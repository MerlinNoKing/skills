# Data Explore Output Template

Copy this template and fill in the findings from the profiling run.
This format is designed to be copy-pasted directly into a CONTEXT.md file
and consumed by downstream skills (/to-prd, /grill-with-docs, /dbt-test).

---

## Table: `{schema}.{table}`

**Explored:** {YYYY-MM-DD}
**Mode:** {Quick Scan | Deep Profile}
**Warehouse:** {Snowflake | Redshift | BigQuery | Generic SQL}
**Row Count:** {n} {rows | sampled rows (10% sample — estimated total: {n})}
**Last Modified:** {date if available}

---

### Schema Summary

| Column | Type | Nullable | Null % | Distinct | Min | Max |
|--------|------|----------|--------|----------|-----|-----|
| {col}  | {type} | {Y/N} | {pct}% | {n} | {val} | {val} |

**Grain:** One row per {inferred grain — confirm with domain expert}
**Primary Key Candidate:** `{column}` {(unique: yes/no)}
**Natural Sort / Partition Key:** `{column}` {if identified}
**Key Date Columns:** `{col}` (business date), `{col}` (audit date)

---

### Column Profiles

<!-- Repeat this block for each profiled column -->
#### `{column_name}`
- **Type:** {data_type} | **Nullable:** {Y/N}
- **Null:** {pct}% ({count} / {total} rows)
- **Distinct:** {count} {(approx)} {(low cardinality: yes/no)}
- **Range:** {min_val} → {max_val}
- **Top Values:**

  | Value | Count | % |
  |-------|-------|---|
  | {val} | {n}   | {pct}% |

- **Domain Note:** {inferred meaning from domain_patterns.md, or "Unknown — see Open Questions"}
- **PII Risk:** {None | MEDIUM: {pattern} | HIGH: {pattern} — excluded from profiling}

---

### Distribution Summary *(Deep Profile only)*

#### `{numeric_column}` (numeric)
| p01 | p25 | p50 | p75 | p95 | p99 | Mean | StdDev |
|-----|-----|-----|-----|-----|-----|------|--------|
| {v} | {v} | {v} | {v} | {v} | {v} | {v}  | {v}    |

Outliers (> 3σ): {count} rows

#### `{date_column}` (date)
- Range: {min_date} → {max_date}
- Monthly distribution:

  | Month | Row Count |
  |-------|-----------|
  | {YYYY-MM} | {n} |

---

### Relationship Map *(Deep Profile only)*

| Column | Likely FK To | Cardinality | Unmatched Rows |
|--------|-------------|-------------|----------------|
| `{col}` | `{ref_table}.{ref_col}` | many-to-one | {count} ({pct}%) |

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

### PII / Sensitive Columns

| Column | Pattern Matched | Risk | Profiling Action |
|--------|-----------------|------|-----------------|
| `{col}` | {pattern} | HIGH | Excluded — hash count only |
| `{col}` | {pattern} | MEDIUM | Included with user consent |

---

### Domain Glossary

<!-- Add confirmed and inferred column meanings here -->

| Term | Definition | Confidence |
|------|------------|-----------|
| `{column} = {value}` | {business meaning} | Confirmed / Inferred |
| `{column}` | {business purpose} | Confirmed / Inferred |

---

### Open Questions

Questions requiring domain expert clarification before modeling:

1. `{column}` has values `{v1}`, `{v2}`, `{v3}` — what does each value mean?
2. Is `{column}` the business effective date or the system load date?
3. Can `{column}` be negative? Does a negative value represent a refund or credit?
4. Are zero values in `{column}` meaningful or missing data?
5. Is `{value}` in `{column}` a sentinel value (e.g., "9999-12-31" for no expiry)?

---

### Recommended Next Steps

- [ ] Confirm domain glossary entries with domain expert
- [ ] Resolve HIGH severity quality flags before building dbt models
- [ ] Build dbt source YAML with column descriptions from this profile
- [ ] Add `not_null` tests for: {list columns}
- [ ] Add `unique` test for: {primary key column}
- [ ] Add `accepted_values` tests for: {list status columns with known codes}
- [ ] Add `relationships` tests for: {list FK columns}
- [ ] Consider partitioning/sorting on: {date column}
- [ ] Flag for data eng remediation: {list HIGH severity quality issues}
