-- 04_engagement.sql
-- Does time on the website predict enrolment? (Real data: time_on_site and enrolled.)

SELECT
    engagement_band,
    COUNT(*)                                   AS leads,
    SUM(stage_5_enrolled)                      AS enrolled,
    ROUND(100.0 * AVG(stage_5_enrolled), 1)    AS lead_to_enrol_pct
FROM leads_clean
GROUP BY engagement_band
ORDER BY engagement_band;
