"""
============================================================
data_quality.py
รัน Data Quality Checks บน Silver และ Gold Layer
ถ้า Check ไม่ผ่าน → หยุด Pipeline ทันที ไม่ยอมให้ผ่าน
============================================================
"""

import psycopg2
import psycopg2.extras
import sys
import os
from pathlib import Path

# ระบุ directory ของ file
current_dir = os.path.dirname(os.path.abspath(__file__))

# ถอย directory กลับไปที่ src
src_dir = os.path.abspath(os.path.join(current_dir, ".."))

# หาก syspath ไม่ตรงกับ src_dir ให้เอา src_dir เข้าไปแทนที่ โดย Python จะใช้ syspath เป็นจุดค้นหา module หรือ library ต่าง ๆ 
if src_dir not in sys.path:
    sys.path.insert(0, src_dir)
 
from common.logger import get_logger
from common.db_connection import check_config, get_connection

# ตั้งค่า logging
log = get_logger(__name__)

#ถอย directory กลับไปที่ src
SCRIPT_DIR = Path(__file__).resolve().parent.parent
SQL_FILE = SCRIPT_DIR/"SQL"/"quality"/"data_quality_checks.sql"


# อ่านไฟล์ SQL 
def read_sql_file(filepath: str) -> str:
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            sql = f.read()
        log.info(f"อ่านไฟล์ SQL สำเร็จ: {filepath}")
        return sql
    except FileNotFoundError:
        log.error(f"ไม่พบไฟล์ SQL: {filepath}")
        raise


# รัน Checks และรับผลลัพธ์ 
def run_quality_checks(conn, sql: str) -> list:
    """
    รัน SQL Checks แล้วคืนผลลัพธ์เป็น list of dict
    แต่ละ dict คือ 1 check result
    """
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute(sql)
        results = cur.fetchall()
    return results


# แสดงผลและตัดสิน
def evaluate_results(results: list) -> bool:
    """
    แสดงผลทุก check แบบตาราง
    คืนค่า True = ผ่านทั้งหมด, False = มีอย่างน้อย 1 check ไม่ผ่าน
    """
    log.info("=" * 50)
    log.info("DATA QUALITY CHECK RESULTS")
    log.info("=" * 50)
    log.info(f"{'Check Name':<35} {'Layer':<8} {'Status':<6} {'Failed':>8}  Detail")
    log.info(f"{'-' * 50}")

    all_passed = True
    failed_checks = []

    for row in results:
        check_name   = row["check_name"]
        layer        = row["layer"]
        status       = row["status"]
        failed_count = row["failed_count"]
        detail       = row["detail"]

        # สัญลักษณ์บอกสถานะ
        icon = "✅" if status == "PASS" else "❌"

        log.info(
            f"{icon} {check_name:<33} {layer:<8} {status:<6} "
            f"{failed_count:>8,}  {detail}"
        )

        # เก็บ check ที่ไม่ผ่านไว้รายงาน
        if status == "FAIL":
            all_passed = False
            failed_checks.append({
                "check_name": check_name,
                "layer": layer,
                "failed_count": failed_count,
                "detail": detail
            })

    log.info(f"{'-' * 50}")

    # สรุปผล
    total   = len(results)
    passed  = sum(1 for r in results if r["status"] == "PASS")
    failed  = total - passed

    log.info(f"สรุป: ผ่าน {passed}/{total} checks | ไม่ผ่าน {failed}/{total} checks")
    log.info("=" * 50)

    # แสดงรายละเอียด check ที่ไม่ผ่าน
    if failed_checks:
        log.error("รายการ Check ที่ไม่ผ่าน:")
        for fc in failed_checks:
            log.error(
                f" [{fc['layer'].upper()}] {fc['check_name']} "
                f"— พบ {fc['failed_count']:,} แถวผิดปกติ"
            )
            log.error(f"      ตรวจสอบ: {fc['detail']}")

    return all_passed


# Main 
def main():
    log.info("=" * 50)
    log.info(" เริ่ม Data Quality Framework")
    log.info(f"   Checks   : Silver (5 checks) + Gold (3 checks)")
    log.info(f"   SQL File : {SQL_FILE}")
    log.info("=" * 50)

    conn = None
    try:
        check_config()
        conn = get_connection()

        # อ่าน SQL
        sql = read_sql_file(SQL_FILE)

        # รัน Checks
        log.info("  กำลังรัน Data Quality Checks...")
        results = run_quality_checks(conn, sql)

        # ตัดสินผล
        all_passed = evaluate_results(results)

        if all_passed:
            log.info(" Data Quality ผ่านทั้งหมด! พร้อมส่ง Report ให้ BoT")
        else:
            # หยุด Pipeline ทันที ไม่ยอมให้ผ่าน
            raise ValueError(
                " Data Quality ไม่ผ่าน! Pipeline หยุดทำงาน "
                "กรุณาตรวจสอบและแก้ไขข้อมูลก่อนส่ง Report"
            )

    except ValueError as e:     # จับเฉพาะ Quality ไม่ผ่าน -> หยุด Pipeline
        log.error(f" {e}")
        raise

    except Exception as e:      # จับ error อื่นๆ เช่น DB หลุด
        log.error(f" Data Quality Framework ล้มเหลว: {e}")
        raise

    finally:
        if conn:
            conn.close()
            log.info("ปิดการเชื่อมต่อแล้ว")


if __name__ == "__main__":
    main()