---
name: quality_flags
description: Data quality flag patterns and severity levels for profiling output. Load this during the Quality Flags phase to determine which issues to check and how to classify them.
type: reference
---

# Data Quality Flag Patterns

Check each category below and include findings in the Quality Flags section of the output artifact. Include severity, affected row count, percentage, and sample values where safe to show.

## Severity Levels

- **HIGH** — Data is incorrect, inconsistent, or unusable for modeling without remediation
- **MEDIUM** — Data may be correct but requires domain confirmation before use
- **LOW** — Cosmetic issue, worth noting but not blocking

---

## Structural Flags

### HIGH: All-Null Column
- **Detection**: `null_pct = 100`
- **Action**: Flag as potentially deprecated or not yet populated
- **Clarifying question**: "Is `{column}` expected to be null in this time period / environment?"

### HIGH: Zero-Variance Column (All Same Value)
- **Detection**: `distinct_count = 1` AND `null_pct < 100`
- **Action**: Flag constant value — possible ETL default or unused field
- **Clarifying question**: "Is `{column}` always `{value}`? Should it vary across records?"

### MEDIUM: High Null Rate (>50%)
- **Detection**: `null_pct > 50`
- **Action**: Note — sparse columns are common in wide tables, but may indicate a load issue
- **Clarifying question**: "When is `{column}` expected to be populated vs null?"

### MEDIUM: Single-Dominant Value (>95% one value)
- **Detection**: Top value frequency > 95% of non-null rows
- **Action**: Flag — may be a default value or degenerate dimension attribute
- **Clarifying question**: "Is `{value}` a meaningful default in `{column}` or a data loading artifact?"

---

## Date / Time Flags

### HIGH: Future Dates in a Historical Table
- **Detection**: `{date_column} > CURRENT_DATE`
- **Exception**: `expiry_date`, `term_date`, `next_renewal_date` legitimately have future dates
- **Action**: Flag count and sample future-dated rows. Distinguish sentinel values (9999-12-31) from errors
- **Clarifying question**: "Is `9999-12-31` (or similar) used as a sentinel for 'no expiry'?"

### HIGH: Impossible Dates
- **Detection**: Dates before `1900-01-01` or after `2099-12-31`
- **Action**: Flag as likely data error — show count

### HIGH: Date Inversion
- **Detection**: `effective_date > expiry_date` OR `start_date > end_date` OR `close_date < loss_date` OR `report_date < loss_date`
- **Action**: Flag all inverted records — show count and examples

### HIGH: Date Stored as String
- **Detection**: Column data type is VARCHAR/TEXT but values parse as dates
- **Action**: Flag format inconsistency; check if single format is used consistently
- **Check**: Are all values in the same format? (YYYY-MM-DD vs MM/DD/YYYY vs YYYYMMDD)

### MEDIUM: Wide Date Range (> 20 years)
- **Detection**: `MAX(date_col) - MIN(date_col) > 20 years`
- **Action**: Verify expected (historical data) vs data error — show min/max dates

### MEDIUM: Date Distribution Gaps
- **Detection**: Monthly distribution has gaps of 2+ consecutive months in an active table
- **Action**: Note gaps with dates — may indicate missing ETL loads or legitimate inactivity

### LOW: Time Zone Inconsistency
- **Detection**: TIMESTAMP column without explicit timezone on a system that crosses TZ boundaries
- **Action**: Note — may cause join issues with other timezone-aware tables

---

## Numeric / Amount Flags

### HIGH: Unexpected Negative Values
- **Detection**: `{amount_column} < 0` for columns like `premium`, `claim_amount`, `loss_amount`, `face_amount`, `deductible`
- **Exception**: `balance`, `adjustment`, `endorsement_amount`, `return_premium`, `ibnr` can legitimately be negative
- **Action**: Flag count and percentage; show sample negative values
- **Clarifying question**: "Can `{column}` be negative? Does a negative value represent a refund or credit?"

### HIGH: Statistical Outliers (> 5 standard deviations)
- **Detection**: Values beyond `mean ± 5 * stddev`
- **Action**: Flag and show up to 5 sample outlier values
- **Common causes**: Unit mismatch (cents vs dollars), test/dummy data, data entry error

### HIGH: Claim Exceeds Policy Limit
- **Detection** (when both tables available): `claim_amount > face_amount` on the same `policy_id`
- **Action**: Flag as likely error or note if subrogation / excess coverage applies

### MEDIUM: High Zero Rate in Amount Columns
- **Detection**: > 20% exact zeros in `premium`, `claim_amount`, `transaction_amount`
- **Action**: Flag percentage of zeros
- **Clarifying question**: "Do zero `{column}` values represent actual zeros or missing data?"

### MEDIUM: Suspiciously Round Numbers
- **Detection**: > 80% of values are divisible by 1000 (for columns expected to be precise)
- **Action**: Flag — may indicate default/placeholder values or rounding from a source system

### LOW: Mixed Orders of Magnitude
- **Detection**: Values ranging across > 6 orders of magnitude (e.g., 1 to 1,000,000+)
- **Action**: Check if column mixes raw values and aggregates, or multiple currencies/units

---

## String / Categorical Flags

### HIGH: Inconsistent Case
- **Detection**: Same string value appears in different cases (e.g., `'active'`, `'ACTIVE'`, `'Active'`)
- **Action**: Flag count of case variants; will break joins and lookups

### HIGH: Leading or Trailing Whitespace
- **Detection**: `LENGTH({column}) != LENGTH(TRIM({column}))` for any values
- **Action**: Flag — breaks joins, accepted_values tests, and lookups

### HIGH: Non-Unique Primary Key
- **Detection**: `COUNT(*) > COUNT(DISTINCT {pk_column})`
- **Action**: Show top 5 duplicate key values and their row counts

### MEDIUM: Mixed Date Formats in String Column
- **Detection**: String column contains both `YYYY-MM-DD` and `MM/DD/YYYY` formats
- **Action**: Flag for standardization before modeling

### MEDIUM: Unexpected Categorical Values
- **Detection**: Values not in a known valid code list (from `references/domain_patterns.md`)
- **Action**: Flag unknown values and their frequency
- **Clarifying question**: "What does `{unknown_value}` mean in `{column}`?"

### LOW: Special Characters
- **Detection**: Values containing control characters, null bytes, or non-ASCII in expected ASCII-only columns
- **Action**: Flag — can cause ETL parsing errors and comparison failures

---

## Relationship / Key Flags

### HIGH: Orphaned Foreign Keys
- **Detection**: FK values not present in the reference table
- **Action**: Flag count and percentage of orphans; show sample values
- **Clarifying question**: "Are records in `{table}` expected to exist without a matching row in `{ref_table}`?"

### MEDIUM: High FK Null Rate (> 10%)
- **Detection**: FK column with > 10% null where relationship is expected to be mandatory
- **Action**: Flag — may indicate optional relationship or a loading issue

### MEDIUM: Cardinality Mismatch
- **Detection**: Many-to-many join where one-to-many is expected based on column names
- **Action**: Note — may indicate a grain issue or a bridge table is needed

---

## Output Format

Format quality flag findings as:

```
## Quality Flags

### HIGH Severity (n issues)
- [Column: {column}] {Flag Name}
  Affected: {count} rows ({pct}%)
  Sample values: {val1}, {val2}, {val3}  ← omit for PII columns
  Recommendation: {action}

### MEDIUM Severity (n issues)
- [Column: {column}] {Flag Name}
  Affected: {count} rows ({pct}%)
  Note: {context}

### LOW Severity (n issues)
- [Column: {column}] {Flag Name}: {brief description}
```
