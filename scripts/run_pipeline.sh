"""
!/bin/bash
 ============================================================
 run_pipeline.sh
 รัน Credit Risk Pipeline ทั้งหมดอัตโนมัติ
 ใช้บน Linux/Unix/Mac หรือ WSL บน Windows

 วิธีใช้:
   chmod +x scripts/run_pipeline.sh   (ทำครั้งแรกครั้งเดียว)
   ./scripts/run_pipeline.sh

 Cron Job (รันอัตโนมัติทุกวันที่ 1 ของเดือน ตี 2):
   0 2 1 * * /path/to/run_pipeline.sh
============================================================
"""
# ตั้งค่าพื้นฐาน
# set -e คือ "ถ้า command ไหน error ให้หยุดทันที"
# ป้องกันการรัน step ถัดไปทั้งที่ step ก่อนพัง
set -e

# กำหนด path ของโปรเจกต์ (เปลี่ยนตาม path จริงในเครื่อง)
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
LOG_FILE="$LOG_DIR/pipeline_$(date '+%d-%b-%y_%H%M').log"
PYTHON="$PROJECT_DIR/venv/Scripts/python.exe"

# สร้างโฟลเดอร์ logs ถ้ายังไม่มี
mkdir -p "$LOG_DIR"

# ฟังก์ชัน log 
# เขียน log พร้อมเวลา ออกทั้งหน้าจอและไฟล์พร้อมกัน
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# ฟังก์ชันรัน Python script 
# รับชื่อ module แล้วรัน พร้อม log ว่าสำเร็จหรือล้มเหลว
run_step() {
    local step_name="$1"
    local module="$2"

    log "เริ่ม: $step_name"

    # รัน Python module จาก root ของโปรเจกต์
    cd "$PROJECT_DIR"
    "$PYTHON" -m "$module" >> "$LOG_FILE" 2>&1

    # $? คือ exit code ของคำสั่งล่าสุด (0 = สำเร็จ, อื่นๆ = error)
    if [ $? -eq 0 ]; then
        log "✅ สำเร็จ: $step_name"
    else
        log "❌ ล้มเหลว: $step_name — Pipeline หยุดทำงาน"
        exit 1
    fi
}

# เริ่ม Pipeline 
log "============================================================"
log "เริ่ม Credit Risk Pipeline"
log "   Project : $PROJECT_DIR"
log "   Log File: $LOG_FILE"
log "============================================================"

PIPELINE_START=$(date +%s)   # บันทึกเวลาเริ่มต้น (Unix timestamp)

# รันทีละขั้นตอน 
# ถ้าขั้นไหน error → set -e จะหยุดทันที ไม่รัน step ถัดไป

run_step "Step 1: Load Raw Transaction"  "src.phase1_ingestion.push_data_to_pgsql"
run_step "Step 2: Load FX Rate"          "src.phase1_ingestion.load_fx_rate"
run_step "Step 3: Bronze Transform"      "src.phase2_transformation.bronze_transform"
run_step "Step 4: Silver Transform"      "src.phase2_transformation.silver_transform"
run_step "Step 5: Gold Aggregate"        "src.phase2_transformation.gold_aggregate"
run_step "Step 6: Data Quality Check"   "src.quality.data_quality"
run_step "Step 7: Reconciliation"        "src.reconciliation.reconciliation"

# สรุปผล 
PIPELINE_END=$(date +%s)
DURATION=$((PIPELINE_END - PIPELINE_START))   # คำนวณเวลาที่ใช้ทั้งหมด

log "============================================================"
log "   Pipeline สำเร็จทั้งหมด!"
log "   ใช้เวลา: ${DURATION} วินาที"
log "   Log File: $LOG_FILE"
log "============================================================"