# Data Profile: `{schema}.{table}`

**Explored:** {YYYY-MM-DD}
**Warehouse:** {Snowflake | Redshift | BigQuery | Generic SQL}
**Row Count:** {n} {rows | sampled rows (10% sample — estimated total: {n})}

---

## Quick Scan

### PII Gate

| Column | Pattern Matched | Risk |
|--------|-----------------|------|
| `{col}` | {pattern} | HIGH — Excluded |
| `{col}` | {pattern} | MEDIUM — Included |

*No PII column names detected.* ← use this line if nothing was found

### Schema Summary

| Column | Type | Nullable | Notes |
|--------|------|----------|-------|
| `{col}` | {type} | Y/N | {e.g. possible PK, date column, etc.} |

**Grain:** One row per {inferred grain — confirm with data owner}
**Primary Key Candidate:** `{column}` {(unique: yes/no)}
**Key Date Columns:** `{col}` (likely business date), `{col}` (likely audit date)
**Sample (10 rows):** {brief description of what sample revealed, or "see raw output"}

---

## Deep Profile

*Not run — re-invoke with "deep profile" to continue.*

### Column-Level Profile

<!-- Repeat this block for each profiled column -->
#### `{column_name}`
- **Type:** {data_type} | **Nullable:** {Y/N}
- **Null:** {pct}% ({count} / {total} rows)
- **Distinct:** {count} {(approx)}
- **Range:** {min_val} → {max_val}
- **Top Values:**

  | Value | Count | % |
  |-------|-------|---|
  | {val} | {n}   | {pct}% |

---

### Distribution Summary

#### `{numeric_column}` (numeric)
| p01 | p25 | p50 | p75 | p95 | p99 | Mean | StdDev |
|-----|-----|-----|-----|-----|-----|------|--------|
| {v} | {v} | {v} | {v} | {v} | {v} | {v}  | {v}    |

Outliers (> 5σ): {count} rows

#### `{date_column}` (date)
- Range: {min_date} → {max_date}
- Monthly distribution:

  | Month | Row Count |
  |-------|-----------|
  | {YYYY-MM} | {n} |

---

### Quality Flags

#### HIGH Severity ({n} issues)
- **[`{column}`] {Flag Name}**
  Affected: {count} rows ({pct}%)
  Sample values: `{val1}`, `{val2}`, `{val3}`
  Recommendation: {action}

#### MEDIUM Severity ({n} issues)
- **[`{column}`] {Flag Name}**
  Affected: {count} rows ({pct}%)
  Note: {context}

#### LOW Severity ({n} issues)
- **[`{column}`] {Flag Name}:** {brief description}

---

### Relationship Map

| Column | Likely FK To | Cardinality | Unmatched Rows |
|--------|-------------|-------------|----------------|
| `{col}` | `{ref_table}.{ref_col}` | many-to-one | {count} ({pct}%) |

---

### Open Questions

1. `{column}` has values `{v1}`, `{v2}`, `{v3}` — what does each value mean?
2. Is `{column}` the business effective date or the system load date?
3. Can `{column}` be negative? Does a negative value represent a refund or credit?
4. Are zero values in `{column}` meaningful or missing data?
5. Is `{value}` in `{column}` a sentinel value (e.g., "9999-12-31" for no expiry)?
