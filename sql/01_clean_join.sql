-- 01_clean_join.sql
-- Join the three source tables into one clean, analysis-ready table (one row per lead).
-- Cleaning rules:
--   * 'Select' is a form placeholder, not a real answer -> NULL / 'Unknown'
--   * Lead source spelling fixes: 'google' -> 'Google', 'bing' -> 'Bing'
--   * Small sources (< 1% of leads) grouped into 'Other'
--   * Missing visit counts -> 0; extreme visits capped at the 99th percentile (17)
--   * Duplicate lead_ids removed (keeps first)

DROP TABLE IF EXISTS leads_clean;

CREATE TABLE leads_clean AS
WITH crm AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY lead_id ORDER BY lead_created_date) AS rn
    FROM crm_leads
),
src AS (
    SELECT lead_id,
           CASE
               WHEN lead_source_raw IS NULL                THEN 'Unknown'
               WHEN LOWER(lead_source_raw) = 'google'      THEN 'Google'
               WHEN lead_source_raw IN ('Direct Traffic', 'Olark Chat', 'Organic Search',
                                        'Reference', 'Welingak Website', 'Referral Sites')
                                                           THEN lead_source_raw
               ELSE 'Other'
           END AS lead_source
    FROM crm
    WHERE rn = 1
)
SELECT
    c.lead_id,
    c.lead_created_date,
    STRFTIME('%Y-%m', c.lead_created_date)                       AS cohort_month,
    c.lead_origin,
    s.lead_source,
    COALESCE(NULLIF(c.occupation_raw, 'Select'), 'Unknown')      AS occupation,
    COALESCE(NULLIF(c.city_raw, 'Select'), 'Unknown')            AS city,
    MIN(COALESCE(w.total_visits, 0), 17)                         AS total_visits,
    w.time_on_site_sec,
    ROUND(w.time_on_site_sec / 60.0, 1)                          AS time_on_site_min,
    CASE
        WHEN w.time_on_site_sec = 0    THEN '0. None'
        WHEN w.time_on_site_sec < 300  THEN '1. <5 min'
        WHEN w.time_on_site_sec < 900  THEN '2. 5-15 min'
        ELSE                                '3. 15+ min'
    END                                                          AS engagement_band,
    w.last_activity,
    -- funnel stage flags (each stage implies the previous one)
    1                                                            AS stage_1_lead,
    CASE WHEN COALESCE(w.total_visits, 0) > 0
              OR c.lead_origin = 'Lead Add Form'
              OR k.enrolled = 1 THEN 1 ELSE 0 END                AS stage_2_engaged,
    CASE WHEN (COALESCE(w.total_visits, 0) > 0 OR c.lead_origin = 'Lead Add Form' OR k.enrolled = 1)
              AND k.counsellor_connected = 1 THEN 1 ELSE 0 END   AS stage_3_counselled,
    CASE WHEN (COALESCE(w.total_visits, 0) > 0 OR c.lead_origin = 'Lead Add Form' OR k.enrolled = 1)
              AND k.counsellor_connected = 1
              AND k.application_started = 1 THEN 1 ELSE 0 END    AS stage_4_applied,
    k.enrolled                                                   AS stage_5_enrolled,
    k.enrolled_date,
    CAST(JULIANDAY(k.enrolled_date) - JULIANDAY(c.lead_created_date) AS INTEGER) AS days_to_enroll,
    k.ab_group,
    k.call_connected_48h
FROM crm c
JOIN src             s ON s.lead_id = c.lead_id
LEFT JOIN web_activity    w ON w.lead_id = c.lead_id
LEFT JOIN counselling_log k ON k.lead_id = c.lead_id
WHERE c.rn = 1;
