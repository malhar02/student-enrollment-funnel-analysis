"""
Step 1 - Build the three source tables and load them into SQLite.

The raw X Education file (data/raw/Leads.csv) is one wide export. Real admissions
teams usually have this data spread across three systems, so we split it the same way:

    crm_leads          -> who the lead is and where they came from   (real columns)
    web_activity       -> what they did on the website               (real columns)
    counselling_log    -> what the admissions team did / outcome     (real + simulated)

SIMULATED fields (the public dataset has no dates, stage history or experiments):
    lead_created_date, enrolled_date, application_started, ab_group, call_connected_48h
All simulation is seeded (SEED below) so every number in the README is reproducible.
Everything else comes straight from the real dataset.
"""
from pathlib import Path
import sqlite3

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw" / "Leads.csv"
DB = ROOT / "data" / "admissions.db"
SEED = 42

rng = np.random.default_rng(SEED)
raw = pd.read_csv(RAW)
n = len(raw)

# ---------------------------------------------------------------- crm_leads (real)
crm = pd.DataFrame({
    "lead_id": raw["Lead Number"],
    "lead_origin": raw["Lead Origin"],
    "lead_source_raw": raw["Lead Source"],
    "occupation_raw": raw["What is your current occupation"],
    "city_raw": raw["City"],
    "specialization_raw": raw["Specialization"],
    "do_not_email": raw["Do Not Email"],
    "do_not_call": raw["Do Not Call"],
})

# Simulated creation date: Jan-Dec 2025, more leads in admission season (May-Jul).
month_weights = np.array([6, 6, 7, 8, 10, 11, 11, 9, 8, 8, 8, 8], dtype=float)
months = rng.choice(np.arange(1, 13), size=n, p=month_weights / month_weights.sum())
days = rng.integers(0, 28, size=n)
crm["lead_created_date"] = pd.to_datetime(
    {"year": 2025, "month": months, "day": 1}) + pd.to_timedelta(days, unit="D")

# ---------------------------------------------------------------- web_activity (real)
web = pd.DataFrame({
    "lead_id": raw["Lead Number"],
    "total_visits": raw["TotalVisits"],
    "time_on_site_sec": raw["Total Time Spent on Website"],
    "pages_per_visit": raw["Page Views Per Visit"],
    "last_activity": raw["Last Activity"],
})

# ---------------------------------------------------------------- counselling_log
converted = raw["Converted"].to_numpy()  # REAL outcome
tags = raw["Tags"].fillna("")

unreachable_tags = {"Ringing", "switched off", "invalid number", "wrong number given",
                    "number not provided", "opp hangup"}
unreachable = (tags.isin(unreachable_tags)
               | raw["Last Activity"].isin(["Unreachable", "Email Bounced"])).to_numpy()

# Counsellor connected (derived from REAL tags/activity). Every enrolled student was connected.
counsellor_connected = np.where(converted == 1, 1, np.where(unreachable, 0, 1))

# Application started (SIMULATED for non-enrolled leads, more likely if they spent time on site).
t = raw["Total Time Spent on Website"].to_numpy()
p_app = np.clip(0.15 + t / 3000, 0.15, 0.65)
application_started = np.where(converted == 1, 1,
                               np.where(counsellor_connected == 1,
                                        (rng.random(n) < p_app).astype(int), 0))

# Enrolled date (SIMULATED): median ~12 days, slower for low-engagement leads.
base_days = rng.lognormal(mean=np.log(12), sigma=0.8, size=n)
slow = np.where(t < 300, 1.5, 1.0)
days_to_enroll = np.clip(np.round(base_days * slow), 1, 120).astype(int)
enrolled_date = np.where(converted == 1,
                         crm["lead_created_date"] + pd.to_timedelta(days_to_enroll, unit="D"),
                         pd.NaT)

# A/B test (SIMULATED): Sep-Dec 2025 leads randomly split. Treatment = WhatsApp reminder
# sent 2 hours before the counselling call. Metric = call connected within 48 hours.
in_test = crm["lead_created_date"] >= "2025-09-01"
ab_group = np.where(in_test, np.where(rng.random(n) < 0.5, "control", "treatment"), None)
base_rate, lift = 0.52, 0.045
p_call = np.where(ab_group == "treatment", base_rate + lift, base_rate)
call_connected_48h = np.where(in_test, (rng.random(n) < p_call).astype(int), None)

counselling = pd.DataFrame({
    "lead_id": raw["Lead Number"],
    "counsellor_tag": raw["Tags"],
    "lead_quality": raw["Lead Quality"],
    "counsellor_connected": counsellor_connected,
    "application_started": application_started,
    "enrolled": converted,
    "enrolled_date": pd.to_datetime(enrolled_date),
    "ab_group": ab_group,
    "call_connected_48h": call_connected_48h,
})

# ---------------------------------------------------------------- load into SQLite
DB.unlink(missing_ok=True)
with sqlite3.connect(DB) as con:
    for name, df in [("crm_leads", crm), ("web_activity", web), ("counselling_log", counselling)]:
        out = df.copy()
        for c in out.select_dtypes("datetime").columns:
            out[c] = out[c].dt.strftime("%Y-%m-%d")
        out.to_sql(name, con, index=False)
        print(f"{name:16s} {len(out):,} rows")
print(f"Saved -> {DB.relative_to(ROOT)}")
