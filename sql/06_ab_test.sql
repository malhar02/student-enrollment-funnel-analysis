-- 06_ab_test.sql
-- A/B test summary: WhatsApp reminder before counselling call (simulated experiment).
-- Significance testing is done in Python (notebook) - SQL gives the counts.

SELECT
    ab_group,
    COUNT(*)                                   AS leads,
    SUM(call_connected_48h)                    AS connected_48h,
    ROUND(100.0 * AVG(call_connected_48h), 2)  AS connect_rate_pct
FROM leads_clean
WHERE ab_group IS NOT NULL
GROUP BY ab_group
ORDER BY ab_group;
