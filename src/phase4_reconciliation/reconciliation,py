"""
============================================================
reconciliation.py
เปรียบเทียบข้อมูลระหว่าง Layer
ตรวจว่าข้อมูลไม่หายและยอดตรงกันตลอด Pipeline
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

# ถอย directory กลับไปที่ src
SCRIPT_DIR = Path(__file__).resolve().parent.parent
SQL_FILE = SCRIPT_DIR/"SQL"/"reconciliation"/"reconciliation_checks.sql"


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


# รัน Reconciliation Checks 
def run_reconciliation(conn, sql: str) -> list:
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute(sql)
        results = cur.fetchall()
    return results


# แสดงผลและตัดสิน
def evaluate_results(results: list) -> bool:
    log.info("=" * 50)
    log.info(" RECONCILIATION RESULTS")
    log.info("=" * 50)
    log.info(
        f"{'Check Name':<35} {'Source':>15} {'Target':>15} "
        f"{'Diff':>10} {'Status'}"
    )
    log.info(f"{'-' * 50}")

    all_passed = True
    failed_checks = []

    for row in results:
        check_name   = row["check_name"]
        source_value = row["source_value"]
        target_value = row["target_value"]
        difference   = row["difference"]
        status       = row["status"]
        detail       = row["detail"]

        icon = "✅" if status == "PASS" else "❌"

        # แสดงตัวเลขพร้อม comma สำหรับอ่านง่าย
        log.info(
            f"{icon} {check_name:<33} "
            f"{float(source_value):>15,.2f} "
            f"{float(target_value):>15,.2f} "
            f"{float(difference):>10,.2f} "
            f"{status}"
        )

        if status == "FAIL":
            all_passed = False
            failed_checks.append({
                "check_name": check_name,
                "difference": difference,
                "detail": detail
            })

    log.info(f"{'-' * 50}")

    total  = len(results)
    passed = sum(1 for r in results if r["status"] == "PASS")
    failed = total - passed

    log.info(f"สรุป: ผ่าน {passed}/{total} | ไม่ผ่าน {failed}/{total}")
    log.info("=" * 75)

    if failed_checks:
        log.error("รายการที่ไม่ผ่าน:")
        for fc in failed_checks:
            log.error(
                f"   {fc['check_name']} "
                f"— ผลต่าง {float(fc['difference']):,.2f}"
            )
            log.error(f"      ตรวจสอบ: {fc['detail']}")

    return all_passed


# Main 
def main():
    log.info("=" * 50)
    log.info("เริ่ม Reconciliation Framework")
    log.info(f"   Checks   : Count (3) + Amount (2) = 5 checks")
    log.info(f"   SQL File : {SQL_FILE}")
    log.info("=" * 50)

    conn = None
    try:
        check_config()
        conn = get_connection()

        sql     = read_sql_file(SQL_FILE)
        results = run_reconciliation(conn, sql)

        all_passed = evaluate_results(results)

        if all_passed:
            log.info("Reconciliation ผ่านทั้งหมด! ข้อมูลไม่หายระหว่าง Layer")
        else:
            raise ValueError(
                "Reconciliation ไม่ผ่าน! "
                "ข้อมูลอาจหายหรือยอดไม่ตรงระหว่าง Layer "
                "กรุณาตรวจสอบก่อนส่ง Report"
            )

    except ValueError as e:
        log.error(f" {e}")
        raise

    except Exception as e:
        log.error(f" Reconciliation ล้มเหลว: {e}")
        raise

    finally:
        if conn:
            conn.close()
            log.info(" ปิดการเชื่อมต่อแล้ว")


if __name__ == "__main__":
    main()