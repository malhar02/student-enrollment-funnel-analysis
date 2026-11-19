-- 05_cohorts.sql
-- Monthly lead cohorts: % of each month's leads enrolled within 7 / 14 / 30 / 60 days.
-- (Dates are simulated - see README.)

SELECT
    cohort_month,
    COUNT(*)                                                                             AS leads,
    ROUND(100.0 * SUM(CASE WHEN days_to_enroll <= 7  THEN 1 ELSE 0 END) / COUNT(*), 1)   AS enrolled_d7_pct,
    ROUND(100.0 * SUM(CASE WHEN days_to_enroll <= 14 THEN 1 ELSE 0 END) / COUNT(*), 1)   AS enrolled_d14_pct,
    ROUND(100.0 * SUM(CASE WHEN days_to_enroll <= 30 THEN 1 ELSE 0 END) / COUNT(*), 1)   AS enrolled_d30_pct,
    ROUND(100.0 * SUM(CASE WHEN days_to_enroll <= 60 THEN 1 ELSE 0 END) / COUNT(*), 1)   AS enrolled_d60_pct,
    ROUND(100.0 * AVG(stage_5_enrolled), 1)                                              AS enrolled_total_pct
FROM leads_clean
GROUP BY cohort_month
ORDER BY cohort_month;
