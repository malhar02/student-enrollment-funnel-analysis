-- 02_funnel.sql
-- Overall 5-stage admissions funnel with step-to-step and top-of-funnel conversion.

WITH stages AS (
    SELECT 1 AS stage_no, 'Lead captured'        AS stage, SUM(stage_1_lead)       AS leads FROM leads_clean
    UNION ALL SELECT 2, 'Engaged (site / form)',  SUM(stage_2_engaged)    FROM leads_clean
    UNION ALL SELECT 3, 'Counsellor connected',   SUM(stage_3_counselled) FROM leads_clean
    UNION ALL SELECT 4, 'Application started',    SUM(stage_4_applied)    FROM leads_clean
    UNION ALL SELECT 5, 'Enrolled',               SUM(stage_5_enrolled)   FROM leads_clean
)
SELECT
    stage_no,
    stage,
    leads,
    ROUND(100.0 * leads / FIRST_VALUE(leads) OVER (ORDER BY stage_no), 1)     AS pct_of_leads,
    ROUND(100.0 * leads / LAG(leads) OVER (ORDER BY stage_no), 1)             AS step_conversion_pct,
    LAG(leads) OVER (ORDER BY stage_no) - leads                                AS dropped_at_step
FROM stages
ORDER BY stage_no;
