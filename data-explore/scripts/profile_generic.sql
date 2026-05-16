-- ============================================================
-- DATA EXPLORE: Generic ANSI SQL Profiling Queries
-- Works on most SQL databases as a fallback
-- Replace {schema}, {table}, {column} with actual values
-- ============================================================

-- ===== PHASE 1: SCHEMA DISCOVERY =====

-- 1a. Column metadata
SELECT
    column_name,
    data_type,
    is_nullable,
    character_maximum_length,
    numeric_precision,
    numeric_scale
FROM information_schema.columns
WHERE table_schema = '{schema}'
  AND table_name   = '{table}'
ORDER BY ordinal_position;

-- 1b. Row count
SELECT COUNT(*) AS total_rows
FROM {schema}.{table};

-- 1c. Sample rows
SELECT *
FROM {schema}.{table}
LIMIT 10;

-- ===== PHASE 2: COLUMN-LEVEL PROFILE =====
-- Run for each column. Replace {column} with the column name.

-- 2a. Null count and percentage
SELECT
    '{column}'                                                   AS column_name,
    COUNT(*)                                                     AS total_rows,
    COUNT({column})                                              AS non_null_count,
    COUNT(*) - COUNT({column})                                   AS null_count,
    ROUND(100.0 * (COUNT(*) - COUNT({column})) / COUNT(*), 2)   AS null_pct
FROM {schema}.{table};

-- 2b. Distinct value count
SELECT
    '{column}'               AS column_name,
    COUNT(DISTINCT {column}) AS distinct_count
FROM {schema}.{table};

-- 2c. Min / Max (cast to VARCHAR for universal compatibility)
SELECT
    MIN(CAST({column} AS VARCHAR)) AS min_val,
    MAX(CAST({column} AS VARCHAR)) AS max_val
FROM {schema}.{table}
WHERE {column} IS NOT NULL;

-- 2d. Top 10 most frequent values (for low-cardinality columns, distinct < 500)
SELECT
    {column}    AS value,
    COUNT(*)    AS frequency,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM {schema}.{table}
WHERE {column} IS NOT NULL
GROUP BY {column}
ORDER BY frequency DESC
LIMIT 10;

-- ===== PHASE 3: DISTRIBUTION (numeric columns only) =====

-- 3a. Basic statistics
SELECT
    MIN({column})    AS min_val,
    MAX({column})    AS max_val,
    AVG({column})    AS avg_val,
    STDDEV({column}) AS std_dev
FROM {schema}.{table}
WHERE {column} IS NOT NULL;

-- ===== PHASE 4: QUALITY FLAGS =====

-- 4a. Future dates (replace {date_column} with a date/timestamp column)
SELECT COUNT(*) AS future_date_count
FROM {schema}.{table}
WHERE {date_column} > CURRENT_DATE;

-- 4b. Date inversion (effective_date > expiry_date)
SELECT COUNT(*) AS inverted_date_count
FROM {schema}.{table}
WHERE {start_date_column} > {end_date_column};

-- 4c. Negative amounts (replace {amount_column} with a numeric column)
SELECT COUNT(*) AS negative_count
FROM {schema}.{table}
WHERE {amount_column} < 0;

-- 4d. Zero-variance check — if result = 1, the column has zero variance
SELECT COUNT(DISTINCT {column}) AS distinct_count
FROM {schema}.{table};

-- 4e. Non-unique primary key check
SELECT
    {pk_column},
    COUNT(*) AS row_count
FROM {schema}.{table}
GROUP BY {pk_column}
HAVING COUNT(*) > 1
LIMIT 20;

-- ===== PHASE 5: RELATIONSHIP MAPPING =====

-- 5a. FK candidate — check if values are a subset of a reference table
SELECT COUNT(*) AS unmatched_count
FROM {schema}.{table} t
LEFT JOIN {ref_schema}.{ref_table} r ON t.{column} = r.{ref_column}
WHERE r.{ref_column} IS NULL
  AND t.{column}     IS NOT NULL;

-- 5b. Cardinality check between two join keys
SELECT
    COUNT(DISTINCT a.{col_a}) AS distinct_a,
    COUNT(DISTINCT b.{col_b}) AS distinct_b
FROM {schema}.{table_a} a
JOIN {schema}.{table_b} b ON a.{col_a} = b.{col_b};
