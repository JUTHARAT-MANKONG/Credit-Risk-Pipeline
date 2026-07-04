"""
============================================================
gold_aggregate.py
สรุปข้อมูลจาก Silver → Gold Layer
คำนวณ KPI 3 ตัวสรุปรายเดือน พร้อมส่ง Regulatory Report
============================================================
"""

import psycopg2
import pandas as pd
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
SQL_FILE = SCRIPT_DIR/"SQL"/"transform"/"2_gold_aggregate.sql"

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


# รัน SQL 
def run_sql(conn, sql: str):
    with conn.cursor() as cur:
        cur.execute(sql)
        conn.commit()
    log.info("รัน SQL สำเร็จ")


# แสดงผล KPI Report 
def show_kpi_report(conn):
    """
    ดึง KPI Report จาก Gold Layer แล้วแสดงผลใน Terminal
    เหมือน Preview ก่อนส่งจริงให้ BoT
    """
    with conn.cursor() as cur:
        cur.execute("""
            SELECT
                report_month,
                total_accounts,
                outstanding_balance_thb,
                npl_accounts,
                npl_ratio_pct,
                total_provision_thb
            FROM gold.monthly_credit_risk_report
            ORDER BY report_month;
        """)
        rows = cur.fetchall()

    log.info("=" * 50)
    log.info("CREDIT RISK REGULATORY REPORT — สรุปรายเดือน")
    log.info("=" * 50)
    log.info(
        f"{'Month':<10} {'Accounts':>9} {'Balance THB':>18} "
        f"{'NPL':>6} {'NPL%':>7} {'Provision THB':>18}"
    )
    log.info(f"{'-' * 50}")

    for row in rows:
        month, accounts, balance, npl, npl_pct, provision = row
        log.info(
            f"{month:<10} {accounts:>9,} {balance:>18,.2f} "
            f"{npl:>6,} {npl_pct:>6.2f}% {provision:>18,.2f}"
        )

    log.info(f"{'-' * 50}")
    log.info(f"รวม {len(rows)} เดือน")
    log.info("=" * 50)

    # สรุปภาพรวมทั้งปี 
    with conn.cursor() as cur:
        cur.execute("""
            SELECT
                SUM(total_accounts)                     AS total_accounts,
                ROUND(SUM(outstanding_balance_thb), 2)  AS total_balance,
                SUM(npl_accounts)                       AS total_npl,
                ROUND(
                    SUM(npl_accounts)::NUMERIC
                    / NULLIF(SUM(total_accounts), 0) * 100
                , 4)                                    AS avg_npl_ratio,
                ROUND(SUM(total_provision_thb), 2)      AS total_provision
            FROM gold.monthly_credit_risk_report;
        """)
        row = cur.fetchone()

    log.info("สรุปภาพรวมทั้งปี 2024")
    log.info(f"   จำนวนบัญชีทั้งหมด     : {row[0]:>15,} บัญชี")
    log.info(f"   Outstanding Balance   : {row[1]:>15,.2f} THB")
    log.info(f"   NPL ทั้งหมด           : {row[2]:>15,} บัญชี")
    log.info(f"   NPL Ratio             : {row[3]:>15.4f} %")
    log.info(f"   Total Provision       : {row[4]:>15,.2f} THB")

    return len(rows)


# Main 
def main():
    log.info("=" * 50)
    log.info("เริ่ม Gold Layer Aggregation")
    log.info(f"   SQL File : {SQL_FILE}")
    log.info(f"   Source   : silver.loan_accounts")
    log.info(f"   Target   : gold.monthly_credit_risk_report")
    log.info("=" * 50)

    conn = None
    try:
        check_config()
        conn = get_connection()

        sql = read_sql_file(SQL_FILE)

        log.info("กำลังสรุป KPI รายเดือน...")
        run_sql(conn, sql)

        months = show_kpi_report(conn)

        log.info(f"Gold Aggregation สำเร็จ! ได้ Report {months} เดือน")

    except Exception as e:
        log.error(f"Gold Aggregation ล้มเหลว: {e}")
        raise

    finally:
        if conn:
            conn.close()
            log.info("ปิดการเชื่อมต่อแล้ว")


if __name__ == "__main__":
    main()