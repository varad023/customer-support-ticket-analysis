# Customer Support Ticket Analysis - Step 1: Cleaning (Python / Pandas)
# Copy each block (between the "# ---- Cell N" lines) into its own Jupyter cell,
# or run the whole file. Change FILE_PATH to where your tickets.csv is.

# ---- Cell 1: load the file and keep a backup copy
import pandas as pd
import numpy as np

FILE_PATH = r"PASTE_YOUR_PATH_HERE\tickets.csv"
df = pd.read_csv(FILE_PATH)
raw = df.copy()
print(df.shape)                      # (2312, 22)

# ---- Cell 2: tidy the column names (lowercase, underscores)
df.columns = df.columns.str.strip().str.lower().str.replace(" ", "_")
print(df.columns.tolist())

# ---- Cell 3: fix the topic spelling ("Pricing and Licensing" vs "licensing")
print(df["topic"].value_counts())
df["topic"] = df["topic"].str.strip().str.capitalize()
print(df["topic"].value_counts())    # 7 topics, Pricing and licensing = 521

# ---- Cell 4: remove hidden spaces in text columns
text_cols = ["status", "priority", "source", "agent_group", "agent_name",
             "product_group", "support_level", "country"]
for c in text_cols:
    df[c] = df[c].str.strip()

# ---- Cell 5: turn text dates into real dates
date_cols = ["created_time", "expected_sla_to_resolve", "expected_sla_to_first_response",
             "first_response_time", "resolution_time", "close_time"]
for c in date_cols:
    df[c] = pd.to_datetime(df[c])
print(df[date_cols].dtypes)

# ---- Cell 6: work out hours
df["first_response_hours"] = (df["first_response_time"] - df["created_time"]).dt.total_seconds() / 3600
df["resolution_hours"] = (df["resolution_time"] - df["created_time"]).dt.total_seconds() / 3600
print(df[["first_response_hours", "resolution_hours"]].describe())

# ---- Cell 7: flag the impossible waits (tickets 1288 and 2135)
bad = df[df["first_response_hours"] < 0]
print(bad[["ticket_id", "created_time", "first_response_time", "first_response_hours"]])
df["frt_data_issue"] = df["first_response_hours"] < 0
df.loc[df["frt_data_issue"], "first_response_hours"] = np.nan

# ---- Cell 8: flag the "60 interactions" outliers
df["interactions_outlier"] = df["agent_interactions"] >= 60
print(df["interactions_outlier"].sum())          # 45

# ---- Cell 9: separate open tickets from finished ones
df["is_open"] = df["status"] == "In progress"
df["sla_resolution_clean"] = df["sla_for_resolution"].where(~df["is_open"])
print(df["sla_resolution_clean"].value_counts(dropna=False))   # 1546 / 366 / 400 NaN

# ---- Cell 10: check blanks (we do NOT fill them)
print(df.isnull().sum()[lambda s: s > 0])

# ---- Cell 11: duplicates and missing IDs
print(df.duplicated().sum())                                   # 0
print(df["ticket_id"].is_unique)                               # True
print(df["ticket_id"].max() - df["ticket_id"].min() + 1 - len(df))   # 676

# ---- Cell 12: save the clean file
df.to_csv("tickets_clean.csv", index=False)
print(df.shape, raw.shape)                                     # (2312, 28) (2312, 22)
