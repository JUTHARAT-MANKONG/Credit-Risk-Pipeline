# Incident Log

## Credit Risk Pipeline — Production Issues

---

## วิธีบันทึก Incident

ทุกครั้งที่เจอปัญหาใน Production ให้บันทึกตาม Template ด้านล่างนี้

```
## INC-XXX — ชื่อปัญหา

| | |
|---|---|
| วันที่ | YYYY-MM-DD HH:MM |
| ผู้พบปัญหา | ชื่อ |
| ความรุนแรง | P1 (Critical) / P2 (High) / P3 (Medium) |
| สถานะ | Open / Resolved |

### อาการที่พบ
อธิบายสิ่งที่เกิดขึ้น

### Root Cause
สาเหตุที่แท้จริง

### วิธีแก้ไข (Resolution)
สิ่งที่ทำเพื่อแก้ปัญหา

### แนวทางป้องกัน (Prevention)
จะป้องกันไม่ให้เกิดซ้ำได้อย่างไร
```

---

## INC-001 — ModuleNotFoundError: No module named 'dotenv'

| | |
|---|---|
| **วันที่** | 2026-07-09 16:12 |
| **ผู้พบปัญหา** | Jutharat Mankong |
| **ความรุนแรง** | P2 (High) — Pipeline รันไม่ได้ |
| **สถานะ** | Resolved |

### อาการที่พบ

รัน `bash scripts/run_pipeline.sh` ใน Git Bash แล้วได้ error

```
ModuleNotFoundError: No module named 'dotenv'
```

Pipeline หยุดที่ Step 1 ทันที ไม่รันต่อ

### Root Cause

Git Bash ใช้ Python จาก PyManager (`/c/Program Files/PyManager/python`) ไม่ใช่ Python จาก venv ของโปรเจกต์ ทำให้ library ที่ติดตั้งไว้ใน venv เช่น `python-dotenv` ไม่ถูกโหลด

### วิธีแก้ไข

ระบุ path ของ Python ใน venv โดยตรงใน `run_pipeline.sh`

```bash
PYTHON="$PROJECT_DIR/venv/Scripts/python.exe"
```

แล้วเปลี่ยนทุกที่ที่เรียก `python` เป็น `"$PYTHON"` แทน

### แนวทางป้องกัน

เพิ่มการตรวจสอบ Python path ตอนต้น script

```bash
if [ ! -f "$PYTHON" ]; then
    echo "ERROR: ไม่พบ Python venv ที่ $PYTHON"
    exit 1
fi
```

---

## INC-002 — Windows Batch Script หา Label ไม่เจอ

| | |
|---|---|
| **วันที่** | 2026-07-09 |
| **ผู้พบปัญหา** | Jutharat Mankong |
| **ความรุนแรง** | P3 (Medium) — Script รันไม่ได้บน Windows |
| **สถานะ** | Resolved |

### อาการที่พบ

```
The system cannot find the batch label specified - LOG
```

### Root Cause

Windows CMD อ่านไฟล์ top-down พอเจอ `goto :END` แล้วหยุดอ่าน ทำให้ Subroutine `:LOG` และ `:RUN_STEP` ที่อยู่หลัง `goto :END` ถูกมองข้ามไป

### วิธีแก้ไข

เขียน Batch Script ใหม่แบบไม่ใช้ Subroutine เขียน `echo` และ `python -m` ตรงๆ ทีละ Step แทน

### แนวทางป้องกัน

หลีกเลี่ยงการใช้ Subroutine ซับซ้อนใน Windows Batch Script ถ้าต้องการ Logic ซับซ้อนให้ใช้ PowerShell หรือ Python แทน

---

## INC-003 — Bronze Table ใช้ cust_id เป็น PRIMARY KEY ผิด

| | |
|---|---|
| วันที่ | 2026-07-14 |
| ความรุนแรง | P1 (Critical) — ข้อมูลหายและ Report ผิด |
| สถานะ | Resolved |

### อาการที่พบ
bronze.financial_transactions เก็บข้อมูลแค่ 1 row ต่อ cust_id
ทั้งที่ลูกค้า 1 คนมีหลาย Transaction (เฉลี่ย 14 transactions/คน)

### Root Cause
DDL กำหนด cust_id TEXT PRIMARY KEY ซึ่งทำให้ห้ามมีค่าซ้ำ
และ ON CONFLICT (cust_id) DO NOTHING ทิ้ง Transaction ที่เหลือทั้งหมด

### วิธีแก้ไข
เปลี่ยน PRIMARY KEY จาก cust_id เป็น txn_id
เพราะ 1 row = 1 Transaction ไม่ใช่ 1 Customer

### แนวทางป้องกัน
ตรวจสอบ Grain ของข้อมูลให้ชัดก่อนออกแบบ Schema
และ Review DDL ทุกครั้งกับ Business Requirements

---

## INC-004 — Provision Rate ไม่ดู Target_Credit_Default ก่อน Delinquency Status

| | |
|---|---|
| **วันที่** | 2026-07-19 |
| **ผู้พบปัญหา** | Jutharat Mankong |
| **ความรุนแรง** | P1 (Critical) — Provision Amount คำนวณผิด ส่งผลต่อ Report ที่ส่ง BoT |
| **สถานะ** | Resolved |

### อาการที่พบ

ลูกค้าที่มี `Delinquency_Status = M1` (ค้างชำระ 30 วัน) 
แต่ `Target_Credit_Default = True` (ธนาคารตัดสินแล้วว่าผิดนัดชำระ)
ได้รับ `provision_rate = 2%` แทนที่จะเป็น `100%`

ผลกระทบ:
- `loan_status` = NPL ถูกต้อง แต่ `provision_rate` ผิด
- เงินสำรองที่คำนวณได้ต่ำกว่าความเป็นจริงมาก
- Report Total Provision ที่ส่ง BoT ผิดพลาด

### Root Cause

**bronze_transform.py — standardize_delinquency()**
ตรวจเฉพาะกรณี `M3 + Default=True` เท่านั้นถึงจะยกระดับเป็น M4+
กรณี M0/M1/M2 + Default=True ไม่ถูกยกระดับ

```python
# โค้ดเดิมที่ผิด
if mapped == "M3" and is_default:    # ← ตรวจแค่ M3
    return "M4+"
return mapped   # M0/M1/M2 + Default=True ยังคืนเป็น M0/M1/M2 อยู่
```

**silver_transform.sql — Provision Rate CASE WHEN**
ลำดับ CASE WHEN ตรวจ Delinquency ก่อน Default ทำให้ M1 ถูกจับก่อนแม้จะ Default

```sql
-- โค้ดเดิมที่ผิด
CASE
    WHEN b.delinquency_status = 'M1'  THEN 0.02   -- จับตรงนี้ก่อน!
    ...
    WHEN b.target_credit_default = TRUE THEN 1.00  -- ไม่มีทางถึงบรรทัดนี้ถ้า M1
END
```

### วิธีแก้ไข

**1. แก้ bronze_transform.py**

```python
# โค้ดใหม่ที่ถูกต้อง
def standardize_delinquency(raw_status: str, is_default: bool) -> str:
    mapped = DELINQUENCY_MAP.get(raw_status)
    if mapped is None:
        raise ValueError(f"ไม่รู้จักค่า Delinquency_Status: '{raw_status}'")

    # ถ้า Default=True ไม่ว่า Delinquency จะเป็นอะไร → M4+ ทันที
    if is_default:
        return "M4+"
    return mapped
```

**2. แก้ silver_transform.sql**

```sql
-- โค้ดใหม่ที่ถูกต้อง: ตรวจ Default ก่อนเสมอ
CASE
    WHEN b.target_credit_default = TRUE  THEN 1.00  -- Default มาก่อน
    WHEN b.delinquency_status = 'M0'     THEN 0.01
    WHEN b.delinquency_status = 'M1'     THEN 0.02
    WHEN b.delinquency_status = 'M2'     THEN 0.10
    WHEN b.delinquency_status = 'M3'     THEN 0.50
    WHEN b.delinquency_status = 'M4+'    THEN 1.00
    ELSE 0.01
END AS provision_rate
```

### แนวทางป้องกัน

1. เขียน Business Rule ให้ชัดเจนใน BRD ว่า
   **"Target_Credit_Default = True มีความสำคัญสูงกว่า Delinquency Status เสมอ"**

2. เพิ่ม Data Quality Check ตรวจกรณีนี้โดยเฉพาะ

```sql
-- เพิ่มใน data_quality_checks.sql
SELECT 'silver_default_provision_check' AS check_name,
       'silver'                          AS layer,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
       COUNT(*)                          AS failed_count,
       'ลูกค้า Default=True ต้องมี provision_rate = 1.00 เสมอ' AS detail
FROM silver.loan_accounts
WHERE target_credit_default = TRUE
  AND provision_rate != 1.00;
```

3. รัน Query ตรวจสอบหลังแก้ไขทุกครั้ง

```sql
SELECT delinquency_status, target_credit_default,
       provision_rate, loan_status, COUNT(*)
FROM silver.loan_accounts
WHERE target_credit_default = TRUE
GROUP BY 1,2,3,4
ORDER BY 1;
-- ทุกแถวต้องมี provision_rate = 1.00
```