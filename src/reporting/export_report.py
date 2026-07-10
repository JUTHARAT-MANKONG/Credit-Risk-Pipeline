"""
============================================================
 export_report.py
 Export Report จาก Gold/Silver Layer ออกมาเป็นไฟล์ CSV
 พร้อมส่งให้ BoT หรือผู้บริหาร
============================================================
"""

import pandas as pd
import sys
import os
from datetime import datetime
from pathlib import Path
# ระบุ directory ของ file
current_dir = os.path.dirname(os.path.abspath(__file__))

# ถอย directory กลับไปที่ src
src_dir = os.path.abspath(os.path.join(current_dir, ".."))

# หาก syspath ไม่ตรงกับ src_dir ให้เอา src_dir เข้าไปแทนที่ โดย Python จะใช้ syspath เป็นจุดค้นหา module หรือ library ต่าง ๆ 
if src_dir not in sys.path:
    sys.path.insert(0, src_dir)

from common.logger import get_logger
from common.db_connection import check_config, get_engine

# ตั้งค่า logging
log = get_logger(__name__)

# โฟลเดอร์เก็บ Report ที่ Export ออกมา
REPORT_DIR = "reports/output"


# อ่าน SQL จากไฟล์ 
def read_sql(filepath: str) -> str:
    with open(filepath, "r", encoding="utf-8") as f:
        return f.read()


# Export Report 1 ตัว
def export_report(engine, sql: str, filename: str):
    """
    รัน SQL แล้ว Export ผลลัพธ์เป็น CSV
    ชื่อไฟล์จะมี timestamp กำกับ เพื่อไม่ให้ทับของเก่า
    """
    log.info(f" กำลัง Export: {filename}")

    df = pd.read_sql(sql, engine)

    # สร้างชื่อไฟล์พร้อม timestamp
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_path = os.path.join(REPORT_DIR, f"{filename}_{timestamp}.csv")

    df.to_csv(output_path, index=False, encoding="utf-8-sig")
    # utf-8-sig คือ UTF-8 with BOM ทำให้ Excel เปิดภาษาไทยได้ถูกต้อง

    log.info(f" Export สำเร็จ: {output_path} ({len(df):,} แถว)")
    return output_path, len(df)


# แสดง Preview
def preview_report(engine, sql: str, report_name: str, rows: int = 5):
    """
    แสดงตัวอย่าง 5 แถวแรกของ Report ใน Terminal
    เหมือน spot check ก่อนส่งจริง
    """
    df = pd.read_sql(sql, engine)

    log.info(f"\n{'='*50}")
    log.info(f" Preview: {report_name} (แสดง {rows} แถวแรก)")
    log.info(f"{'='*50}")

    # แสดงผลทีละแถว
    for i, row in df.head(rows).iterrows():
        for col, val in row.items():
            log.info(f"   {col}: {val}")
        log.info("   " + "-"*40)

    log.info(f"   รวมทั้งหมด: {len(df):,} แถว")


# Main 
def main():
    log.info("=" * 50)
    log.info(" เริ่ม Reporting Layer — Export Reports")
    log.info(f"   Output Dir: {REPORT_DIR}")
    log.info("=" * 50)

    # สร้างโฟลเดอร์ output ถ้ายังไม่มี
    os.makedirs(REPORT_DIR, exist_ok=True)
    SQL_DIR = Path(__file__).resolve().parent.parent 
    engine = None
    try:
        check_config()
        engine = get_engine()

        # Report 1: Credit Risk Summary 
        sql1 = read_sql(SQL_DIR/"SQL/reports/1_credit_risk_summary.sql")
        preview_report(engine, sql1, "Credit Risk Summary")
        export_report(engine, sql1, "1_credit_risk_summary")

        # Report 2: NPL Analysis 
        # Report นี้มี 3 SELECT แยกกัน ต้องแยก export
        # ใช้วิธีอ่าน SQL แล้วแยกตาม -- ──
        sql2_parts = read_sql(SQL_DIR/"SQL/reports/2_npl_analysis.sql").split("-- ──")
        sqls2 = [s.strip() for s in sql2_parts if "SELECT" in s]

        names2 = ["2_npl_monthly", "2_npl_by_region", "2_npl_by_account_type"]
        for sql_part, name in zip(sqls2, names2):
            # ตัดเอาเฉพาะ SELECT statement (หลัง comment บรรทัดแรก)
            lines = sql_part.split("\n")
            sql_clean = "\n".join(
                l for l in lines
                if not l.strip().startswith("--") and l.strip()
            )
            if sql_clean.strip():
                export_report(engine, sql_clean, name)

        # Report 3: Provision Breakdown 
        sql3_parts = read_sql(SQL_DIR/"SQL/reports/3_provision_breakdown.sql").split("-- ──")
        sqls3 = [s.strip() for s in sql3_parts if "SELECT" in s]

        names3 = ["3_provision_monthly", "3_provision_by_delinquency"]
        for sql_part, name in zip(sqls3, names3):
            lines = sql_part.split("\n")
            sql_clean = "\n".join(
                l for l in lines
                if not l.strip().startswith("--") and l.strip()
            )
            if sql_clean.strip():
                export_report(engine, sql_clean, name)

        log.info("=" * 50)
        log.info(" Export Report ทั้งหมดสำเร็จ!")
        log.info(f"   ดู Report ได้ที่: {REPORT_DIR}/")
        log.info("=" * 50)

    except Exception as e:
        log.error(f" Export Report ล้มเหลว: {e}")
        raise


if __name__ == "__main__":
    main()