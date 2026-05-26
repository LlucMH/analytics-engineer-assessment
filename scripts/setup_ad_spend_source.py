"""
setup_ad_spend_source.py
────────────────────────
Registers the ad_spend Parquet file as a queryable DuckDB source so that
dbt can reference it via source('external', 'ad_spend').

Run this ONCE before `dbt run` (or in CI before the dbt step):
    python scripts/setup_ad_spend_source.py

Current setup:
    Registers a single Parquet file as a persistent view in the DuckDB database.

Production alternative (hive-partitioned files):
    If the agency delivers files partitioned by date, the directory structure would be:

        data/ad_spend/spend_date=2025-07-19/data.parquet
        data/ad_spend/spend_date=2025-07-20/data.parquet
        ...

    And the view would be registered as:

        CREATE OR REPLACE VIEW external.ad_spend AS
        SELECT * FROM read_parquet(
            'data/ad_spend/**/*.parquet',
            hive_partitioning=true
        )

    This enables automatic partition pruning on spend_date — DuckDB only reads
    the partitions needed for each query instead of scanning the full dataset.

CI usage:
    Add this step before `dbt run` in your pipeline:
        - run: python scripts/setup_ad_spend_source.py
"""

import os
import duckdb

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH      = os.path.join(PROJECT_ROOT, "octane11_analytics.duckdb")
PARQUET_PATH = os.path.join(PROJECT_ROOT, "data", "ad_spend.parquet")

def main():
    conn = duckdb.connect(DB_PATH)
    conn.execute("CREATE SCHEMA IF NOT EXISTS external")
    conn.execute(f"""
        CREATE OR REPLACE VIEW external.ad_spend AS
        SELECT * FROM read_parquet('{PARQUET_PATH}')
    """)
    count = conn.execute("SELECT count(*) FROM external.ad_spend").fetchone()[0]
    print(f"✓ external.ad_spend registered — {count} rows visible")
    conn.close()

if __name__ == "__main__":
    main()