---
name: data-explore
description: This skill should be used when a user wants to explore, profile, understand, or audit a dataset before building data models or transformations. It replaces ad-hoc SQL exploration with a structured, repeatable profiling workflow covering schema discovery, column profiling, distribution analysis, relationship mapping, data quality flagging, and domain inference. Particularly suited for banking, insurance, and financial services datasets. Triggers on phrases like "explore this table", "profile this dataset", "what does this data look like", "audit this source", "understand this schema", or before building dbt models on an unfamiliar source.
---

# Data Explore

## Purpose

To systematically profile and understand a dataset before modeling. Produces a structured artifact (modeled on `assets/context_template.md`) that feeds directly into downstream skills: `/to-prd`, `/grill-with-docs`, and `/dbt-test`.

## Modes

**Quick Scan** (default) — Run phases 0, 1, 2, and 5. Takes 5–10 queries, ~60 seconds. Use when the user wants a fast overview or hasn't specified depth.

**Deep Profile** — Run all 6 phases. Use when the user asks for a "full audit", "deep dive", or when quality issues are suspected. State upfront that this is more thorough and will take longer.

## Workflow

### Phase 0: Identify Dialect and Scale

Before running any queries:
1. Ask or infer the SQL warehouse: Snowflake, Redshift, BigQuery, or other. Load the appropriate dialect script:
   - Snowflake → `scripts/profile_snowflake.sql`
   - Redshift → `scripts/profile_redshift.sql`
   - BigQuery → `scripts/profile_bigquery.sql`
   - Other → `scripts/profile_generic.sql`

2. Run the row count query first. If the table has **> 10 million rows**, use TABLESAMPLE for all subsequent queries. State this upfront: "Table has {n} rows — using 10% sample for performance."

3. Confirm the target table(s) and schema with the user if not already specified.

### Phase 1: PII Check (always run before any profiling)

Load `references/pii_detection.md`.

Check every column name against the HIGH and MEDIUM risk patterns. Also run a quick scan of sample values (top 10 rows) for value-level PII patterns (SSN format, email, phone, credit card).

If any matches are found, output the warning template from `pii_detection.md` and wait for explicit confirmation before profiling HIGH RISK columns.

For confirmed HIGH RISK columns: use hash-based counting only, never show sample values or top-10 frequencies. Note these columns in the PII section of the output artifact.

### Phase 2: Schema Discovery

Run the schema discovery queries from the dialect script:
- Column names, types, nullability
- Row count (or use the metadata-based query — no scan needed for Snowflake/Redshift/BigQuery)
- Sample 10 rows

From the sample, infer the likely grain of the table (one row per policy, one row per transaction, etc.). State this inference and flag it for confirmation.

### Phase 3: Column-Level Profile

For each column, run the profile queries from the dialect script to collect:
- Null count and null %
- Distinct count (approximate is fine for large tables)
- Min / max values
- Top 10 most frequent values (only for columns with < 500 distinct values)

Skip top-10 frequency for HIGH RISK PII columns.

### Phase 4: Distribution Check *(Deep Profile only)*

For **numeric columns**: run the percentile distribution query (p01, p25, p50, p75, p95, p99, mean, stddev).

For **date columns**: run the monthly distribution query to check date range and identify gaps.

Flag statistical outliers (values > 5 standard deviations from mean).

### Phase 5: Quality Flags

Load `references/quality_flags.md`.

Check each flag category: structural flags, date flags, numeric flags, string flags, and relationship flags. Run the relevant queries from the dialect script.

Classify each issue as HIGH, MEDIUM, or LOW severity. Format findings using the output template in `quality_flags.md`.

Always check at minimum:
- All-null and zero-variance columns
- Future dates in non-expiry date columns
- Negative amounts in premium/claim/loss columns
- Non-unique primary keys
- Leading/trailing whitespace in string join keys

### Phase 6: Domain Inference and Relationship Mapping *(Deep Profile only)*

Load `references/domain_patterns.md`.

Match column names and sample values against banking/insurance domain patterns to infer business meaning. Add inferred meanings to the Domain Glossary section of the output, marking them as "Inferred — confirm with domain expert."

For columns ending in `_id` or `_key`, run the FK candidate query to check if their values are a subset of a likely reference table. Note cardinality (one-to-many vs many-to-many).

## Clarifying Questions

After completing the profile, always generate 3–5 clarifying questions for the user based on:
- Status/flag columns with undocumented code values
- Ambiguous date columns (business date vs system date)
- Amount columns that can be negative (refund/credit vs error)
- Zero values in amount columns (missing vs meaningful)
- Sentinel values (e.g., 9999-12-31 in date columns)
- Any HIGH or MEDIUM quality flags found

Frame questions as a numbered list under "Open Questions" in the output artifact.

## Output

Always produce the output using `assets/context_template.md` as the structure. Fill in all sections with actual findings. Leave placeholder text only where data was not collected (e.g., "Not profiled — Deep Profile mode required").

The output should be copy-paste ready for a CONTEXT.md file so findings flow directly into downstream skills.

## Notes on Sensitive Data

- Never log or display raw values from HIGH RISK PII columns in the output artifact
- Redact sample values from quality flag examples if they come from MEDIUM or HIGH risk PII columns
- If the user declines profiling of HIGH RISK columns, exclude them from the output entirely and note "Excluded — PII risk"
