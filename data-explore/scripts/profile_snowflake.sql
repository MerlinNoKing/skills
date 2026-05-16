-- ============================================================
-- DATA EXPLORE: Snowflake-Specific Profiling Queries
-- Prefer these over generic SQL for performance on Snowflake
-- Replace {database}, {schema}, {table}, {column} with actual values
-- ============================================================

-- ===== PHASE 1: SCHEMA DISCOVERY =====

-- 1a. Column metadata with comments
SELECT
    column_name,
    data_type,
    is_nullable,
    character_maximum_length,
    numeric_precision,
    numeric_scale,
    column_default,
    comment
FROM {database}.information_schema.columns
WHERE table_schema = UPPER('{schema}')
  AND table_name   = UPPER('{table}')
ORDER BY ordinal_position;

-- 1b. Table size and row count from metadata (no scan needed)
SELECT
    table_name,
    row_count,
    ROUND(bytes / (1024.0 * 1024 * 1024), 3) AS size_gb,
    last_altered
FROM {database}.information_schema.tables
WHERE table_schema = UPPER('{schema}')
  AND table_name   = UPPER('{table}');

-- 1c. Clustering information
SELECT SYSTEM$CLUSTERING_INFORMATION('{schema}.{table}');

-- 1d. Sample rows
SELECT * FROM {schema}.{table} LIMIT 10;

-- ===== SAMPLING (use for tables > 10M rows) =====
-- Replaces full table scans in all subsequent queries
SELECT * FROM {schema}.{table} TABLESAMPLE BERNOULLI (10);

-- ===== PHASE 2: COLUMN-LEVEL PROFILE =====

-- 2a. Full column profile — null, distinct, min, max in one scan
SELECT
    '{column}'                                                  AS column_name,
    COUNT(*)                                                    AS total_rows,
    COUNT({column})                                             AS non_null_count,
    COUNT(*) - COUNT({column})                                  AS null_count,
    ROUND(100.0 * (COUNT(*) - COUNT({column})) / COUNT(*), 2)  AS null_pct,
    APPROX_COUNT_DISTINCT({column})                             AS approx_distinct,
    MIN({column})                                               AS min_val,
    MAX({column})                                               AS max_val
FROM {schema}.{table};

-- 2b. Top 10 most frequent values
SELECT
    {column}  AS value,
    COUNT(*)  AS frequency,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM {schema}.{table}
WHERE {column} IS NOT NULL
GROUP BY {column}
ORDER BY frequency DESC
LIMIT 10;

-- ===== PHASE 3: DISTRIBUTION (numeric columns) =====

-- 3a. Full percentile distribution (Snowflake native PERCENTILE_CONT)
SELECT
    PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY {column}) AS p01,
    PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY {column}) AS p05,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY {column}) AS p25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY {column}) AS p50,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY {column}) AS p75,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY {column}) AS p95,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY {column}) AS p99,
    AVG({column})                                           AS avg_val,
    STDDEV({column})                                        AS std_dev
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
WHERE {date_column} > CURRENT_DATE();

-- 4b. Negative amounts
SELECT COUNT(*) AS negative_count
FROM {schema}.{table}
WHERE {amount_column} < 0;

-- 4c. Format consistency check (string columns that should be dates)
SELECT
    {column},
    TRY_TO_DATE({column}) AS parsed_date,
    CASE WHEN TRY_TO_DATE({column}) IS NULL THEN 'INVALID' ELSE 'VALID' END AS format_status
FROM {schema}.{table}
WHERE {column} IS NOT NULL
LIMIT 20;

-- 4d. Non-unique primary key
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

-- 5b. Cardinality between two join keys
SELECT
    COUNT(DISTINCT a.{col_a})                                            AS distinct_a,
    COUNT(DISTINCT b.{col_b})                                            AS distinct_b,
    COUNT(DISTINCT a.{col_a}) / NULLIF(COUNT(DISTINCT b.{col_b}), 0)    AS ratio_a_to_b
FROM {schema}.{table_a} a
JOIN {schema}.{table_b} b ON a.{col_a} = b.{col_b};

-- ===== PII SAFE: Hash-based distinct count (HIGH risk columns only) =====
-- Use this instead of COUNT(DISTINCT {column}) to avoid exposing values in logs
SELECT COUNT(DISTINCT MD5({column}::STRING)) AS hashed_distinct_count
FROM {schema}.{table}
WHERE {column} IS NOT NULL;
