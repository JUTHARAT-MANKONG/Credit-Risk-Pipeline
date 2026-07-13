# Runbook: Credit Risk Regulatory Reporting Pipeline

| | |
|---|---|
| **Version** | 1.0 |
| **Author** | Jutharat Mankong |
| **Last Updated** | 2026-07-09 |
| **ระบบ** | Credit Risk Pipeline — PostgreSQL |

---

## 1. ภาพรวมระบบ

Pipeline นี้รันทุกสิ้นเดือนเพื่อประมวลผลข้อมูล Transaction และ FX Rate แล้วสร้าง Credit Risk Report ส่งให้ BoT ผ่าน 7 ขั้นตอน

```
Raw → Bronze → Silver → Gold → Data Quality → Reconciliation → Export Report
```

---

## 2. ข้อมูลการติดต่อฉุกเฉิน

| บทบาท | ผู้รับผิดชอบ | ติดต่อเมื่อ |
|---|---|---|
| Data Engineer (L2) | Jutharat Mankong | Pipeline พัง, ข้อมูลผิดปกติ |
| DBA | ทีม Infrastructure | Database ล่ม, Disk เต็ม |
| Business Owner | ทีม Risk Management | ตัวเลข KPI ผิดปกติ |

---

## 3. วิธีตรวจสอบสถานะ Pipeline

### ขั้นที่ 1 — ดู Audit Log ก่อน

```sql
SELECT run_id, step_name, status, duration_sec, error_message
FROM gold.pipeline_run_log
ORDER BY run_id DESC
LIMIT 10;
```

### ขั้นที่ 2 — ดู Log File

```bash
cat logs/pipeline_YYYYMMDD_HHMMSS.log
```

### ขั้นที่ 3 — ตรวจสอบข้อมูลใน Database

เปิดไฟล์ `sql/troubleshooting/diagnostic_queries.sql` แล้วรันทีละ Section

---

## 4. Incident Scenarios และวิธีแก้

---

### Incident 1 — Pipeline หยุดกลางทาง

**อาการ:** รัน script แล้วหยุดที่ Step ใด Step หนึ่ง ไม่รัน Step ถัดไป

**วิธีตรวจสอบ:**

```sql
-- ดู Step ที่ FAILED
SELECT step_name, error_message, started_at
FROM gold.pipeline_run_log
WHERE status = 'FAILED'
ORDER BY run_id DESC
LIMIT 5;
```

**สาเหตุที่พบบ่อยและวิธีแก้:**

| สาเหตุ | error_message | วิธีแก้ |
|---|---|---|
| DB Connection ล้มเหลว | could not connect to server | ตรวจสอบ PostgreSQL ว่ายังรันอยู่ไหม |
| .env ไม่มีค่า | ไม่พบค่าใน .env | เปิด .env ตรวจสอบทุก key ว่าครบ |
| FX Rate ขาด | FX Rate ไม่พบ | โหลด FX Rate ใหม่ แล้วรัน silver_transform อีกครั้ง |
| Data Quality ไม่ผ่าน | Data Quality ไม่ผ่าน | ดู Section 5 ด้านล่าง |

**วิธีรัน Step ที่พังใหม่โดยไม่ต้องรันทั้งหมด:**

```bash
# ตัวอย่างถ้า Silver พัง รันแค่ Silver ต่อ
python -m src.phase2_transformation.silver_transform
python -m src.phase2_transformation.gold_aggregate
python -m src.quality.data_quality
python -m src.reconciliation.reconciliation
```

---

### Incident 2 — ModuleNotFoundError

**อาการ:**
```
ModuleNotFoundError: No module named 'xxx'
```

**วิธีแก้:**

```bash
# ตรวจสอบว่า venv active อยู่ไหม
which python   # ควรเห็น path ที่มี venv

# ถ้าไม่ active
source venv/Scripts/activate   # Windows Git Bash
venv\Scripts\activate          # Windows CMD

# ติดตั้ง library ที่ขาด
pip install -r requirements.txt
```

---

### Incident 3 — Data Quality ไม่ผ่าน

**อาการ:**
```
❌ Data Quality ไม่ผ่าน! Pipeline หยุดทำงาน
```

**วิธีตรวจสอบ:**

```sql
-- ดู NULL ใน Silver
SELECT COUNT(*) FILTER (WHERE loan_status IS NULL) AS null_loan_status
FROM silver.loan_accounts;

-- ดู Quarantine
SELECT failed_column, failure_reason, COUNT(*)
FROM bronze.quarantine_log
GROUP BY failed_column, failure_reason
ORDER BY COUNT(*) DESC;
```

**วิธีแก้:**

```
1. ถ้า NULL มาจาก Bronze → ตรวจสอบ raw data ต้นทาง
2. ถ้า Quarantine เยอะผิดปกติ → แจ้ง Source System team
3. ถ้า loan_status = Unknown → ตรวจ Delinquency_Status ใน Bronze
```

---

### Incident 4 — Reconciliation ไม่ผ่าน

**อาการ:**
```
❌ Reconciliation ไม่ผ่าน! ข้อมูลอาจหายหรือยอดไม่ตรง
```

**วิธีตรวจสอบ:**

```sql
-- เปรียบเทียบยอดระหว่าง Layer
SELECT
    (SELECT COUNT(*) FROM bronze.financial_transactions WHERE orig_balance_after > 0) AS bronze_count,
    (SELECT COUNT(*) FROM silver.loan_accounts)                                        AS silver_count,
    (SELECT COALESCE(SUM(total_accounts),0) FROM gold.monthly_credit_risk_report)     AS gold_count;
```

**วิธีแก้:**

```
ถ้า Bronze > Silver → FX Rate ขาดบางเดือน/สกุลเงิน
   → โหลด FX Rate ใหม่ แล้วรัน Silver ใหม่

ถ้า Silver ≠ Gold  → Gold Aggregate มีปัญหา
   → รัน gold_aggregate.py ใหม่
```

---

### Incident 5 — Report ตัวเลขผิดปกติ

**อาการ:** NPL Ratio สูงหรือต่ำผิดปกติ หรือ Provision Amount ผิด

**วิธีตรวจสอบ:**

```sql
-- ตรวจ Loan Status Distribution
SELECT loan_status, COUNT(*), ROUND(SUM(orig_balance_thb), 2)
FROM silver.loan_accounts
GROUP BY loan_status;

-- ตรวจ FX Rate ที่ใช้จริง
SELECT txn_currency, txn_month, fx_rate_to_thb, COUNT(*)
FROM silver.loan_accounts
GROUP BY txn_currency, txn_month, fx_rate_to_thb
ORDER BY txn_month;

-- ตรวจ Provision Rate ถูกต้องไหม
SELECT delinquency_status, provision_rate, COUNT(*)
FROM silver.loan_accounts
GROUP BY delinquency_status, provision_rate
ORDER BY provision_rate;
```

---

## 5. ขั้นตอน Escalation

```
Level 1 (ตัวเองแก้ได้ใน 30 นาที)
→ ดู Log File
→ รัน Diagnostic SQL
→ รัน Step ที่พังใหม่

Level 2 (แจ้ง DBA ภายใน 1 ชั่วโมง)
→ PostgreSQL ล่ม
→ Disk เต็ม
→ Connection Pool หมด

Level 3 (แจ้ง Business Owner ทันที)
→ NPL Ratio ผิดปกติเกิน 20%
→ ส่ง Report ไม่ทันกำหนด BoT
→ ข้อมูลหายหลังจาก Reconciliation ผ่าน
```

---

## 6. Checklist ก่อนส่ง Report ให้ BoT

```
□ Pipeline รันสำเร็จทุก Step (ดูจาก Audit Log)
□ Data Quality ผ่านครบ 8/8 checks
□ Reconciliation ผ่านครบ 5/5 checks
□ NPL Ratio อยู่ในช่วงที่สมเหตุสมผล (0-20%)
□ มีข้อมูลครบ 12 เดือน ใน Gold Layer
□ Export CSV แล้ว เปิดใน Excel ตรวจอีกครั้ง
□ บันทึก Incident Log ถ้าพบปัญหาระหว่างรัน
```

---

## 7. วิธีรัน Pipeline ทั้งหมด

```bash
cd "D:\Data-Eng\Project\Credit-Risk-Pipeline"

# Windows
scripts\run_pipeline.bat

# Git Bash / Linux
bash scripts/run_pipeline.sh
```