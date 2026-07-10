/*
============================================================
 01_credit_risk_summary.sql
 สรุป KPI รายเดือนพร้อมส่ง BoT
============================================================
*/

SELECT
    report_month                                        AS "เดือน",
    total_accounts                                      AS "จำนวนบัญชีทั้งหมด",
    ROUND(outstanding_balance_thb, 2)                   AS "ยอดหนี้รวม (THB)",
    npl_accounts                                        AS "จำนวนบัญชี NPL",
    ROUND(npl_ratio_pct, 4)                             AS "NPL Ratio (%%)",
    ROUND(total_provision_thb, 2)                       AS "เงินสำรองรวม (THB)",
    ROUND(total_provision_thb / NULLIF(outstanding_balance_thb, 0) * 100, 4)   AS "Provision Coverage (%%)"
FROM gold.monthly_credit_risk_report
ORDER BY report_month;