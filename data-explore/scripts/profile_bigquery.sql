-- ============================================================
-- DATA EXPLORE: Google BigQuery-Specific Profiling Queries
-- Replace {project}, {dataset}, {table}, {column} with actual values
-- Use backtick notation for fully-qualified names: `{project}.{dataset}.{table}`
-- ============================================================

-- ===== PHASE 1: SCHEMA DISCOVERY =====

-- 1a. Column metadata including nested/repeated fields
SELECT
    column_name,
    data_type,
    is_nullable,
    is_partitioning_column,
    clustering_ordinal_position
FROM `{project}.{dataset}`.INFORMATION_SCHEMA.COLUMNS
WHERE table_name = '{table}'
ORDER BY ordinal_position;

-- 1b. Table size and row count from metadata (no scan, no cost)
SELECT
    table_id,
    row_count,
    ROUND(size_bytes / (1024.0 * 1024 * 1024), 3) AS size_gb,
    TIMESTAMP_MILLIS(last_modified_time)            AS last_modified
FROM `{project}.{dataset}.__TABLES__`
WHERE table_id = '{table}';

-- 1c. Partition information
SELECT
    partition_id,
    total_rows,
    total_logical_bytes,
    last_modified_time
FROM `{project}.{dataset}.INFORMATION_SCHEMA.PARTITIONS`
WHERE table_name = '{table}'
ORDER BY partition_id DESC
LIMIT 20;

-- 1d. Sample rows
SELECT * FROM `{project}.{dataset}.{table}` LIMIT 10;

-- ===== SAMPLING (use for tables > 10M rows) =====
-- Use TABLESAMPLE to avoid full scan costs
SELECT * FROM `{project}.{dataset}.{table}` TABLESAMPLE SYSTEM (10 PERCENT);

-- ===== PHASE 2: COLUMN-LEVEL PROFILE =====

-- 2a. Full column profile — null, distinct, min, max in one pass
SELECT
    '{column}'                                                     AS column_name,
    COUNT(*)                                                       AS total_rows,
    COUNTIF({column} IS NOT NULL)                                  AS non_null_count,
    COUNTIF({column} IS NULL)                                      AS null_count,
    ROUND(100.0 * COUNTIF({column} IS NULL) / COUNT(*), 2)        AS null_pct,
    APPROX_COUNT_DISTINCT({column})                                AS approx_distinct,
    CAST(MIN({column}) AS STRING)                                  AS min_val,
    CAST(MAX({column}) AS STRING)                                  AS max_val
FROM `{project}.{dataset}.{table}`;

-- 2b. Top 10 most frequent values
SELECT
    CAST({column} AS STRING) AS value,
    COUNT(*)                 AS frequency,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM `{project}.{dataset}.{table}`
WHERE {column} IS NOT NULL
GROUP BY {column}
ORDER BY frequency DESC
LIMIT 10;

-- ===== PHASE 3: DISTRIBUTION (numeric columns) =====

-- 3a. Full percentile distribution using APPROX_QUANTILES (cost-efficient)
SELECT
    APPROX_QUANTILES({column}, 100)[OFFSET(1)]  AS p01,
    APPROX_QUANTILES({column}, 100)[OFFSET(25)] AS p25,
    APPROX_QUANTILES({column}, 100)[OFFSET(50)] AS p50,
    APPROX_QUANTILES({column}, 100)[OFFSET(75)] AS p75,
    APPROX_QUANTILES({column}, 100)[OFFSET(95)] AS p95,
    APPROX_QUANTILES({column}, 100)[OFFSET(99)] AS p99,
    AVG({column})                               AS avg_val,
    STDDEV({column})                            AS std_dev
FROM `{project}.{dataset}.{table}`
WHERE {column} IS NOT NULL;

-- 3b. Date distribution by month
SELECT
    DATE_TRUNC({date_column}, MONTH) AS month_bucket,
    COUNT(*)                         AS row_count
FROM `{project}.{dataset}.{table}`
WHERE {date_column} IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- ===== PHASE 4: QUALITY FLAGS =====

-- 4a. Future dates
SELECT COUNT(*) AS future_date_count
FROM `{project}.{dataset}.{table}`
WHERE {date_column} > CURRENT_DATE();

-- 4b. Negative amounts
SELECT COUNT(*) AS negative_count
FROM `{project}.{dataset}.{table}`
WHERE {amount_column} < 0;

-- 4c. Format check (string columns that should be dates)
SELECT
    {column},
    SAFE_CAST({column} AS DATE) AS parsed_date,
    CASE WHEN SAFE_CAST({column} AS DATE) IS NULL THEN 'INVALID' ELSE 'VALID' END AS format_status
FROM `{project}.{dataset}.{table}`
WHERE {column} IS NOT NULL
LIMIT 20;

-- 4d. Non-unique primary key
SELECT {pk_column}, COUNT(*) AS row_count
FROM `{project}.{dataset}.{table}`
GROUP BY {pk_column}
HAVING COUNT(*) > 1
LIMIT 20;

-- ===== PHASE 5: RELATIONSHIP MAPPING =====

-- 5a. FK candidate check
SELECT COUNT(*) AS unmatched_count
FROM `{project}.{dataset}.{table}` t
LEFT JOIN `{project}.{ref_dataset}.{ref_table}` r ON t.{column} = r.{ref_column}
WHERE r.{ref_column} IS NULL
  AND t.{column}     IS NOT NULL;

-- ===== PII SAFE: Hash-based distinct count (HIGH risk columns only) =====
SELECT COUNT(DISTINCT TO_HEX(MD5(CAST({column} AS STRING)))) AS hashed_distinct_count
FROM `{project}.{dataset}.{table}`
WHERE {column} IS NOT NULL;
