USE support_db;

-- Q1: Ticket volume by topic
-- Expected: Product setup 623 (26.9%), Pricing and licensing 521, Feature request 414 ...
SELECT tp.topic_name,
       COUNT(*) AS tickets,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM tickets), 1) AS pct_of_total
FROM tickets t
JOIN topics tp ON tp.topic_id = t.topic_id
GROUP BY tp.topic_name
ORDER BY tickets DESC;

-- Q2: Average resolution time by topic
-- Expected: Training request slowest (38.89 hrs), Bug report fastest (29.91 hrs)
SELECT tp.topic_name,
       COUNT(t.resolution_hours) AS resolved_tickets,
       ROUND(AVG(t.resolution_hours), 2) AS avg_resolution_hrs
FROM tickets t
JOIN topics tp ON tp.topic_id = t.topic_id
GROUP BY tp.topic_name
ORDER BY avg_resolution_hrs DESC;

-- Q3: Resolution SLA % by agent (finished tickets only)
-- Expected: Heather Urry 87.1% best, Connor Danielovitch 78.4% lowest
SELECT a.agent_name,
       a.agent_group,
       COUNT(*) AS finished_tickets,
       SUM(t.sla_resolution_clean = 'Within SLA') AS within_sla,
       ROUND(SUM(t.sla_resolution_clean = 'Within SLA') * 100.0 / COUNT(*), 1) AS sla_pct
FROM tickets t
JOIN agents a ON a.agent_id = t.agent_id
WHERE t.is_open = 0
GROUP BY a.agent_name, a.agent_group
ORDER BY sla_pct DESC;

-- Q4: Tickets by status
-- Expected: Closed 1173, Resolved 739, In progress 400
SELECT s.status_name, COUNT(*) AS tickets
FROM tickets t
JOIN statuses s ON s.status_id = t.status_id
GROUP BY s.status_name
ORDER BY tickets DESC;

-- Q5: Monthly volume and average resolution time
-- Expected: 12 rows; Jan 224 tickets / 26.10 hrs ... Oct 200 / 39.19 hrs
SELECT DATE_FORMAT(created_time, '%Y-%m') AS month,
       COUNT(*) AS tickets,
       ROUND(AVG(resolution_hours), 2) AS avg_resolution_hrs
FROM tickets
GROUP BY DATE_FORMAT(created_time, '%Y-%m')
ORDER BY month;

-- Q6: SLA performance by priority
-- Expected: High 413 / 88.9 / 83.0, Medium 716 / 87.8 / 78.4, Low 1183 / 86.5 / 81.6
SELECT priority,
       COUNT(*) AS tickets,
       ROUND(SUM(sla_for_first_response = 'Within SLA') * 100.0 / COUNT(*), 1) AS first_response_sla_pct,
       ROUND(SUM(sla_resolution_clean = 'Within SLA') * 100.0 / SUM(is_open = 0), 1) AS resolution_sla_pct
FROM tickets
GROUP BY priority
ORDER BY FIELD(priority, 'High', 'Medium', 'Low');

-- Q7: Customer satisfaction by agent
-- Expected: Connor Danielovitch 4.07 top, Kristos Westoll 3.23 lowest
SELECT a.agent_name,
       COUNT(t.survey_score) AS surveys,
       ROUND(AVG(t.survey_score), 2) AS avg_score
FROM tickets t
JOIN agents a ON a.agent_id = t.agent_id
GROUP BY a.agent_name
HAVING COUNT(t.survey_score) > 0
ORDER BY avg_score DESC;

-- Q8: Top 5 countries by volume, with a rank (window function)
-- Expected: Germany 304, Italy 300, Poland 286, United Kingdom 281, Slovenia 158
SELECT country,
       tickets,
       avg_resolution_hrs,
       RANK() OVER (ORDER BY tickets DESC) AS volume_rank
FROM (
    SELECT country,
           COUNT(*) AS tickets,
           ROUND(AVG(resolution_hours), 2) AS avg_resolution_hrs
    FROM tickets
    GROUP BY country
) c
ORDER BY volume_rank
LIMIT 5;

-- Q9: How fast are tickets resolved? (CASE statement - speed buckets, finished tickets only)
-- Expected: 0-12 hrs 533 (27.9%), 12-24 hrs 508 (26.6%), 24-48 hrs 541 (28.3%), 48+ hrs 330 (17.3%)
SELECT CASE
           WHEN resolution_hours <= 12 THEN '1) Up to 12 hrs'
           WHEN resolution_hours <= 24 THEN '2) 12-24 hrs'
           WHEN resolution_hours <= 48 THEN '3) 24-48 hrs'
           ELSE '4) Over 48 hrs'
       END AS resolution_bucket,
       COUNT(*) AS tickets,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM tickets WHERE is_open = 0), 1) AS pct_of_finished
FROM tickets
WHERE is_open = 0
GROUP BY resolution_bucket
ORDER BY resolution_bucket;

-- Q10: Which agents beat the team's overall SLA %? (CTE)
-- Expected: overall is 80.9%; above it: Heather Urry 87.1, Sheela Cutten 83.8,
--           Michele Whyatt 81.8, Adolpho Messingham 81.4
WITH agent_sla AS (
    SELECT a.agent_name,
           ROUND(SUM(t.sla_resolution_clean = 'Within SLA') * 100.0 / COUNT(*), 1) AS sla_pct
    FROM tickets t
    JOIN agents a ON a.agent_id = t.agent_id
    WHERE t.is_open = 0
    GROUP BY a.agent_name
),
overall AS (
    SELECT ROUND(SUM(sla_resolution_clean = 'Within SLA') * 100.0 / COUNT(*), 1) AS overall_pct
    FROM tickets
    WHERE is_open = 0
)
SELECT s.agent_name, s.sla_pct, o.overall_pct
FROM agent_sla s
CROSS JOIN overall o
WHERE s.sla_pct > o.overall_pct
ORDER BY s.sla_pct DESC;

-- Q11: Month-over-month change in resolution time (window function LAG)
-- Expected: Feb +1.06, Mar +3.38, Apr -3.52, May +1.16, Jun +3.66, Jul +3.97, Aug +2.40,
--           Sep +0.93, Oct +0.04, Nov -1.32, Dec -0.73  (Jan is NULL; +/-0.01 rounding is fine)
SELECT month,
       avg_resolution_hrs,
       ROUND(avg_resolution_hrs - LAG(avg_resolution_hrs) OVER (ORDER BY month), 2) AS change_vs_prev_month
FROM (
    SELECT DATE_FORMAT(created_time, '%Y-%m') AS month,
           AVG(resolution_hours) AS avg_resolution_hrs
    FROM tickets
    GROUP BY DATE_FORMAT(created_time, '%Y-%m')
) m
ORDER BY month;

-- Q12: Tier 1 vs Tier 2 support
-- Expected: Tier 1 = 1756 tickets, 34.08 hrs, 80.0% | Tier 2 = 556 tickets, 30.63 hrs, 83.4%
SELECT support_level,
       COUNT(*) AS tickets,
       ROUND(AVG(resolution_hours), 2) AS avg_resolution_hrs,
       ROUND(SUM(sla_resolution_clean = 'Within SLA') * 100.0 / SUM(is_open = 0), 1) AS resolution_sla_pct
FROM tickets
GROUP BY support_level
ORDER BY support_level;

-- Q13: Performance by channel (source)
-- Expected: Chat 846 / 0.03 hrs / 84.4% | Email 1220 / 0.81 hrs / 91.8% | Phone 246 / 0.09 hrs / 75.2%
-- (the 2 tickets with impossible first-response times are NULL, so AVG ignores them)
SELECT source,
       COUNT(*) AS tickets,
       ROUND(AVG(first_response_hours), 2) AS avg_first_response_hrs,
       ROUND(SUM(sla_for_first_response = 'Within SLA') * 100.0 / COUNT(*), 1) AS first_response_sla_pct
FROM tickets
GROUP BY source
ORDER BY tickets DESC;

-- Q14: Tickets by product group
-- Expected: Ready to use Software 1002, Custom software development 639, Other 343,
--           Training and Consulting Services 328
SELECT product_group, COUNT(*) AS tickets
FROM tickets
GROUP BY product_group
ORDER BY tickets DESC;

-- Q15: Open ticket backlog by agent
-- Expected: Connor Danielovitch 72, Nicola Wane 68, Sheela Cutten 60, Bernard Beckley 60,
--           Kristos Westoll 49, Adolpho Messingham 37, Michele Whyatt 32, Heather Urry 22
SELECT a.agent_name,
       COUNT(*) AS open_tickets
FROM tickets t
JOIN agents a ON a.agent_id = t.agent_id
WHERE t.is_open = 1
GROUP BY a.agent_name
ORDER BY open_tickets DESC;

-- BONUS: a view for Power BI (readable names instead of ID numbers)
-- Run this ONCE (CREATE OR REPLACE lets you re-run it safely). Expected: 2312 rows.
CREATE OR REPLACE VIEW v_ticket_report AS
SELECT t.ticket_id,
       s.status_name   AS status,
       tp.topic_name   AS topic,
       a.agent_name,
       a.agent_group,
       t.priority,
       t.source,
       t.product_group,
       t.support_level,
       t.country,
       t.latitude,
       t.longitude,
       t.created_time,
       t.first_response_time,
       t.resolution_time,
       t.close_time,
       t.sla_for_first_response,
       t.sla_resolution_clean AS sla_for_resolution,
       t.first_response_hours,
       t.resolution_hours,
       t.agent_interactions,
       t.survey_score,
       t.is_open,
       t.interactions_outlier
FROM tickets t
JOIN statuses s ON s.status_id = t.status_id
JOIN topics tp  ON tp.topic_id = t.topic_id
JOIN agents a   ON a.agent_id  = t.agent_id;

SELECT COUNT(*) AS rows_in_view FROM v_ticket_report;
