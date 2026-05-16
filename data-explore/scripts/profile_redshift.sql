-- ============================================================
-- DATA EXPLORE: Amazon Redshift-Specific Profiling Queries
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

-- 1b. Table size and row count from catalog (no scan needed)
SELECT
    "table"                        AS table_name,
    tbl_rows                       AS row_count,
    ROUND(size * 1.0 / 1024, 3)   AS size_gb,
    pct_used
FROM svv_table_info
WHERE schema = '{schema}'
  AND "table" = '{table}';

-- 1c. Sort key and dist key information
SELECT
    column_name,
    sortkey,
    distkey
FROM svv_columns
WHERE table_schema = '{schema}'
  AND table_name   = '{table}'
  AND (sortkey <> 0 OR distkey = true)
ORDER BY sortkey;

-- 1d. Sample rows
SELECT * FROM {schema}.{table} LIMIT 10;

-- ===== SAMPLING (use for tables > 10M rows) =====
SELECT * FROM {schema}.{table} TABLESAMPLE SYSTEM (10);

-- ===== PHASE 2: COLUMN-LEVEL PROFILE =====

-- 2a. Null count and percentage
SELECT
    '{column}'                                                   AS column_name,
    COUNT(*)                                                     AS total_rows,
    COUNT({column})                                              AS non_null_count,
    COUNT(*) - COUNT({column})                                   AS null_count,
    ROUND(100.0 * (COUNT(*) - COUNT({column})) / COUNT(*), 2)   AS null_pct
FROM {schema}.{table};

-- 2b. Approximate distinct count (Redshift HyperLogLog — fast, no full scan)
SELECT APPROXIMATE COUNT(DISTINCT {column}) AS approx_distinct_count
FROM {schema}.{table};

-- 2c. Min / Max
SELECT
    MIN({column}) AS min_val,
    MAX({column}) AS max_val
FROM {schema}.{table}
WHERE {column} IS NOT NULL;

-- 2d. Top 10 most frequent values
SELECT
    {column}  AS value,
    COUNT(*) AS frequency
FROM {schema}.{table}
WHERE {column} IS NOT NULL
GROUP BY {column}
ORDER BY frequency DESC
LIMIT 10;

-- 2e. Column statistics from catalog (fastest — no scan at all)
SELECT
    attname          AS column_name,
    stanullfrac      AS null_fraction,
    stawidth         AS avg_width_bytes,
    stadistinct      AS distinct_count_estimate
FROM pg_statistic
JOIN pg_attribute  ON attrelid = starelid AND attnum = staattnum
JOIN pg_class      ON pg_class.oid = starelid
JOIN pg_namespace  ON pg_namespace.oid = pg_class.relnamespace
WHERE nspname = '{schema}'
  AND relname = '{table}';

-- ===== PHASE 3: DISTRIBUTION (numeric columns) =====

-- 3a. Percentile distribution
SELECT
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {column}) AS p25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY {column}) AS p50,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {column}) AS p75,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY {column}) AS p95,
    AVG({column})                                          AS avg_val,
    STDDEV({column})                                       AS std_dev
FROM {schema}.{table}
WHERE {column} IS NOT NULL;

-- 3b. Date distribution by month
SELECT
    DATE_TRUNC('month', {date_column}) AS month_bucket,
    COUNT(*)                           AS row_count
FROM {schema}.{table}
WHERE {date_column} IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- ===== PHASE 4: QUALITY FLAGS =====

-- 4a. Future dates
SELECT COUNT(*) AS future_date_count
FROM {schema}.{table}
WHERE {date_column} > CURRENT_DATE;

-- 4b. Negative amounts
SELECT COUNT(*) AS negative_count
FROM {schema}.{table}
WHERE {amount_column} < 0;

-- 4c. Non-unique primary key
SELECT {pk_column}, COUNT(*) AS row_count
FROM {schema}.{table}
GROUP BY {pk_column}
HAVING COUNT(*) > 1
LIMIT 20;

-- ===== PHASE 5: RELATIONSHIP MAPPING =====

-- 5a. FK candidate check
SELECT COUNT(*) AS unmatched_count
FROM {schema}.{table} t
LEFT JOIN {ref_schema}.{ref_table} r ON t.{column} = r.{ref_column}
WHERE r.{ref_column} IS NULL
  AND t.{column}     IS NOT NULL;

-- ===== PII SAFE: Hash-based distinct count (HIGH risk columns only) =====
SELECT COUNT(DISTINCT MD5({column})) AS hashed_distinct_count
FROM {schema}.{table}
WHERE {column} IS NOT NULL;
