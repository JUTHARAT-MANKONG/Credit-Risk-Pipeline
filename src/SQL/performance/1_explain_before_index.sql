/*
============================================================
 1_explain_before_index.sql
 ดู Execution Plan ก่อนสร้าง Index
 เพื่อเข้าใจว่า PostgreSQL ทำงานยังไง และช้าตรงไหน

 วิธีอ่านผล EXPLAIN ANALYZE:
   Seq Scan   = สแกนทุกแถว (ช้า เหมือนหาของโดยเปิดทุกลิ้นชัก)
   Index Scan = ใช้ Index (เร็ว เหมือนเปิดสารบัญหนังสือ)
   cost=x..y  = ประมาณเวลา (ยิ่งน้อยยิ่งดี)
   actual time= เวลาจริงที่ใช้ (มิลลิวินาที)
   rows=      = จำนวนแถวที่ประมวลผล
============================================================
*/

-- Query 1: หา NPL ทั้งหมด (ใช้บ่อยมากใน Report)
EXPLAIN ANALYZE
SELECT
    cust_id,
    txn_id,
    loan_status,
    orig_balance_thb,
    provision_amount_thb
FROM silver.loan_accounts
WHERE loan_status = 'NPL';

-- Query 2: JOIN ที่ใช้ใน silver_transform 
-- Query นี้รันทุกครั้งที่ pipeline ทำงาน ต้องเร็วที่สุด
EXPLAIN ANALYZE
SELECT
    b.txn_id,
    b.orig_balance_after,
    fx.rate_to_thb
FROM bronze.financial_transactions b
JOIN (
    SELECT rate_month, currency_code, rate_to_thb::NUMERIC
    FROM raw.fx_rate
) fx
    ON TO_CHAR(b.txn_timestamp, 'YYYY-MM') = fx.rate_month
    AND b.txn_currency = fx.currency_code
WHERE b.orig_balance_after > 0;

-- Query 3: สรุปรายเดือน (ใช้ใน gold_aggregate) 
EXPLAIN ANALYZE
SELECT
    TO_CHAR(txn_timestamp, 'YYYY-MM')  AS txn_month,
    COUNT(*)                           AS total,
    SUM(orig_balance_thb)              AS total_balance
FROM silver.loan_accounts
GROUP BY TO_CHAR(txn_timestamp, 'YYYY-MM');