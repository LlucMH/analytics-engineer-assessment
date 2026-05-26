# Part 3 — External Data Source (ad_spend.parquet)

## Setup

Run this once before `dbt run`:

```bash
python scripts/setup_ad_spend_source.py
```

This script registers a persistent view `external.ad_spend` over the Parquet
file in the DuckDB database so dbt can query it via `source('external', 'ad_spend')`.

## CI

Add this step before `dbt run` in your pipeline:

```bash
python scripts/setup_ad_spend_source.py
dbt run
```

## Models

| Model | Description |
|-------|-------------|
| `stg_ad_spend` | Cleaned daily spend. Incremental on spend_date with 7-day lookback to handle late-arriving data. |
| `mart_budget_vs_actuals` | Budget vs actual spend per campaign with variance and status. |

## Production notes

- Incremental strategy: `delete+insert` with `unique_key = (campaign_id, spend_date)`
- Lookback window: 7 days (assumes agency corrections arrive within 7 days)
- No full refresh: agency only delivers the last year of data; historical data must be preserved