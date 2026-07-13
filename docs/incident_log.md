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