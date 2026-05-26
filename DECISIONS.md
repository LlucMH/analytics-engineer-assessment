# Design Decisions

This document captures the key modeling decisions made during the assessment
and the reasoning behind each one.

---

## Staging layer

### Seeds are not incremental
`stg_campaigns`, `stg_events`, and `stg_accounts` are materialized as tables,
not incremental models. Seeds are static by definition — they are loaded once
via `dbt seed` and do not grow over time. Incremental logic would add complexity
with no benefit.

### Null filters in staging
All staging models filter `campaign_id IS NOT NULL` and `client_id IS NOT NULL`.
This is a multi-tenant platform — a record without a client has no valid business
context and should not propagate downstream. These were confirmed as real data
quality issues in the seed data (`camp_bad_001` and a null-client account).

### revenue_influenced coalesced to 0 in stg_events
`revenue_influenced` is NULL for non-conversion events (impressions, clicks) in
the raw data. Coalescing to 0 in staging centralizes this logic once so no mart
needs to handle NULLs. If this were done per mart, it would be easy to forget
and produce silent errors in aggregations.

### lower() applied to event_type
`event_type` is lowercased in staging to guard against dirty data from upstream
pipelines delivering mixed-case values. Defensive by default.

---

## Intermediate layer

### No intermediate models created
No `int_` models were created. The three business questions are simple enough
that the join logic fits cleanly inside each mart without duplication that would
justify a shared intermediate. Adding intermediates here would increase project
complexity without meaningful benefit.

The one case where an intermediate could be justified is `int_events_enriched`
(joining events + campaigns to get channel), shared by Q1 and Q3. This was
a conscious tradeoff: keeping the project simple for now, with the intermediate
as an obvious next step if more marts needed the same join.

---

## Mart layer

### INNER JOIN instead of LEFT JOIN
All marts use INNER JOIN when joining events to campaigns or accounts.
A LEFT JOIN would silently produce NULL values for unmatched records, hiding
data quality issues. In a multi-tenant B2B platform, an event referencing
an unknown campaign or account is a pipeline problem that should surface,
not be hidden behind NULLs.

### ROW_NUMBER() instead of LIMIT for top-N per client
`LIMIT N` returns a global top N across all clients. `ROW_NUMBER() OVER
(PARTITION BY client_id)` correctly scopes the ranking within each client.
This is the core bug in the original `mart_top_accounts.sql`.

### 90-day window uses current_date
The revenue window in `mart_top_channels_per_client` uses
`current_date - interval '90' day` instead of a hardcoded date. A hardcoded
date goes stale silently — the model would keep running but return increasingly
wrong results over time.

### Peer group in mart_efficient_campaigns excludes zero-meeting campaigns
The channel average (`AVG() OVER (PARTITION BY channel)`) is computed only
over campaigns that booked at least one meeting. This is enforced via INNER JOIN
before the window function. Including zero-meeting campaigns in the average
would dilute the benchmark and make it meaningless.

### count(distinct event_id) instead of count(*)
Used throughout to guard against duplicate events in the pipeline. If the
upstream system delivers duplicates, `count(*)` would silently overcount.
`count(distinct event_id)` is more defensive with negligible performance cost
at this data volume.

### mom_change coalesces NULL prev_month to 0
In `mart_account_engagement_trend`, the first month of an account has no prior
month, so `prev_month_events` is NULL. `mom_change` coalesces this to 0 to
avoid NULL propagation in the delta calculation.

### No ORDER BY in marts
Marts do not include `ORDER BY`. Ordering is the responsibility of the consumer
(BI tool, analyst query). Adding `ORDER BY` in a mart gives a false sense of
guaranteed ordering that most engines (BigQuery, Snowflake) do not preserve.

---

## Code Review (Part 2)

### mart_top_accounts: original model kept, improved version commented
The assessment explicitly asks to list issues as comments at the top of the file
and rewrite the model below. The original (broken) model is kept as the active
query so the issues are visible in context. The improved version is included as
commented-out SQL immediately below, ready to replace the original.

This is intentional — the file is structured exactly as the assessment requested:
1. Issues documented as comments at the top
2. Original model (broken) visible and runnable
3. Improved version commented out below

In a real code review this would be a PR where the improved version replaces
the original entirely.

---

## External data source (Part 3)

> ⚠️ The following decisions are based on assumptions made during the assessment
> about how the agency delivers data. In production these would be validated
> against the actual agency SLA and delivery process.

### stg_ad_spend is incremental
Unlike the seed-based staging models, `stg_ad_spend` is incremental because:
- The agency delivers a daily export — the file grows every day
- At production scale this table would be large enough that full table scans
  on every run would be expensive
- The grain is (campaign_id, spend_date) — a natural unique key for upserts

### 7-day lookback window
The incremental filter uses a 7-day lookback to capture late-arriving data
without reprocessing the full history. The window size is a tradeoff: wide
enough to cover typical agency delivery delays, narrow enough to keep each
run cheap. The right value depends on the agency SLA agreed in production.

### No full refresh
A full refresh is deliberately avoided. If the agency only delivers a rolling
window of recent data, running a full refresh would delete historical records
that are no longer in the source file. The incremental strategy with
`delete+insert` preserves the full history while still applying corrections
within the lookback window.

### DuckDB view over Parquet
The Parquet file is registered as a persistent DuckDB view via
`scripts/setup_ad_spend_source.py` rather than being loaded into a seed or
a native table. This avoids duplicating the data and lets DuckDB query the
file in place. The view persists in the `.duckdb` file across dbt runs.

---

## Tests

### Tests reflect confirmed data quality assumptions
Tests were added based on the README documentation and confirmed issues found
in the data:
- `not_null` on `client_id` and `campaign_id` — confirmed NULL records exist
- `accepted_values` on `event_type` and `channel` — values defined in README
- `unique` + `not_null` on primary keys — standard for any staging model

### mart_top_accounts has no tests
The original model has known issues documented in the SQL file. Adding tests
against the broken model would either fail (testing the wrong columns) or give
false confidence. Tests will be added once the improved version replaces the
original.
