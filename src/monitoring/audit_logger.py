"""
============================================================
 audit_logger.py
 บันทึกประวัติการรัน Pipeline เข้า gold.pipeline_run_log
 ใช้งานโดย import เข้าไปในทุก script ที่อยากติดตาม
============================================================
"""

import psycopg2
import sys
import os
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
from common.db_connection import get_connection

# ตั้งค่า Logging
log = get_logger(__name__)

# class คือการรวมข้อมูลและฟังก์ชันที่เกี่ยวข้องไว้ด้วยกัน
class PipelineAuditLogger:
    """
    Class สำหรับบันทึก Audit Log ของ Pipeline
    ใช้งานแบบนี้:

    logger = PipelineAuditLogger("full_pipeline")
    run_id = logger.start_step("bronze_transform")
    # ... ทำงาน ...
    logger.end_step(run_id, status="SUCCESS", rows=5000)
    """

    def __init__(self, pipeline_name: str):
        self.pipeline_name = pipeline_name
        self.conn = None

        try:
            self.conn = get_connection()
            log.info(f" Audit Logger พร้อมใช้งาน: {pipeline_name}")
        except Exception as e:
            log.warning(f"  Audit Logger เชื่อมต่อ DB ไม่ได้: {e}")
            log.warning("    Pipeline จะรันต่อโดยไม่บันทึก Audit Log")

    # บันทึกว่าเริ่มรัน step 
    def start_step(self, step_name: str) -> int:
        """
        บันทึกว่าเริ่มรัน step นี้แล้ว
        คืนค่า run_id เพื่อเอาไปอัปเดตตอนจบ
        """
        if not self.conn:
            return -1  # ถ้าเชื่อมต่อไม่ได้ คืน -1 แทน

        try:
            with self.conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO gold.pipeline_run_log
                        (pipeline_name, step_name, status, started_at)
                    VALUES (%s, %s, 'RUNNING', %s)
                    RETURNING run_id;
                """, (self.pipeline_name, step_name, datetime.now()))

                run_id = cur.fetchone()[0]
                self.conn.commit()

            log.info(f" Audit Log: เริ่ม step '{step_name}' (run_id={run_id})")
            return run_id

        except Exception as e:
            log.warning(f"  บันทึก Audit Log ไม่ได้: {e}")
            return -1

    # อัปเดตว่า step จบแล้ว 
    def end_step(
        self,
        run_id: int,
        status: str,           # "SUCCESS" หรือ "FAILED"
        rows: int = None,      # จำนวนแถวที่ประมวลผล
        error_msg: str = None  # ข้อความ error ถ้าพัง
    ):
        """
        อัปเดต Audit Log ว่า step จบแล้ว พร้อมผลลัพธ์
        """
        if not self.conn or run_id == -1:
            return

        try:
            finished_at = datetime.now()

            # ดึงเวลาเริ่มต้นมาคำนวณ duration
            with self.conn.cursor() as cur:
                cur.execute(
                    "SELECT started_at FROM gold.pipeline_run_log WHERE run_id = %s;",
                    (run_id,)
                )
                row = cur.fetchone()

                duration = None
                if row:
                    started_at = row[0]
                    duration = (finished_at - started_at).total_seconds()

                # อัปเดต record
                cur.execute("""
                    UPDATE gold.pipeline_run_log
                    SET
                        status        = %s,
                        finished_at   = %s,
                        duration_sec  = %s,
                        rows_processed = %s,
                        error_message = %s
                    WHERE run_id = %s;
                """, (status, finished_at, duration, rows, error_msg, run_id))

                self.conn.commit()

            icon = "✅" if status == "SUCCESS" else "❌"
            log.info(
                f" Audit Log: {icon} step จบแล้ว "
                f"(run_id={run_id}, status={status}, "
                f"duration={duration:.2f}s, rows={rows})"
            )

        except Exception as e:
            log.warning(f"  อัปเดต Audit Log ไม่ได้: {e}")

    # ปิด connection 
    def close(self):
        if self.conn:
            self.conn.close()


# ฟังก์ชันสรุป Audit Log 
def show_audit_summary(days: int = 7):
    """
    แสดงสรุปการรัน Pipeline ย้อนหลัง N วัน
    ใช้ดูว่า Pipeline ทำงานปกติไหม
    """
    conn = None
    try:
        conn = get_connection()
        with conn.cursor() as cur:
            cur.execute("""
                SELECT
                    run_date,
                    pipeline_name,
                    step_name,
                    status,
                    ROUND(duration_sec, 2)  AS duration_sec,
                    rows_processed,
                    error_message
                FROM gold.pipeline_run_log
                WHERE run_date >= CURRENT_DATE - INTERVAL '%s days'
                ORDER BY run_id DESC
                LIMIT 50;
            """, (days,))

            rows = cur.fetchall()

        if not rows:
            log.info(f" ไม่มี Audit Log ใน {days} วันที่ผ่านมา")
            return

        log.info(f"{'='*50}")
        log.info(f" AUDIT LOG — ย้อนหลัง {days} วัน")
        log.info(f"{'='*50}")
        log.info(
            f"{'Date':<12} {'Pipeline':<18} {'Step':<25} "
            f"{'Status':<10} {'Sec':>6} {'Rows':>8}"
        )
        log.info(f"{'-'*50}")

        for row in rows:
            date, pipeline, step, status, duration, row_count, error = row
            icon = "✅" if status == "SUCCESS" else "❌"
            log.info(
                f"{str(date):<12} {pipeline:<18} {step:<25} "
                f"{icon} {status:<8} "
                f"{str(duration or '-'):>6} "
                f"{str(row_count or '-'):>8}"
            )
            if error:
                log.error(f"   └─ Error: {error}")

        log.info(f"{'='*50}")

    except Exception as e:
        log.error(f"❌ ดู Audit Log ไม่ได้: {e}")
    finally:
        if conn:
            conn.close()