---
name: data-explore
description: This skill should be used when a user wants to explore, profile, understand, or audit a dataset before building data models or transformations. It replaces ad-hoc SQL exploration with a structured, repeatable profiling workflow covering schema discovery, column profiling, distribution analysis, relationship mapping, and data quality flagging. Suited for any analytics dataset. Triggers on phrases like "explore this table", "profile this dataset", "what does this data look like", "audit this source", "understand this schema", or before building dbt models on an unfamiliar source.
---

# Data Explore

## Purpose

To systematically profile and understand a dataset before modeling. Produces a structured Markdown file saved locally that the user can review before deciding to dig deeper.

One table at a time. Read-only — never writes to the warehouse.

## Modes

**Quick Scan** (default) — Run phases 0 and 1. Takes 3–5 queries, ~30 seconds. Use for any first-pass exploration.

**Deep Profile** — Run all phases. Use when the user asks for a "full audit", "deep dive", or when quality issues are suspected. Always ask the user upfront whether to build on an existing Quick Scan file or start fresh.

## Output File

Save output to the current working directory as:

```
<table_name>_profile_<YYYYMMDD>.md
```

Example: `orders_profile_20260516.md`

- Do not overwrite existing files — the date suffix preserves versions across runs.
- Use `assets/context_template.md` as the structure.
- Quick Scan fills the Quick Scan section. Deep Profile appends below a `## Deep Profile` divider.

## Workflow

### Phase 0: Setup

Before running any queries:

1. **Infer the target table** from context (conversation, dbt project, recent SQL). If genuinely ambiguous, ask the user for the full `schema.table` reference.

2. **Identify the SQL warehouse**: Snowflake, Redshift, BigQuery, or other. Load the appropriate dialect script:
   - Snowflake → `scripts/profile_snowflake.sql`
   - Redshift → `scripts/profile_redshift.sql`
   - BigQuery → `scripts/profile_bigquery.sql`
   - Other → `scripts/profile_generic.sql`

3. **Run row count first.** If the table has > 10 million rows, use TABLESAMPLE for all subsequent queries. State this upfront: "Table has {n} rows — using 10% sample for performance."

4. **Name-only PII gate** — load `references/pii_detection.md` and match every column name (case-insensitive substring) against HIGH and MEDIUM risk patterns. No queries needed — column names only.
   - If HIGH RISK columns are found: output the warning template, wait for explicit confirmation before including them in any output. If declined, exclude and note "Excluded — PII risk".
   - If MEDIUM RISK columns are found: note them but proceed.
   - Never show raw values from HIGH RISK columns in the saved file.

### Phase 1: Schema Discovery

Run the schema discovery queries from the dialect script:
- Column names, types, nullability
- Row count (use metadata-based query where available — no full scan)
- Sample 10 rows

From the sample, infer the likely grain of the table (one row per order, one row per event, etc.). State this inference and flag it for confirmation.

Save output to `<table_name>_profile_<YYYYMMDD>.md` in the current working directory after this phase.

### Phase 2: Column-Level Profile *(Deep Profile only)*

For each column, run the profile queries from the dialect script:
- Null count and null %
- Distinct count (approximate is fine for large tables)
- Min / max values
- Top 10 most frequent values (only for columns with < 500 distinct values)

Skip top-10 frequency for HIGH RISK PII columns.

### Phase 3: Distribution Check *(Deep Profile only)*

For **numeric columns**: run the percentile distribution query (p01, p25, p50, p75, p95, p99, mean, stddev).

For **date columns**: run the monthly distribution query to check date range and identify gaps.

Flag statistical outliers (values > 5 standard deviations from mean).

### Phase 4: Quality Flags *(Deep Profile only)*

Load `references/quality_flags.md`.

Check each flag category: structural flags, date flags, numeric flags, string flags, and relationship flags. Run the relevant queries from the dialect script.

Classify each issue as HIGH, MEDIUM, or LOW severity. Format findings using the output template in `quality_flags.md`.

Always check at minimum:
- All-null and zero-variance columns
- Future dates in non-expiry date columns
- Negative amounts in amount/revenue/cost columns
- Non-unique primary keys
- Leading/trailing whitespace in string join keys

### Phase 5: Relationship Mapping *(Deep Profile only)*

For columns ending in `_id` or `_key`, run the FK candidate query to check if their values are a subset of a likely reference table. Note cardinality (one-to-many vs many-to-many).

## After Quick Scan

Once the file is saved, ask the user about their needs. Frame the question based on what was found:

- If column names suggest quality concerns (many nullables, ambiguous types): ask if they want to run a Deep Profile to validate data quality before proceeding.
- If schema looks clean and well-structured: ask if they want to explore a related table or start modeling.
- If PII columns were excluded: remind the user and ask how they'd like to handle them.

Do not suggest specific downstream skills by name.

## Notes on Sensitive Data

- Never log or display raw values from HIGH RISK PII columns in the output file
- Redact sample values from quality flag examples if they come from MEDIUM or HIGH risk PII columns
- If the user declines profiling of HIGH RISK columns, exclude them from the output entirely and note "Excluded — PII risk"
