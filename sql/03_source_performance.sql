-- 03_source_performance.sql
-- Funnel by lead source: where do enrolments really come from?

SELECT
    lead_source,
    COUNT(*)                                                     AS leads,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)           AS share_of_leads_pct,
    ROUND(100.0 * AVG(stage_3_counselled), 1)                    AS counselled_pct,
    ROUND(100.0 * AVG(stage_4_applied), 1)                       AS applied_pct,
    SUM(stage_5_enrolled)                                        AS enrolled,
    ROUND(100.0 * AVG(stage_5_enrolled), 1)                      AS lead_to_enrol_pct,
    ROUND(100.0 * SUM(stage_5_enrolled) / SUM(SUM(stage_5_enrolled)) OVER (), 1) AS share_of_enrolments_pct,
    ROUND(AVG(time_on_site_min), 1)                              AS avg_time_on_site_min
FROM leads_clean
GROUP BY lead_source
ORDER BY leads DESC;
