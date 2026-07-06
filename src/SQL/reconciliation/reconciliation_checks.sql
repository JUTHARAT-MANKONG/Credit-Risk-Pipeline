/*
============================================================
 reconciliation_checks.sql
 เปรียบเทียบข้อมูลระหว่าง Layer
 ตรวจว่าข้อมูลไม่หายไประหว่างการ Transform

 รูปแบบผลลัพธ์:
   check_name    → ชื่อของ check
   source_value  → ค่าจาก Layer ต้นทาง
   target_value  → ค่าจาก Layer ปลายทาง
   difference    → ผลต่าง (0 = ตรงกันสมบูรณ์)
   status        → PASS หรือ FAIL
   detail        → อธิบายว่าตรวจอะไร
============================================================
*/

-- ════════════════════════════════════════════════════════════
-- COUNT RECONCILIATION
-- ตรวจว่าจำนวนแถวตรงกันไหมระหว่าง Layer
-- ════════════════════════════════════════════════════════════

-- Check 1: Bronze → Silver Count
-- Bronze กรอง balance > 0 ออกไปตอน Transform
-- Silver ต้องมีแถวเท่ากับ Bronze ที่ balance > 0 พอดี
SELECT
    'count_bronze_to_silver'                    AS check_name,
    bronze_count                                AS source_value,
    silver_count                                AS target_value,
    bronze_count - silver_count                 AS difference,
    CASE WHEN bronze_count = silver_count
         THEN 'PASS' ELSE 'FAIL'
    END                                         AS status,
    'จำนวนแถว Bronze (balance>0) vs Silver'     AS detail
FROM (
    SELECT
        (SELECT COUNT(*)
         FROM bronze.financial_transactions
         WHERE orig_balance_after > 0)          AS bronze_count,

        (SELECT COUNT(*)
         FROM silver.loan_accounts)             AS silver_count
) counts

UNION ALL

-- Check 2: Silver → Gold Count 
-- Silver ทุกแถวต้องถูกนับรวมใน Gold
-- ตรวจโดยนับจาก Silver แล้วเทียบกับ SUM ของ Gold
SELECT
    'count_silver_to_gold'                          AS check_name,
    silver_total                                    AS source_value,
    gold_total                                      AS target_value,
    silver_total - gold_total                       AS difference,
    CASE WHEN silver_total = gold_total
         THEN 'PASS' ELSE 'FAIL'
    END                                             AS status,
    'จำนวนแถวรวมใน Silver vs SUM(total_accounts) ใน Gold'   AS detail
FROM (
    SELECT
        (SELECT COUNT(*)
         FROM silver.loan_accounts)                 AS silver_total,

        (SELECT COALESCE(SUM(total_accounts), 0)    --ถ้า sum() คืนค่า NULL (เช่น Table ว่างเปล่า) จะใช้ค่า 0 แทน ป้องกัน error ตอนเอาไปคำนวณต่อ 
         FROM gold.monthly_credit_risk_report)      AS gold_total
) counts


-- ════════════════════════════════════════════════════════════
-- AMOUNT RECONCILIATION
-- ตรวจว่ายอดรวมตรงกันไหมระหว่าง Layer
-- ════════════════════════════════════════════════════════════

UNION ALL

-- Check 3: Silver vs Gold Outstanding Balance
-- SUM(orig_balance_thb) ใน Silver ต้องเท่ากับ
-- SUM(outstanding_balance_thb) ใน Gold
-- ถ้าไม่เท่ากัน แสดงว่า Aggregation ใน Gold ผิดพลาด
SELECT
    'amount_balance_silver_vs_gold'                     AS check_name,
    ROUND(silver_balance, 2)                            AS source_value,
    ROUND(gold_balance, 2)                              AS target_value,
    ROUND(silver_balance - gold_balance, 2)             AS difference,
    CASE
        -- ยอมให้ผิดพลาดได้ไม่เกิน 1 บาท (เพราะการ ROUND อาจต่างกันเล็กน้อย)
        WHEN ABS(silver_balance - gold_balance) <= 1.00    -- ABS ย่อมาจาก Absolute Value คือค่าสัมบูรณ์ (เอาค่าลบออกให้เป็นบวกเสมอ)
        THEN 'PASS' ELSE 'FAIL'
    END                                                 AS status,
    'SUM(orig_balance_thb) Silver vs SUM(outstanding_balance_thb) Gold'  AS detail
FROM (
    SELECT
        (SELECT COALESCE(SUM(orig_balance_thb), 0)
         FROM silver.loan_accounts)                     AS silver_balance,

        (SELECT COALESCE(SUM(outstanding_balance_thb), 0)
         FROM gold.monthly_credit_risk_report)          AS gold_balance
) amounts

UNION ALL

-- Check 4: Silver vs Gold Provision Amount 
-- SUM(provision_amount_thb) ใน Silver ต้องเท่ากับ
-- SUM(total_provision_thb) ใน Gold
SELECT
    'amount_provision_silver_vs_gold'                   AS check_name,
    ROUND(silver_provision, 2)                          AS source_value,
    ROUND(gold_provision, 2)                            AS target_value,
    ROUND(silver_provision - gold_provision, 2)         AS difference,
    CASE
        WHEN ABS(silver_provision - gold_provision) <= 1.00
        THEN 'PASS' ELSE 'FAIL'
    END                                                 AS status,
    'SUM(provision_amount_thb) Silver vs SUM(total_provision_thb) Gold'  AS detail
FROM (
    SELECT
        (SELECT COALESCE(SUM(provision_amount_thb), 0)
         FROM silver.loan_accounts)                     AS silver_provision,

        (SELECT COALESCE(SUM(total_provision_thb), 0)
         FROM gold.monthly_credit_risk_report)          AS gold_provision
) amounts

UNION ALL

-- Check 5: Silver vs Gold NPL Count 
-- จำนวน NPL ใน Silver ต้องเท่ากับ SUM(npl_accounts) ใน Gold
SELECT
    'count_npl_silver_vs_gold'                          AS check_name,
    silver_npl                                          AS source_value,
    gold_npl                                            AS target_value,
    silver_npl - gold_npl                               AS difference,
    CASE WHEN silver_npl = gold_npl
         THEN 'PASS' ELSE 'FAIL'
    END                                                 AS status,
    'COUNT(NPL) ใน Silver vs SUM(npl_accounts) ใน Gold' AS detail
FROM (
    SELECT
        (SELECT COUNT(*)
         FROM silver.loan_accounts
         WHERE loan_status = 'NPL')                     AS silver_npl,

        (SELECT COALESCE(SUM(npl_accounts), 0)
         FROM gold.monthly_credit_risk_report)          AS gold_npl
) npl_counts

ORDER BY check_name;