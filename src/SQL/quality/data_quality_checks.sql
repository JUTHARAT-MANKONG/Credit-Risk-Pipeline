/*
============================================================
data_quality_checks.sql
  ตรวจสอบคุณภาพข้อมูลใน Silver และ Gold Layer
  Python จะอ่านผลลัพธ์และตัดสินว่าผ่านหรือไม่ผ่าน

รูปแบบผลลัพธ์ทุก check:
   check_name   → ชื่อของ check
   layer        → silver หรือ gold
   status       → PASS หรือ FAIL
   failed_count → จำนวนแถวที่ผิดปกติ (0 = ผ่าน)
   detail       → อธิบายว่าตรวจอะไร
============================================================
*/

-- ════════════════════════════════════════════════════════════
-- SILVER LAYER CHECKS
-- ════════════════════════════════════════════════════════════

-- Check 1: Null Check 
-- column สำคัญที่ใช้คำนวณ KPI ต้องไม่มีค่าว่างเลย
-- ถ้ามี NULL จะทำให้ SUM ผิด และ Report ผิดตามไปด้วย
SELECT
    'silver_null_check'                         AS check_name,
    'silver'                                    AS layer,
    CASE WHEN COUNT(*) = 0 THEN 'PASS'
         ELSE 'FAIL'
    END                                         AS status,
    COUNT(*)                                    AS failed_count,
    'NULL ใน column: cust_id, txn_id, orig_balance_thb, loan_status, provision_amount_thb'   AS detail
FROM silver.loan_accounts
WHERE
    cust_id               IS NULL OR
    txn_id                IS NULL OR
    orig_balance_thb      IS NULL OR
    loan_status           IS NULL OR
    provision_amount_thb  IS NULL

UNION ALL   --UNION ALL : รวม Check หลายตัวให้ผลลัพธ์ออกมาเป็นตารางเดียว

-- Check 2: Duplicate Check 
-- txn_id ต้องไม่ซ้ำกัน 1 transaction = 1 แถวเท่านั้น
-- ถ้าซ้ำ ยอด SUM จะบวกซ้ำ ทำให้ตัวเลขพองออกไปเกินจริง
SELECT
    'silver_duplicate_txn'                      AS check_name,
    'silver'                                    AS layer,
    CASE WHEN COUNT(*) = 0 THEN 'PASS'
         ELSE 'FAIL'
    END                                         AS status,
    COUNT(*)                                    AS failed_count,
    'txn_id ที่ซ้ำกันมากกว่า 1 แถว'                  AS detail
FROM (
    SELECT txn_id, COUNT(*) AS cnt
    FROM silver.loan_accounts
    GROUP BY txn_id
    HAVING COUNT(*) > 1
) duplicates

UNION ALL

-- Check 3: FX Rate Check 
-- อัตราแลกเปลี่ยนต้องมากกว่า 0 เสมอ
-- ถ้า rate = 0 จะทำให้ยอด THB = 0 ผิดพลาดร้ายแรง
SELECT
    'silver_fx_rate_positive'                   AS check_name,
    'silver'                                    AS layer,
    CASE WHEN COUNT(*) = 0 THEN 'PASS'
         ELSE 'FAIL'
    END                                         AS status,
    COUNT(*)                                    AS failed_count,
    'fx_rate_to_thb ต้องมากกว่า 0 เสมอ'           AS detail
FROM silver.loan_accounts
WHERE fx_rate_to_thb <= 0
   OR fx_rate_to_thb IS NULL

UNION ALL

-- Check 4: Balance Positive Check 
-- ยอดหนี้คงเหลือ THB ต้องมากกว่า 0
-- (กรอง balance <= 0 ออกไปตั้งแต่ silver_transform.sql แล้ว)
SELECT
    'silver_balance_positive'                   AS check_name,
    'silver'                                    AS layer,
    CASE WHEN COUNT(*) = 0 THEN 'PASS'
         ELSE 'FAIL'
    END                                         AS status,
    COUNT(*)                                    AS failed_count,
    'orig_balance_thb ต้องมากกว่า 0'              AS detail
FROM silver.loan_accounts
WHERE orig_balance_thb <= 0

UNION ALL

-- Check 5: Loan Status Valid Values 
-- loan_status ต้องเป็นแค่ 3 ค่าที่กำหนดไว้ใน BRD เท่านั้น
-- ถ้าเจอค่าอื่น แสดงว่า Business Logic ใน silver_transform.sql ผิด
SELECT
    'silver_loan_status_valid'                  AS check_name,
    'silver'                                    AS layer,
    CASE WHEN COUNT(*) = 0 THEN 'PASS'
         ELSE 'FAIL'
    END                                         AS status,
    COUNT(*)                                    AS failed_count,
    'loan_status ต้องเป็น Performing, Under-Performing, หรือ NPL เท่านั้น'   AS detail
FROM silver.loan_accounts
WHERE loan_status NOT IN ('Performing', 'Under-Performing', 'NPL')

UNION ALL

-- Check 6: Default Provision Rate Check (เพิ่มจาก INC-004)
-- ลูกค้าที่ Target_Credit_Default = True ต้องได้ provision_rate = 1.00 เสมอ
-- ไม่ว่า Delinquency_Status จะเป็น M0/M1/M2/M3 ก็ตาม
-- ถ้าไม่เป็น 1.00 แสดงว่า Business Logic ผิดพลาดร้ายแรง
SELECT
    'silver_default_provision_rate'             AS check_name,
    'silver'                                    AS layer,
    CASE WHEN COUNT(*) = 0 THEN 'PASS'
         ELSE 'FAIL'
    END                                         AS status,
    COUNT(*)                                    AS failed_count,
    'ลูกค้าที่ Default=True ต้องมี provision_rate = 1.00 เสมอ ไม่ว่า Delinquency จะเป็นอะไร'    AS detail
FROM silver.loan_accounts
WHERE target_credit_default = TRUE
  AND provision_rate != 1.00

UNION ALL

-- Check 7: Default ต้องเป็น NPL เสมอ (INC-004)
-- ลูกค้าที่ Target_Credit_Default = True ต้องมี loan_status = NPL เสมอ
-- ถ้าไม่เป็น NPL แสดงว่า Loan Status Logic ผิดพลาด
SELECT
    'silver_default_loan_status'                AS check_name,
    'silver'                                    AS layer,
    CASE WHEN COUNT(*) = 0 THEN 'PASS'
         ELSE 'FAIL'
    END                                         AS status,
    COUNT(*)                                    AS failed_count,
    'ลูกค้าที่ Default=True ต้องมี loan_status = NPL เสมอ'    AS detail
FROM silver.loan_accounts
WHERE target_credit_default = TRUE
  AND loan_status != 'NPL'

UNION ALL

-- ════════════════════════════════════════════════════════════
-- GOLD LAYER CHECKS
-- ════════════════════════════════════════════════════════════

-- Check 8: NPL Ratio Range 
-- NPL Ratio ต้องอยู่ระหว่าง 0-100% เสมอ
-- ถ้าเกิน 100% แสดงว่าการคำนวณผิดพลาดร้ายแรง
SELECT
    'gold_npl_ratio_range'                      AS check_name,
    'gold'                                      AS layer,
    CASE WHEN COUNT(*) = 0 THEN 'PASS'
         ELSE 'FAIL'
    END                                         AS status,
    COUNT(*)                                    AS failed_count,
    'npl_ratio_pct ต้องอยู่ระหว่าง 0 ถึง 100'        AS detail
FROM gold.monthly_credit_risk_report
WHERE npl_ratio_pct < 0
   OR npl_ratio_pct > 100

UNION ALL

-- Check 9: Provision vs Balance 
-- เงินสำรองต้องไม่เกินยอดหนี้รวม
-- ถ้าเกิน แสดงว่า Provision Rate หรือการคำนวณผิดพลาด
SELECT
    'gold_provision_not_exceed_balance'         AS check_name,
    'gold'                                      AS layer,
    CASE WHEN COUNT(*) = 0 THEN 'PASS'
         ELSE 'FAIL'
    END                                         AS status,
    COUNT(*)                                    AS failed_count,
    'total_provision_thb ต้องไม่เกิน outstanding_balance_thb'   AS detail
FROM gold.monthly_credit_risk_report
WHERE total_provision_thb > outstanding_balance_thb

UNION ALL

-- Check 10: Monthly Completeness 
-- ต้องมีข้อมูลครบ 12 เดือนของปี 2024
-- ถ้าขาดเดือนไหน Report ที่ส่ง BoT จะไม่สมบูรณ์
SELECT
    'gold_monthly_completeness'                 AS check_name,
    'gold'                                      AS layer,
    CASE WHEN COUNT(*) = 12 THEN 'PASS'
         ELSE 'FAIL'
    END                                         AS status,
    CASE WHEN COUNT(*) = 12 THEN 0
         ELSE 12 - COUNT(*)
    END                                         AS failed_count,
    CONCAT('มีข้อมูล ', COUNT(*), ' เดือน (ต้องการ 12 เดือน)')
                                                AS detail
FROM gold.monthly_credit_risk_report
WHERE report_month LIKE '2024-%'

ORDER BY layer, check_name;