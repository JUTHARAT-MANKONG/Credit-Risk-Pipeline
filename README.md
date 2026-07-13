# Credit Risk Regulatory Reporting Pipeline

> ระบบ ETL Pipeline จำลองการประมวลผลข้อมูลความเสี่ยงด้านสินเชื่อ
> สำหรับการรายงานตามมาตรฐาน Basel III และ BoT Regulatory Guidelines

---

## Project Overview

โปรเจกต์นี้จำลองระบบ Data Engineering ในธนาคาร ที่รับข้อมูล Transaction จาก Core Banking System แล้วประมวลผลผ่าน Medallion Architecture เพื่อสร้าง Credit Risk Report ส่งให้ธนาคารแห่งประเทศไทย (BoT)

---

## Architecture

```
CSV Source Files
      │
      ▼
┌─────────────────────────────────────────────────┐
│                  RAW LAYER                       │
│  raw.financial_transactions  raw.fx_rate          │
│  (ข้อมูลดิบ ทุก column เป็น TEXT)                │
└─────────────────────────────────────────────────┘
      │
      ▼  bronze_transform.py (Type Conversion + Quarantine)
┌─────────────────────────────────────────────────┐
│                 BRONZE LAYER                     │
│  bronze.financial_transactions                   │
│  bronze.quarantine_log                           │
│  (แปลง Type ถูกต้อง + แยก Error rows)           │
└─────────────────────────────────────────────────┘
      │
      ▼  silver_transform.sql (FX Conversion + Business Logic)
┌─────────────────────────────────────────────────┐
│                 SILVER LAYER                     │
│  silver.loan_accounts                            │
│  (FX Rate, Loan Status, Provision Amount)        │
└─────────────────────────────────────────────────┘
      │
      ▼  gold_aggregate.sql (Monthly KPI Aggregation)
┌─────────────────────────────────────────────────┐
│                  GOLD LAYER                      │
│  gold.monthly_credit_risk_report                 │
│  gold.pipeline_run_log                           │
│  (KPI รายเดือน + Audit Log)                     │
└─────────────────────────────────────────────────┘
      │
      ▼
┌─────────────────────────────────────────────────┐
│               REPORTING LAYER                    │
│  CSV Export พร้อมส่ง BoT                         │
└─────────────────────────────────────────────────┘
```

---

## Business Rules (ตาม BoT/Basel III)

| Loan Status | Delinquency | Provision Rate |
|---|---|---|
| Performing | M0 (Current) | 1% |
| Under-Performing | M1 (30 Days Past Due) | 2% |
| Under-Performing | M2 (60 Days Past Due) | 10% |
| Under-Performing | M3 (90+ Days Past Due) | 50% |
| NPL | M4+ หรือ Default | 100% |

---

## KPIs ที่คำนวณ

| KPI | สูตร | หน่วย |
|---|---|---|
| Outstanding Balance | SUM(orig_balance_after × FX Rate) | THB |
| NPL Ratio | COUNT(NPL) / COUNT(*) × 100 | % |
| Total Provision | SUM(Balance THB × Provision Rate) | THB |

---

## Tech Stack

| Category | Technology |
|---|---|
| **Database** | PostgreSQL 16 |
| **Language** | Python 3.x, SQL (PL/pgSQL) |
| **Libraries** | pandas, psycopg2, SQLAlchemy, python-dotenv |
| **Architecture** | Medallion Architecture (Raw → Bronze → Silver → Gold) |
| **Automation** | Shell Script (Bash), Windows Batch Script |
| **Version Control** | Git, GitHub |

---

## Project Structure

```
credit-risk-pipeline/
├── data/
│   └── raw/                         # CSV Source Files
├── docs/
│   ├── business_requirements.md     # BRD
│   ├── data_dictionary.md           # 50 columns คำอธิบาย
│   ├── kpi_definitions.md           # KPI Definitions
│   ├── runbook.md                   # Production Support Guide
│   └── incident_log.md              # Incident Records
├── sql/
│   ├── ddl/                         # CREATE TABLE scripts
│   ├── transform/                   # ETL SQL (Silver, Gold)
│   ├── quality/                     # Data Quality Checks
│   ├── reconciliation/              # Reconciliation Checks
│   ├── performance/                 # Index + EXPLAIN ANALYZE
│   ├── reports/                     # Report Queries
│   └── troubleshooting/             # Diagnostic Queries
├── src/
│   ├── common/                      # Shared utilities
│   ├── phase1_ingestion/            # Raw Layer scripts
│   ├── phase2_transformation/       # Bronze/Silver/Gold scripts
│   ├── quality/                     # Data Quality Framework
│   ├── reconciliation/              # Reconciliation Framework
│   ├── monitoring/                  # Audit Logger
│   └── reporting/                   # Report Export
├── scripts/
│   ├── run_pipeline.sh              # Linux/Mac automation
│   └── run_pipeline.bat             # Windows automation
├── logs/                            # Pipeline execution logs
├── reports/output/                  # Exported CSV reports
├── .env                             # DB credentials (ไม่ขึ้น Git)
├── .gitignore
├── requirements.txt
└── README.md
```

---

## Getting Started

### Prerequisites

```
Python 3.8+
PostgreSQL 16
Git
```

### Installation

```bash
# 1. Clone repository
git clone https://github.com/YOUR_USERNAME/credit-risk-pipeline.git
cd credit-risk-pipeline

# 2. สร้าง Virtual Environment
python -m venv venv
source venv/Scripts/activate   # Windows
source venv/bin/activate        # Mac/Linux

# 3. ติดตั้ง dependencies
pip install -r requirements.txt

# 4. ตั้งค่า environment variables
cp .env.example .env
# แก้ไข .env ใส่ DB credentials

# 5. สร้าง Database Schema
# เปิด pgAdmin แล้วรันไฟล์เหล่านี้ตามลำดับ
# sql/ddl/02_create_bronze_tables.sql
# sql/ddl/04_create_silver_tables.sql
# sql/ddl/05_create_gold_tables.sql
# sql/ddl/06_create_audit_table.sql
```

### Run Pipeline

```bash
# Windows
scripts\run_pipeline.bat

# Linux/Mac/Git Bash
bash scripts/run_pipeline.sh
```

### Run Individual Steps

```bash
python -m src.phase1_ingestion.push_data_to_pgsql
python -m src.phase1_ingestion.load_fx_rate
python -m src.phase2_transformation.bronze_transform
python -m src.phase2_transformation.silver_transform
python -m src.phase2_transformation.gold_aggregate
python -m src.quality.data_quality
python -m src.reconciliation.reconciliation
python -m src.reporting.export_report
```

---

## Data Quality Framework

ตรวจสอบ 8 checks ก่อน Report ออกจากระบบ

| Check | Layer | ตรวจอะไร |
|---|---|---|
| Null Check | Silver | column สำคัญต้องไม่มี NULL |
| Duplicate Check | Silver | txn_id ต้องไม่ซ้ำ |
| FX Rate Positive | Silver | Rate ต้องมากกว่า 0 |
| Balance Positive | Silver | ยอดหนี้ต้องมากกว่า 0 |
| Loan Status Valid | Silver | ต้องเป็นค่าที่กำหนดไว้ใน BRD |
| NPL Ratio Range | Gold | 0-100% เท่านั้น |
| Provision vs Balance | Gold | Provision ต้องไม่เกิน Balance |
| Monthly Completeness | Gold | ต้องมีครบ 12 เดือน |

---

## Reconciliation Framework

ตรวจสอบ 5 checks เปรียบเทียบข้อมูลระหว่าง Layer

| Check | ตรวจอะไร |
|---|---|
| Bronze → Silver Count | จำนวนแถวตรงกันไหม |
| Silver → Gold Count | จำนวนแถวรวมตรงกันไหม |
| Balance Silver vs Gold | ยอดหนี้รวมตรงกันไหม |
| Provision Silver vs Gold | เงินสำรองรวมตรงกันไหม |
| NPL Count Silver vs Gold | จำนวน NPL ตรงกันไหม |

---

## Performance Optimization

สร้าง 9 Indexes เพื่อเพิ่มความเร็ว Query

```sql
-- ตัวอย่าง Index ที่สร้าง
idx_bronze_transform_composite   -- Composite Index สำหรับ JOIN กับ FX Rate
idx_silver_loan_status           -- Index สำหรับกรอง NPL
idx_silver_month_status          -- Composite Index สำหรับ GROUP BY รายเดือน
```

ผลลัพธ์: Query เร็วขึ้น ~8x (Seq Scan → Index Scan)

---

## Design Decisions

### เหตุผลที่แยก `common/` ออกมา

ฟังก์ชันที่ใช้ร่วมกันทุก module (Logging, DB Connection) ถูกแยกออกมาไว้ใน `common/` ตามหลัก **DRY (Don't Repeat Yourself)** และ **Separation of Concerns** ทำให้แก้ไขที่เดียวมีผลทุก module และแต่ละ Layer โฟกัสแค่ Business Logic ของตัวเอง

### เหตุผลที่ Bronze ใช้ Python แต่ Silver/Gold ใช้ SQL

Bronze ต้องการ row-by-row validation และ Quarantine Logic ที่ Python จัดการได้ดีกว่า แต่ Silver/Gold เป็น Set-based Operations ที่ SQL ทำได้เร็วกว่า และตรงกับ JD ที่ต้องการทักษะ SQL

---

## Sample Output

```
📋 CREDIT RISK REGULATORY REPORT — สรุปรายเดือน
====================================================================
Month      Accounts     Balance THB    NPL  NPL%    Provision THB
--------------------------------------------------------------------
2024-01         xxx   x,xxx,xxx.xx    xxx  x.xx%    x,xxx,xxx.xx
2024-02         xxx   x,xxx,xxx.xx    xxx  x.xx%    x,xxx,xxx.xx
...
2024-12         xxx   x,xxx,xxx.xx    xxx  x.xx%    x,xxx,xxx.xx
====================================================================
```

---

## Author

**Jutharat Mankong**
Data Engineering Portfolio Project