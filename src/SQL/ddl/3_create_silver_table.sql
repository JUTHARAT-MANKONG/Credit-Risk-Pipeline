/*
============================================================
create_silver_tables.sql
สร้าง Table ใน Schema silver
ต่างจาก Bronze : มี column เพิ่มจากการคำนวณ Business Logic
FX Conversion,Loan Status,Provision Amount
============================================================
*/

CREATE SCHEMA IF NOT EXISTS silver;
CREATE TABLE IF NOT EXISTS silver.loan_accounts (
    -- ข้อมูล Customer (มาจาก Bronze)
    cust_id                         TEXT,
    cust_age                        INTEGER,
    cust_gender                     TEXT,
    cust_marital_status             TEXT,
    cust_dependents                 INTEGER,
    cust_education                  TEXT,
    cust_employment_status          TEXT,
    cust_occupation_sector          TEXT,
    cust_annual_income_usd          NUMERIC(14,2),
    cust_home_ownership             TEXT,

    -- ข้อมูล Account (มาจาก Bronze)
    account_id                      TEXT,
    account_type                    TEXT,
    account_open_date               DATE,
    account_status                  TEXT,
    account_kyc_tier                TEXT,
    primary_branch_region           TEXT,
    total_assets_under_management   NUMERIC(14,2),
    has_active_credit_card          BOOLEAN,
    has_active_loan                 BOOLEAN,
    digital_banking_enrollment      BOOLEAN,

    -- ข้อมูล Transaction (มาจาก Bronze)
    txn_id                          TEXT,
    txn_timestamp                   TIMESTAMP,
    txn_type                        TEXT,
    txn_channel                     TEXT,
    txn_amount_usd                  NUMERIC(14,2),
    txn_currency                    TEXT,
    counterparty_id                 TEXT,
    counterparty_type               TEXT,
    merchant_category_code_mcc      INTEGER,
    txn_response_code               TEXT,

    -- ข้อมูล Balance (มาจาก Bronze)
    orig_balance_before              NUMERIC(14,2),
    orig_balance_after               NUMERIC(14,2),
    dest_balance_before              NUMERIC(14,2),
    dest_balance_after               NUMERIC(14,2),
    monthly_avg_inflow               NUMERIC(14,2),
    monthly_avg_outflow              NUMERIC(14,2),
    overdraft_limit_usd              NUMERIC(14,2),
    days_in_overdraft_l12m           INTEGER,

    -- ข้อมูล Risk (มาจาก Bronze)
    credit_card_utilization_rate       NUMERIC(5,4),
    delinquency_status                 TEXT,   -- มาตรฐานแล้ว: M0, M1, M2, M3, M4+
    risk_score_internal                INTEGER,
    bureau_credit_score                INTEGER,

    -- ข้อมูล Digital & Fraud (มาจาก Broze)
    device_type                         TEXT,
    device_ip_country                   TEXT,
    is_vpn_used                         BOOLEAN,
    login_attempts_fail_count           INTEGER,
    txn_velocity_1h                     INTEGER,
    behavioral_anomaly_flag             BOOLEAN,

    -- Target Labels (มาจาก Bronze)
    target_credit_default                BOOLEAN,
    target_is_fraud_aml                  BOOLEAN,

    -- Column ใหม่จาก FX Conversion
	txn_month                            TEXT, --ใช้ JOIN กับ FX Rate
	fx_rate_to_thb                       NUMERIC(10,4), --Rate ที่ใช้แปลง เก็บไว้ audit ย้อนหลัง
	txn_amount_thb                       NUMERIC(14,2), --txn_amount_usd x fx_rate
	orig_balance_thb                     NUMERIC(14,2), --orig_balance_after x fx_rate

	--Column ใหม่จาก Business Logic
	loan_status                          TEXT, --Perforing/Under-Perforing/NPL
	provision_rate                       NUMERIC(5,4), --0.01,0.02,0.10,0.50,1.00
	provision_amount_thb                 NUMERIC(14,2), --orig_balance_thb x provision_rate

	-- Metadata
    _silver_loaded_at                    TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE silver.loan_accounts IS
    'Silver Layer - Bronze data + FX Conversion(THB) + Loan Status + Provision on Amount
	ทุกตัวเลขทางการเงิน แปลงเป็น THB แล้ว พร้อมสำหรับ Regulatory Reporting';

COMMENT ON COLUMN silver.loan_accounts.loan_status IS
    'Performing = M0 | Under-Performing = M1/M2/M3 | NPL = M4+ หรือ Target_Credit_Default = True';
 
COMMENT ON COLUMN silver.loan_accounts.provision_rate IS
    'M0=1% M1=2% M2=10% M3=50% M4+=100% ตามมาตรฐาน BoT/Basel III';
 
COMMENT ON COLUMN silver.loan_accounts.fx_rate_to_thb IS
    'เก็บ Rate ที่ใช้จริงไว้ตรวจสอบย้อนหลัง (Audit Trail)';


