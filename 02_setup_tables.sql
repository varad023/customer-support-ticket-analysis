-- Customer Support Ticket Analysis - Step 2: build the MySQL tables
-- RUN THIS ONLY ONCE. You already did. Running it again will give errors
-- ("table already exists" / "duplicate entry"). Keep it as a record of how the database was built.
--
-- Before this file: import tickets_clean.csv with the Table Data Import Wizard
-- into support_db as a NEW table called tickets_staging
-- (set the type of first_response_hours to TEXT in the wizard so no rows are dropped).

USE support_db;

-- Part A: small lookup tables
CREATE TABLE agents (
    agent_id INT AUTO_INCREMENT PRIMARY KEY,
    agent_name VARCHAR(100) NOT NULL UNIQUE,
    agent_group VARCHAR(50)
);

CREATE TABLE topics (
    topic_id INT AUTO_INCREMENT PRIMARY KEY,
    topic_name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE statuses (
    status_id INT AUTO_INCREMENT PRIMARY KEY,
    status_name VARCHAR(50) NOT NULL UNIQUE
);

-- Part B: fill them from the staging table
INSERT INTO agents (agent_name, agent_group)
SELECT DISTINCT agent_name, agent_group FROM tickets_staging;

INSERT INTO topics (topic_name)
SELECT DISTINCT topic FROM tickets_staging;

INSERT INTO statuses (status_name)
SELECT DISTINCT status FROM tickets_staging;

-- Part C: main tickets table
CREATE TABLE tickets (
    ticket_id INT PRIMARY KEY,
    status_id INT NOT NULL,
    topic_id INT NOT NULL,
    agent_id INT NOT NULL,
    priority VARCHAR(20),
    source VARCHAR(20),
    product_group VARCHAR(50),
    support_level VARCHAR(20),
    country VARCHAR(50),
    latitude DECIMAL(9,5),
    longitude DECIMAL(9,5),
    created_time DATETIME(3),
    expected_sla_to_resolve DATETIME(3),
    expected_sla_to_first_response DATETIME(3),
    first_response_time DATETIME(3),
    resolution_time DATETIME(3),
    close_time DATETIME(3),
    sla_for_first_response VARCHAR(20),
    sla_for_resolution VARCHAR(20),
    sla_resolution_clean VARCHAR(20),
    first_response_hours DOUBLE,
    resolution_hours DOUBLE,
    agent_interactions INT,
    survey_score TINYINT,
    frt_data_issue BOOLEAN,
    interactions_outlier BOOLEAN,
    is_open BOOLEAN,
    FOREIGN KEY (status_id) REFERENCES statuses(status_id),
    FOREIGN KEY (topic_id) REFERENCES topics(topic_id),
    FOREIGN KEY (agent_id) REFERENCES agents(agent_id)
);

-- Part D: copy the data in (blank text becomes a real NULL)
INSERT INTO tickets
SELECT
    s.ticket_id,
    st.status_id,
    tp.topic_id,
    ag.agent_id,
    s.priority,
    s.source,
    s.product_group,
    s.support_level,
    s.country,
    s.latitude,
    s.longitude,
    NULLIF(CAST(s.created_time AS CHAR), ''),
    NULLIF(CAST(s.expected_sla_to_resolve AS CHAR), ''),
    NULLIF(CAST(s.expected_sla_to_first_response AS CHAR), ''),
    NULLIF(CAST(s.first_response_time AS CHAR), ''),
    NULLIF(CAST(s.resolution_time AS CHAR), ''),
    NULLIF(CAST(s.close_time AS CHAR), ''),
    s.sla_for_first_response,
    s.sla_for_resolution,
    NULLIF(CAST(s.sla_resolution_clean AS CHAR), ''),
    NULLIF(CAST(s.first_response_hours AS CHAR), ''),
    NULLIF(CAST(s.resolution_hours AS CHAR), ''),
    s.agent_interactions,
    CAST(NULLIF(CAST(s.survey_results AS CHAR), '') AS DECIMAL(3,1)),
    CAST(s.frt_data_issue AS CHAR) IN ('True', '1'),
    CAST(s.interactions_outlier AS CHAR) IN ('True', '1'),
    CAST(s.is_open AS CHAR) IN ('True', '1')
FROM tickets_staging s
JOIN statuses st ON st.status_name = s.status
JOIN topics tp ON tp.topic_name = s.topic
JOIN agents ag ON ag.agent_name = s.agent_name;

-- Part E: checks (one row; expected 2312, 2, 400, 1139, 400, 45, 2, 33.24)
SELECT
    COUNT(*)                          AS total_tickets,
    SUM(first_response_hours IS NULL) AS frh_blank,
    SUM(resolution_time IS NULL)      AS resolution_blank,
    SUM(survey_score IS NULL)         AS survey_blank,
    SUM(is_open)                      AS open_tickets,
    SUM(interactions_outlier)         AS outliers,
    SUM(frt_data_issue)               AS frt_issues,
    ROUND(AVG(resolution_hours), 2)   AS avg_resolution_hrs
FROM tickets;
