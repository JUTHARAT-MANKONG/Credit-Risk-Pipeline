/*
============================================================
 03_provision_breakdown.sql
 แจกแจง Provision รายกลุ่ม Loan Status
============================================================
*/

-- ส่วนที่ 1: Provision รายเดือน แจกแจงตาม Loan Status
SELECT
    txn_month                                           AS "เดือน",

    -- Performing
    ROUND(SUM(provision_amount_thb)
        FILTER (WHERE loan_status = 'Performing'), 2)   AS "Provision - Performing (THB)",

    -- Under-Performing
    ROUND(SUM(provision_amount_thb)
        FILTER (WHERE loan_status = 'Under-Performing'), 2)  AS "Provision - Under-Performing (THB)",

    -- NPL
    ROUND(SUM(provision_amount_thb)
        FILTER (WHERE loan_status = 'NPL'), 2)          AS "Provision - NPL (THB)",

    -- รวม
    ROUND(SUM(provision_amount_thb), 2)                 AS "Provision รวม (THB)"

FROM silver.loan_accounts
GROUP BY txn_month
ORDER BY txn_month;


-- ส่วนที่ 2: Provision แจกแจงตาม Delinquency Status
SELECT
    delinquency_status                                  AS "Delinquency",
    loan_status                                         AS "Loan Status",
    ROUND(provision_rate * 100, 0)                      AS "Provision Rate (%%)",
    COUNT(*)                                            AS "จำนวนบัญชี",
    ROUND(SUM(orig_balance_thb), 2)                     AS "ยอดหนี้รวม (THB)",
    ROUND(SUM(provision_amount_thb), 2)                 AS "เงินสำรองรวม (THB)"
FROM silver.loan_accounts
GROUP BY delinquency_status, loan_status, provision_rate
ORDER BY provision_rate;