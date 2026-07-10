/*
============================================================
 2_npl_analysis.sql
 วิเคราะห์ NPL เชิงลึก แจกแจงตาม Region และ Account Type
============================================================
*/

-- ส่วนที่ 1: NPL รายเดือน พร้อม Trend
SELECT
    txn_month                                           AS "เดือน",
    COUNT(*) FILTER (WHERE loan_status = 'NPL')         AS "NPL Accounts",
    COUNT(*)                                            AS "Total Accounts",
    ROUND(
        COUNT(*) FILTER (WHERE loan_status = 'NPL')::NUMERIC
        / NULLIF(COUNT(*), 0) * 100
    , 4)                                                AS "NPL Ratio (%%)",
    ROUND(SUM(orig_balance_thb)
        FILTER (WHERE loan_status = 'NPL'), 2)          AS "NPL Balance (THB)"
FROM silver.loan_accounts
GROUP BY txn_month
ORDER BY txn_month;


-- ส่วนที่ 2: NPL แจกแจงตาม Region 
SELECT
    primary_branch_region                               AS "Region",
    COUNT(*) FILTER (WHERE loan_status = 'NPL')         AS "NPL Accounts",
    COUNT(*)                                            AS "Total Accounts",
    ROUND(
        COUNT(*) FILTER (WHERE loan_status = 'NPL')::NUMERIC
        / NULLIF(COUNT(*), 0) * 100
    , 4)                                                AS "NPL Ratio (%%)",
    ROUND(SUM(orig_balance_thb)
        FILTER (WHERE loan_status = 'NPL'), 2)          AS "NPL Balance (THB)"
FROM silver.loan_accounts
GROUP BY primary_branch_region
ORDER BY "NPL Ratio (%%)" DESC;


-- ส่วนที่ 3: NPL แจกแจงตาม Account Type
SELECT
    account_type                                        AS "Account Type",
    COUNT(*) FILTER (WHERE loan_status = 'NPL')         AS "NPL Accounts",
    COUNT(*)                                            AS "Total Accounts",
    ROUND(
        COUNT(*) FILTER (WHERE loan_status = 'NPL')::NUMERIC
        / NULLIF(COUNT(*), 0) * 100
    , 4)                                                AS "NPL Ratio (%%)",
    ROUND(SUM(orig_balance_thb)
        FILTER (WHERE loan_status = 'NPL'), 2)          AS "NPL Balance (THB)"
FROM silver.loan_accounts
GROUP BY account_type
ORDER BY "NPL Ratio (%%)" DESC;