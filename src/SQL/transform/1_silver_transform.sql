/*
============================================================
silver_transform.sql
Transform ข้อมูลจาก Bronze → Silver
ทำ 3 อย่างพร้อมกัน:
1. JOIN กับ FX Rate แปลงเงินเป็น THB
2. คำนวณ Loan Status
3. คำนวณ Provision Amount
============================================================
*/

-- ล้างข้อมูลเก่าก่อน load ใหม่ (Full Load รายเดือน)
TRUNCATE TABLE silver.loan_accounts;

-- Insert ข้อมูลที่แปลงแล้ว
INSERT INTO silver.loan_accounts (

    -- ข้อมูล Customer
    cust_id,
    cust_age,
    cust_gender,
    cust_marital_status,
    cust_dependents,
    cust_education,
    cust_employment_status,
    cust_occupation_sector,
    cust_annual_income_usd,
    cust_home_ownership,

    -- ข้อมูล Account 
    account_id,
    account_type,
    account_open_date,
    account_status,
    account_kyc_tier,
    primary_branch_region,
    total_assets_under_management,
    has_active_credit_card,
    has_active_loan,
    digital_banking_enrollment,

    -- ข้อมูล Transaction 
    txn_id,
    txn_timestamp,
    txn_type,
    txn_channel,
    txn_amount_usd,
    txn_currency,
    counterparty_id,
    counterparty_type,
    merchant_category_code_mcc,
    txn_response_code,

    -- ข้อมูล Balance 
    orig_balance_before,
    orig_balance_after,
    dest_balance_before,
    dest_balance_after,
    monthly_avg_inflow,
    monthly_avg_outflow,
    overdraft_limit_usd,
    days_in_overdraft_l12m,

    -- ข้อมูล Risk
    credit_card_utilization_rate,
    delinquency_status,
    risk_score_internal,
    bureau_credit_score,

    -- ข้อมูล Digital & Fraud 
    device_type,
    device_ip_country,
    is_vpn_used,
    login_attempts_fail_count,
    txn_velocity_1h,
    behavioral_anomaly_flag,

    -- Target Labels 
    target_credit_default,
    target_is_fraud_aml,

    -- column ใหม่จาก FX Conversion 
    txn_month,
    fx_rate_to_thb,
    txn_amount_thb,
    orig_balance_thb,

    -- column ใหม่จาก Business Logic
    loan_status,
    provision_rate,
    provision_amount_thb
)

SELECT

    -- ข้อมูล Customer 
    b.cust_id,
    b.cust_age,
    b.cust_gender,
    b.cust_marital_status,
    b.cust_dependents,
    b.cust_education,
    b.cust_employment_status,
    b.cust_occupation_sector,
    b.cust_annual_income_usd,
    b.cust_home_ownership,

    -- ข้อมูล Account 
    b.account_id,
    b.account_type,
    b.account_open_date,
    b.account_status,
    b.account_kyc_tier,
    b.primary_branch_region,
    b.total_assets_under_management,
    b.has_active_credit_card,
    b.has_active_loan,
    b.digital_banking_enrollment,

    -- ข้อมูล Transaction 
    b.txn_id,
    b.txn_timestamp,
    b.txn_type,
    b.txn_channel,
    b.txn_amount_usd,
    b.txn_currency,
    b.counterparty_id,
    b.counterparty_type,
    b.merchant_category_code_mcc,
    b.txn_response_code,

    -- ข้อมูล Balance
    b.orig_balance_before,
    b.orig_balance_after,
    b.dest_balance_before,
    b.dest_balance_after,
    b.monthly_avg_inflow,
    b.monthly_avg_outflow,
    b.overdraft_limit_usd,
    b.days_in_overdraft_l12m,

    -- ข้อมูล Risk 
    b.credit_card_utilization_rate,
    b.delinquency_status,
    b.risk_score_internal,
    b.bureau_credit_score,

    -- ข้อมูล Digital & Fraud 
    b.device_type,
    b.device_ip_country,
    b.is_vpn_used,
    b.login_attempts_fail_count,
    b.txn_velocity_1h,
    b.behavioral_anomaly_flag,

    -- Target Labels 
    b.target_credit_default,
    b.target_is_fraud_aml,

    -- FX Conversion 
    -- ตัดเอาแค่ปี-เดือน จาก timestamp เช่น 2024-09-16 19:56:16 → "2024-09"
    TO_CHAR(b.txn_timestamp, 'YYYY-MM')         AS txn_month,

    -- Rate ที่ใช้จริง เก็บไว้ audit ย้อนหลัง
    fx.rate_to_thb                              AS fx_rate_to_thb,

    -- แปลงยอด Transaction เป็น THB
    -- ROUND(..., 2) ปัดเศษทศนิยม 2 ตำแหน่ง ตามมาตรฐาน BoT
    ROUND(b.txn_amount_usd * fx.rate_to_thb, 2)         AS txn_amount_thb,

    -- แปลงยอดหนี้คงเหลือเป็น THB (ใช้คำนวณ Provision ต่อไป)
    ROUND(b.orig_balance_after * fx.rate_to_thb, 2)     AS orig_balance_thb,

    -- Loan Status 
    -- CASE WHEN คือการตัดสินใจแบบ if/else ใน SQL
    -- ตรวจสอบ Delinquency_Status แล้วจัดกลุ่มตามที่ตกลงใน BRD
    CASE
        WHEN b.delinquency_status = 'M0'
            THEN 'Performing'

        WHEN b.delinquency_status IN ('M1', 'M2', 'M3')
            THEN 'Under-Performing'

        WHEN b.delinquency_status = 'M4+'
          OR b.target_credit_default = TRUE
            THEN 'NPL'

        ELSE 'Unknown'
    END                                                 AS loan_status,

    -- Provision Rate 
    -- กำหนด Rate ตามมาตรฐาน BoT/Basel III ตามที่เขียนไว้ใน BRD
    CASE
        -- ตรวจ Default ก่อนเสมอ ไม่ว่า Delinquency จะเป็นอะไร
        WHEN b.target_credit_default = TRUE                     THEN 1.00

        -- ถ้าไม่ Default ค่อยดู Delinquency Status
        WHEN b.delinquency_status = 'M0'                        THEN 0.01
        WHEN b.delinquency_status = 'M1'                        THEN 0.02
        WHEN b.delinquency_status = 'M2'                        THEN 0.10
        WHEN b.delinquency_status = 'M3'                        THEN 0.50
        WHEN b.delinquency_status = 'M4+'                       THEN 1.00
        ELSE 0.01
    END                                                         AS provision_rate,

    -- Provision Amount (THB)
    -- คำนวณจาก orig_balance_thb × provision_rate
    -- ใช้ CASE ซ้ำเพราะ SQL ไม่สามารถใช้ alias ที่เพิ่งสร้าง
    -- ในบรรทัดเดียวกันได้ (เช่น provision_rate ที่เพิ่งคำนวณ)
    ROUND(
        b.orig_balance_after * fx.rate_to_thb *
        CASE
            WHEN b.target_credit_default = TRUE                 THEN 1.00             
            WHEN b.delinquency_status = 'M0'                    THEN 0.01
            WHEN b.delinquency_status = 'M1'                    THEN 0.02
            WHEN b.delinquency_status = 'M2'                    THEN 0.10
            WHEN b.delinquency_status = 'M3'                    THEN 0.50
            WHEN b.delinquency_status = 'M4+'                   THEN 1.00
            ELSE 0.01
        END
    , 2)                                                        AS provision_amount_thb

FROM bronze.financial_transactions b

-- JOIN กับ FX Rate 
-- JOIN แบบ INNER JOIN: เอาเฉพาะแถวที่หา Rate เจอ
-- ถ้าหา Rate ไม่เจอ แถวนั้นจะถูกทิ้ง (จะ log ไว้ใน Python)
JOIN (
    -- แปลง rate_to_thb จาก TEXT (จาก raw) เป็น NUMERIC ก่อน JOIN
    SELECT
        rate_month,
        currency_code,
        rate_to_thb::NUMERIC AS rate_to_thb
    FROM raw.fx_rate
) fx
    ON TO_CHAR(b.txn_timestamp, 'YYYY-MM') = fx.rate_month
    AND b.txn_currency = fx.currency_code

-- กรองเฉพาะ Transaction ที่มียอดหนี้คงเหลือมากกว่า 0
-- (ยอดติดลบคือ Overdraft ไม่นับเป็นหนี้ตาม BRD)
WHERE b.orig_balance_after > 0;