/*
============================================================
create_gold_tables.sql
สร้าง Table ใน Schema gold
เก็บ KPI สรุปรายเดือน พร้อมส่ง Regulatory Report ให้ BoT
============================================================
*/

CREATE SCHEMA IF NOT EXISTS gold;
CREATE TABLE IF NOT EXISTS gold.monthly_credit_risk_report (

    -- Key
    report_month            TEXT        NOT NULL,  -- เช่น "2024-01"

    -- KPI ที่ 1: Outstanding Balance
    total_accounts          INTEGER,               -- จำนวนบัญชีทั้งหมด
    outstanding_balance_thb NUMERIC(20,2),         -- ยอดหนี้รวม (THB)

    -- KPI ที่ 2: NPL Ratio
    npl_accounts            INTEGER,               -- จำนวนบัญชี NPL
    npl_ratio_pct           NUMERIC(8,4),          -- อัตราส่วนหนี้เสีย (%)

    -- KPI ที่ 3: Provision Amount 
    total_provision_thb     NUMERIC(20,2),         -- เงินสำรองรวม (THB)

    -- Breakdown ตาม Loan Status 
    performing_accounts     INTEGER,
    performing_balance_thb  NUMERIC(20,2),
    performing_provision_thb NUMERIC(20,2),

    under_performing_accounts     INTEGER,
    under_performing_balance_thb  NUMERIC(20,2),
    under_performing_provision_thb NUMERIC(20,2),

    npl_balance_thb         NUMERIC(20,2),
    npl_provision_thb       NUMERIC(20,2),

    -- Metadata 
    _gold_loaded_at         TIMESTAMP DEFAULT NOW(),

    -- Constraint 
    PRIMARY KEY (report_month)   -- 1 เดือน มีแค่ 1 แถวเท่านั้น ห้ามซ้ำ
);

COMMENT ON TABLE gold.monthly_credit_risk_report IS
    'Gold layer - KPI สรุปรายเดือน พร้อมส่ง Regulatory Report ให้ BoT
     Outstanding Balance, NPL Ratio, Total Provision Amount';