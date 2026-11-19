"""
Step 2 - Run every query in sql/ against data/admissions.db and export the results
to data/processed/ as CSVs (these are the Looker Studio data sources).
"""
from pathlib import Path
import sqlite3

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
DB = ROOT / "data" / "admissions.db"
OUT = ROOT / "data" / "processed"
OUT.mkdir(parents=True, exist_ok=True)

with sqlite3.connect(DB) as con:
    for sql_file in sorted((ROOT / "sql").glob("*.sql")):
        query = sql_file.read_text()
        if sql_file.name.startswith("01_"):
            con.executescript(query)
            df = pd.read_sql("SELECT * FROM leads_clean", con)
            name = "leads_clean"
        else:
            df = pd.read_sql(query, con)
            name = sql_file.stem[3:]
        df.to_csv(OUT / f"{name}.csv", index=False)
        print(f"\n=== {sql_file.name} -> {name}.csv ({len(df):,} rows)")
        if len(df) < 20:
            print(df.to_string(index=False))
