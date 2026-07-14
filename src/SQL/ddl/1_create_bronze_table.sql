/*
============================================================
 create_bronze_tables.sql
 สร้าง Table ใน Schema bronze
 ต่างจาก raw: column type ถูกต้องตามจริง ไม่ใช่ TEXT ทั้งหมด
============================================================
*/
-- Table หลัก เก็บข้อมูลที่ผ่านการตรวจสอบ Type แล้ว
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE TABLE IF NOT EXISTS bronze.financial_transactions (
    -- ข้อมูล Customer
    cust_id                         TEXT ,
    cust_age                        INTEGER,
    cust_gender                     TEXT,
    cust_marital_status             TEXT,
    cust_dependents                 INTEGER,
    cust_education                  TEXT,
    cust_employment_status          TEXT,
    cust_occupation_sector          TEXT,
    cust_annual_income_usd          NUMERIC(14,2),
    cust_home_ownership             TEXT,

    -- ข้อมูล Account
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

    -- ข้อมูล Transaction
    txn_id                          TEXT PRIMARY KEY,
    txn_timestamp                   TIMESTAMP,
    txn_type                        TEXT,
    txn_channel                     TEXT,
    txn_amount_usd                  NUMERIC(14,2),
    txn_currency                    TEXT,
    counterparty_id                 TEXT,
    counterparty_type               TEXT,
    merchant_category_code_mcc      INTEGER,
    txn_response_code               TEXT,

    -- ข้อมูล Balance
    orig_balance_before              NUMERIC(14,2),
    orig_balance_after               NUMERIC(14,2),
    dest_balance_before              NUMERIC(14,2),
    dest_balance_after               NUMERIC(14,2),
    monthly_avg_inflow               NUMERIC(14,2),
    monthly_avg_outflow              NUMERIC(14,2),
    overdraft_limit_usd              NUMERIC(14,2),
    days_in_overdraft_l12m           INTEGER,

    -- ข้อมูล Risk
    credit_card_utilization_rate       NUMERIC(5,4),
    delinquency_status                 TEXT,   -- มาตรฐานแล้ว: M0, M1, M2, M3, M4+
    risk_score_internal                INTEGER,
    bureau_credit_score                INTEGER,

    -- ข้อมูล Digital & Fraud
    device_type                         TEXT,
    device_ip_country                   TEXT,
    is_vpn_used                         BOOLEAN,
    login_attempts_fail_count           INTEGER,
    txn_velocity_1h                     INTEGER,
    behavioral_anomaly_flag             BOOLEAN,

    -- Target Labels
    target_credit_default                BOOLEAN,
    target_is_fraud_aml                  BOOLEAN,

    -- Metadata
    _bronze_loaded_at                    TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE bronze.financial_transactions IS
    'Cleansed data with correct types. Delinquency_Status standardized to M0-M4+.';


-- Table เก็บข้อมูลที่ Type ผิดปกติ ตรวจสอบไม่ผ่าน
CREATE TABLE IF NOT EXISTS bronze.quarantine_log (
    quarantine_id         SERIAL PRIMARY KEY,
    cust_id               TEXT,
    txn_id                TEXT,
    failed_column         TEXT,         -- ชื่อ column ที่ผิดปกติ
    failed_value          TEXT,         -- ค่าดิบที่ทำให้ผิดปกติ
    failure_reason        TEXT,         -- อธิบายว่าผิดปกติยังไง
    raw_row_data          JSONB,        -- เก็บข้อมูลทั้ง row ไว้ตรวจสอบย้อนหลัง
    quarantined_at        TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE bronze.quarantine_log IS
    'แถวที่ไม่ผ่านการตรวจสอบ Type หรือ Business Rule เก็บไว้ตรวจสอบและแก้ไขย้อนหลัง';