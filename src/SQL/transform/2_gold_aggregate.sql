/*
============================================================
gold_aggregate.sql
สรุปข้อมูลจาก Silver → Gold
คำนวณ KPI 3 ตัวตาม BRD สรุปรายเดือน
============================================================
*/

TRUNCATE TABLE gold.monthly_credit_risk_report;

INSERT INTO gold.monthly_credit_risk_report (
    report_month,
    total_accounts,
    outstanding_balance_thb,
    npl_accounts,
    npl_ratio_pct,
    total_provision_thb,
    performing_accounts,
    performing_balance_thb,
    performing_provision_thb,
    under_performing_accounts,
    under_performing_balance_thb,
    under_performing_provision_thb,
    npl_balance_thb,
    npl_provision_thb
)

-- CTE (Common Table Expression)
-- คือการ "ตั้งชื่อ" ผลลัพธ์ชั่วคราวไว้ใช้ซ้ำ
-- แก้ปัญหาที่ Bronze เจอ (ต้องเขียน CASE ซ้ำหลายรอบ)

WITH

-- Step 1: สรุปรายเดือนแบบ Breakdown
monthly_summary AS (
    SELECT
        txn_month                                      AS report_month,

        -- KPI ที่ 1: Outstanding Balance 
        COUNT(*)                                       AS total_accounts,
        ROUND(SUM(orig_balance_thb), 2)                AS outstanding_balance_thb,

        -- KPI ที่ 2: นับ NPL
        COUNT(*) FILTER (WHERE loan_status = 'NPL')    AS npl_accounts,

        -- KPI ที่ 3: Provision 
        ROUND(SUM(provision_amount_thb), 2)            AS total_provision_thb,

        -- Breakdown: Performing
        COUNT(*) FILTER (WHERE loan_status = 'Performing')   AS performing_accounts,
        ROUND(SUM(orig_balance_thb)
            FILTER (WHERE loan_status = 'Performing'), 2)    AS performing_balance_thb,
        ROUND(SUM(provision_amount_thb)
            FILTER (WHERE loan_status = 'Performing'), 2)    AS performing_provision_thb,

        -- Breakdown: Under-Performing 
        COUNT(*) FILTER (WHERE loan_status = 'Under-Performing')  AS under_performing_accounts,
        ROUND(SUM(orig_balance_thb)
            FILTER (WHERE loan_status = 'Under-Performing'), 2)   AS under_performing_balance_thb,
        ROUND(SUM(provision_amount_thb)
            FILTER (WHERE loan_status = 'Under-Performing'), 2)   AS under_performing_provision_thb,

        -- Breakdown: NPL 
        ROUND(SUM(orig_balance_thb)
            FILTER (WHERE loan_status = 'NPL'), 2)    AS npl_balance_thb,
        ROUND(SUM(provision_amount_thb)
            FILTER (WHERE loan_status = 'NPL'), 2)    AS npl_provision_thb

    FROM silver.loan_accounts
    GROUP BY txn_month
),

-- Step 2: คำนวณ NPL Ratio จาก Step 1
-- แยกออกมาเป็น CTE ใหม่ เพราะต้องใช้ค่าที่คำนวณจาก Step 1
-- (SQL ไม่ให้ใช้ alias ที่เพิ่งสร้างในขั้นเดียวกัน)
monthly_with_ratio AS (
    SELECT *,
        ROUND(
            npl_accounts::NUMERIC / NULLIF(total_accounts, 0) * 100, 4)   AS npl_ratio_pct
        -- NULLIF(total_accounts, 0) ป้องกัน divide by zero
        -- ถ้า total_accounts = 0 จะคืนค่า NULL แทน error
    FROM monthly_summary
)

-- Final Select
SELECT
    report_month,
    total_accounts,
    outstanding_balance_thb,
    npl_accounts,
    npl_ratio_pct,
    total_provision_thb,
    performing_accounts,
    performing_balance_thb,
    performing_provision_thb,
    under_performing_accounts,
    under_performing_balance_thb,
    under_performing_provision_thb,
    npl_balance_thb,
    npl_provision_thb
FROM monthly_with_ratio
ORDER BY report_month;