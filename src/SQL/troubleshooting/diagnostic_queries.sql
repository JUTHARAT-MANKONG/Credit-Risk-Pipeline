/*
============================================================
 diagnostic_queries.sql
 SQL ใช้ตรวจสอบปัญหาใน Production
 เปิดไฟล์นี้เมื่อ Pipeline พัง หรือ Report ตัวเลขผิด
============================================================
*/

-- ════════════════════════════════════════════════════════════
-- SECTION 1: ตรวจสอบ Pipeline Run Log
-- ใช้ดูว่า Pipeline รันครั้งล่าสุดสำเร็จหรือไม่
-- ════════════════════════════════════════════════════════════

-- Q1: ดู Pipeline Run ล่าสุด 10 ครั้ง
SELECT
    run_id,
    pipeline_name,
    step_name,
    status,
    started_at,
    finished_at,
    duration_sec,
    rows_processed,
    error_message
FROM gold.pipeline_run_log
ORDER BY run_id DESC
LIMIT 10;

-- Q2: ดู Step ที่ FAILED ทั้งหมด
SELECT
    run_id,
    step_name,
    started_at,
    error_message
FROM gold.pipeline_run_log
WHERE status = 'FAILED'
ORDER BY run_id DESC;

-- Q3: ดูเวลาเฉลี่ยของแต่ละ Step 
-- ใช้ตรวจว่า Step ไหนช้าผิดปกติ
SELECT
    step_name,
    COUNT(*)                            AS total_runs,
    ROUND(AVG(duration_sec), 2)         AS avg_duration_sec,
    ROUND(MAX(duration_sec), 2)         AS max_duration_sec,
    ROUND(MIN(duration_sec), 2)         AS min_duration_sec
FROM gold.pipeline_run_log
WHERE status = 'SUCCESS'
GROUP BY step_name
ORDER BY avg_duration_sec DESC;


-- ════════════════════════════════════════════════════════════
-- SECTION 2: ตรวจสอบข้อมูลใน Raw Layer
-- ใช้เมื่อสงสัยว่าข้อมูลต้นทางผิดปกติ
-- ════════════════════════════════════════════════════════════

-- Q4: นับแถวใน raw.financial_transactions
SELECT
    COUNT(*)                            AS total_rows,
    COUNT(DISTINCT cust_id)             AS unique_customers,
    COUNT(DISTINCT txn_id)              AS unique_transactions,
    MIN(_loaded_at)                     AS first_loaded,
    MAX(_loaded_at)                     AS last_loaded
FROM raw.financial_transactions;

-- Q5: ตรวจสอบ FX Rate ว่าครบทุกเดือนและทุกสกุลเงิน
SELECT
    rate_month,
    COUNT(DISTINCT currency_code)       AS currency_count,
    STRING_AGG(currency_code, ', ')     AS currencies
FROM raw.fx_rate
GROUP BY rate_month
ORDER BY rate_month;


-- ════════════════════════════════════════════════════════════
-- SECTION 3: ตรวจสอบ Bronze Layer
-- ════════════════════════════════════════════════════════════

-- Q6: นับแถวใน Bronze และ Quarantine
SELECT 'bronze.financial_transactions'  AS table_name,
        COUNT(*)                        AS row_count
FROM bronze.financial_transactions
UNION ALL
SELECT 'bronze.quarantine_log',
        COUNT(*)
FROM bronze.quarantine_log;

-- Q7: ดู Quarantine ล่าสุด ว่า Error อะไร 
SELECT
    cust_id,
    txn_id,
    failed_column,
    failed_value,
    failure_reason,
    quarantined_at
FROM bronze.quarantine_log
ORDER BY quarantined_at DESC
LIMIT 20;

-- Q8: ตรวจ Delinquency Status ใน Bronze 
-- ต้องมีแค่ M0, M1, M2, M3, M4+ เท่านั้น
SELECT
    delinquency_status,
    COUNT(*)                            AS row_count
FROM bronze.financial_transactions
GROUP BY delinquency_status
ORDER BY delinquency_status;


-- ════════════════════════════════════════════════════════════
-- SECTION 4: ตรวจสอบ Silver Layer
-- ════════════════════════════════════════════════════════════

-- Q9: นับแถวและตรวจ NULL ใน Silver 
SELECT
    COUNT(*)                            AS total_rows,
    COUNT(*) FILTER (WHERE cust_id IS NULL)             AS null_cust_id,
    COUNT(*) FILTER (WHERE orig_balance_thb IS NULL)    AS null_balance,
    COUNT(*) FILTER (WHERE loan_status IS NULL)         AS null_loan_status,
    COUNT(*) FILTER (WHERE provision_amount_thb IS NULL) AS null_provision,
    COUNT(*) FILTER (WHERE fx_rate_to_thb IS NULL)      AS null_fx_rate
FROM silver.loan_accounts;

-- Q10: ตรวจ Loan Status Distribution 
SELECT
    loan_status,
    COUNT(*)                            AS accounts,
    ROUND(SUM(orig_balance_thb), 2)     AS total_balance_thb,
    ROUND(SUM(provision_amount_thb), 2) AS total_provision_thb
FROM silver.loan_accounts
GROUP BY loan_status
ORDER BY loan_status;

-- Q11: ตรวจ FX Rate ที่ใช้จริงใน Silver
SELECT
    txn_currency,
    txn_month,
    fx_rate_to_thb,
    COUNT(*)                            AS transaction_count
FROM silver.loan_accounts
GROUP BY txn_currency, txn_month, fx_rate_to_thb
ORDER BY txn_month, txn_currency;


-- ════════════════════════════════════════════════════════════
-- SECTION 5: ตรวจสอบ Gold Layer
-- ════════════════════════════════════════════════════════════

-- Q12: ดู KPI Report ทั้งหมด 
SELECT
    report_month,
    total_accounts,
    ROUND(outstanding_balance_thb, 2)   AS outstanding_balance_thb,
    npl_accounts,
    npl_ratio_pct,
    ROUND(total_provision_thb, 2)       AS total_provision_thb
FROM gold.monthly_credit_risk_report
ORDER BY report_month;

-- Q13: ตรวจว่า Gold ตรงกับ Silver ไหม (Quick Recon) 
SELECT
    'silver_total_accounts'             AS metric,
    COUNT(*)::TEXT                      AS value
FROM silver.loan_accounts
UNION ALL
SELECT
    'gold_sum_total_accounts',
    COALESCE(SUM(total_accounts), 0)::TEXT
FROM gold.monthly_credit_risk_report
UNION ALL
SELECT
    'silver_total_balance_thb',
    ROUND(SUM(orig_balance_thb), 2)::TEXT
FROM silver.loan_accounts
UNION ALL
SELECT
    'gold_sum_outstanding_balance_thb',
    ROUND(SUM(outstanding_balance_thb), 2)::TEXT
FROM gold.monthly_credit_risk_report;