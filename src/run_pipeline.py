"""
============================================================
 run_pipeline.py
 Orchestrator หลักของ Pipeline
 เรียกทุก step ตามลำดับ พร้อมบันทึก Audit Log ทุก step
============================================================
"""

import os
import sys
import time
from pathlib import Path
from datetime import datetime

# ระบุ directory ของ file
current_dir = os.path.dirname(os.path.abspath(__file__))

# ถอย directory กลับไปที่ src
src_dir = os.path.abspath(os.path.join(current_dir, ".."))

# หาก syspath ไม่ตรงกับ src_dir ให้เอา src_dir เข้าไปแทนที่ โดย Python จะใช้ syspath เป็นจุดค้นหา module หรือ library ต่าง ๆ 
if src_dir not in sys.path:
    sys.path.insert(0, src_dir)

from common.logger import get_logger
from common.db_connection import check_config
from monitoring.audit_logger import PipelineAuditLogger, show_audit_summary

# Import ทุก step ของ Pipeline
from phase1_ingestion import push_data_to_pgsql
from phase1_ingestion import load_fx_rate
from phase2_transformation import bronze_transform
from phase2_transformation import silver_transform
from phase2_transformation import gold_aggregate
from quality import data_quality
from reconciliation import reconciliation

# ตั้งค่า Logging
log = get_logger(__name__)

PIPELINE_NAME = "full_pipeline"


# รัน 1 step พร้อมบันทึก Audit Log 
def run_step(audit: PipelineAuditLogger, step_name: str, func, rows: int = None):
    """
    รัน 1 step ของ Pipeline
    บันทึก Audit Log ตอนเริ่มและตอนจบอัตโนมัติ
    ถ้า error → บันทึก FAILED แล้ว raise ต่อ
    """
    run_id = audit.start_step(step_name)
    start  = time.time()

    try:
        func()
        duration = time.time() - start
        audit.end_step(run_id, status="SUCCESS", rows=rows)
        log.info(f"✅ {step_name} ({duration:.2f}s)")

    except Exception as e:
        duration = time.time() - start
        audit.end_step(run_id, status="FAILED", error_msg=str(e))
        log.error(f"❌ {step_name} ล้มเหลว: {e}")
        raise


# Main Pipeline 
def main():
    log.info("=" * 50)
    log.info(" เริ่ม Credit Risk Pipeline (Full Run)")
    log.info(f"   วันที่รัน: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    log.info("=" * 50)

    pipeline_start = time.time()

    # สร้าง Audit Logger — บันทึกทุก step
    audit = PipelineAuditLogger(PIPELINE_NAME)

    try:
        check_config()

        # รันทีละ step ตามลำดับ
        # ถ้า step ไหน error → หยุดทันที
        run_step(audit, "load_raw_transaction",  push_data_to_pgsql.main)
        run_step(audit, "load_fx_rate",          load_fx_rate.main)
        run_step(audit, "bronze_transform",      bronze_transform.main)
        run_step(audit, "silver_transform",      silver_transform.main)
        run_step(audit, "gold_aggregate",        gold_aggregate.main)
        run_step(audit, "data_quality",          data_quality.main)
        run_step(audit, "reconciliation",        reconciliation.main)

        # สรุปผลรวม
        total_duration = time.time() - pipeline_start
        log.info("=" * 50)
        log.info(f" Pipeline สำเร็จทั้งหมด!")
        log.info(f"   ใช้เวลารวม: {total_duration:.2f} วินาที")
        log.info("=" * 50)

        # แสดง Audit Log ย้อนหลัง 1 วัน
        show_audit_summary(days=1)

    except Exception as e:
        total_duration = time.time() - pipeline_start
        log.error(f" Pipeline ล้มเหลว หลังรัน {total_duration:.2f} วินาที")
        log.error(f"   สาเหตุ: {e}")
        sys.exit(1)

    finally:
        audit.close()


if __name__ == "__main__":
    main()