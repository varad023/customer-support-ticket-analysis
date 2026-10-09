# Customer Support Ticket Analysis - Step 4: charts (Matplotlib)
# Run this in the SAME notebook as the cleaning cells, so the cleaned 'df' already exists.
# Each '# ---- ' block can go in its own cell. Charts are saved in an 'images' folder.

# ---- Chart cell A: setup
import matplotlib.pyplot as plt
import os
os.makedirs("images", exist_ok=True)
plt.rcParams.update({"figure.figsize": (9, 5), "axes.spines.top": False, "axes.spines.right": False})

# ---- Chart 1: monthly ticket volume (bars) and average resolution time (line)
df["month"] = df["created_time"].dt.to_period("M").astype(str)
monthly = df.groupby("month").agg(tickets=("ticket_id", "count"),
                                  avg_hours=("resolution_hours", "mean"))
fig, ax1 = plt.subplots()
ax1.bar(monthly.index, monthly["tickets"], color="#cfd8e3")
ax1.set_ylabel("Tickets created")
ax1.tick_params(axis="x", rotation=45)
ax2 = ax1.twinx()
ax2.plot(monthly.index, monthly["avg_hours"], color="#d9480f", marker="o")
ax2.set_ylabel("Avg resolution time (hours)")
ax2.spines["right"].set_visible(True)
plt.title("Resolution time climbed from ~26h to ~39h while volume stayed flat")
plt.tight_layout()
plt.savefig("images/01_monthly_trend.png", dpi=150)
plt.show()

# ---- Chart 2: tickets by topic
topic = df["topic"].value_counts().sort_values()
plt.figure()
plt.barh(topic.index, topic.values, color="#3b5b92")
plt.xlabel("Tickets")
plt.title("Ticket volume by topic")
plt.tight_layout()
plt.savefig("images/02_tickets_by_topic.png", dpi=150)
plt.show()

# ---- Chart 3: resolution SLA % by agent (finished tickets only)
done = df[~df["is_open"]]
agent_sla = (done["sla_for_resolution"].eq("Within SLA")
             .groupby(done["agent_name"]).mean().mul(100).sort_values())
plt.figure()
plt.barh(agent_sla.index, agent_sla.values, color="#2b8a3e")
overall = done["sla_for_resolution"].eq("Within SLA").mean() * 100
plt.axvline(overall, color="#d9480f", linestyle="--", label=f"Team average {overall:.1f}%")
plt.xlabel("Within resolution SLA (%)")
plt.xlim(70, 90)
plt.legend()
plt.title("Resolution SLA % by agent (finished tickets)")
plt.tight_layout()
plt.savefig("images/03_sla_by_agent.png", dpi=150)
plt.show()

# ---- Chart 4: first-response SLA % by channel
chan = (df["sla_for_first_response"].eq("Within SLA")
        .groupby(df["source"]).mean().mul(100).sort_values())
plt.figure()
plt.bar(chan.index, chan.values, color="#7048e8")
for i, v in enumerate(chan.values):
    plt.text(i, v + 0.5, f"{v:.1f}%", ha="center")
plt.ylabel("Within first-response SLA (%)")
plt.ylim(60, 100)
plt.title("First-response SLA % by channel")
plt.tight_layout()
plt.savefig("images/04_first_response_by_channel.png", dpi=150)
plt.show()
