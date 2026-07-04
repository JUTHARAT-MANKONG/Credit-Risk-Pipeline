"""
============================================================
silver_transform.py
Transform ข้อมูลจาก Bronze → Silver Layer
Python ทำหน้าที่อ่านไฟล์ SQL แล้วส่งให้ PostgreSQL รัน
Logic ทั้งหมดอยู่ใน sql/transform/4_silver_transform.sql
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

# ถอย directory กลับไปที่ src โดย .parent คือการถอย 1 ครั้ง จาก phase2_transformation
SCRIPT_DIR = Path(__file__).resolve().parent.parent 
SQL_FILE = SCRIPT_DIR/"SQL"/"transform"/"4_silver_transform.sql"

# อ่านไฟล์ SQL (แปลงข้อมูลจากไฟล์ .sql เป็น str)
def read_sql_file(filepath: str) -> str:  
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            sql = f.read()
        log.info(f"อ่านไฟล์ SQL สำเร็จ: {filepath}")
        return sql
    except FileNotFoundError:
        log.error(f"ไม่พบไฟล์ SQL: {filepath}")
        raise

# รัน SQL ที่อ่านมาจากไฟล์ใน PostgreSQL ใช้ psycopg2 ส่ง SQL ตรงๆ
def run_sql(conn, sql: str): 
    with conn.cursor() as cur:
        cur.execute(sql)
        conn.commit()
    log.info("รัน SQL สำเร็จ")

# ตรวจสอบผลหลัง Transform 
def verify_silver(conn):
    """
    ตรวจสอบ 3 อย่างหลังจาก Transform เสร็จ
    1. จำนวนแถวทั้งหมดที่ได้
    2. แถวที่ตกหล่น (Bronze มีแต่ Silver ไม่มี เพราะ JOIN ไม่เจอ FX Rate)
    3. ตัวอย่างผลลัพธ์ที่คำนวณได้
    """

    # 1 นับแถวใน Silver 
    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM silver.loan_accounts;")
        silver_count = cur.fetchone()[0]
    log.info(f"Silver Layer: {silver_count:,} แถว")

    # 2 นับแถวใน Bronze 
    with conn.cursor() as cur:
        cur.execute("""
            SELECT COUNT(*) 
            FROM bronze.financial_transactions 
            WHERE orig_balance_after > 0;
        """)
        bronze_count = cur.fetchone()[0]
    log.info(f"Bronze Layer (balance > 0): {bronze_count:,} แถว")

    # 3 แถวที่ตกหล่น 
    dropped = bronze_count - silver_count
    if dropped > 0:
        log.warning(f"แถวที่ตกหล่น (JOIN FX Rate ไม่เจอ): {dropped:,} แถว")
    else:
        log.info("ไม่มีแถวตกหล่น JOIN FX Rate ครบทุกแถว")

    # 4 ตรวจ Loan Status Distribution 
    with conn.cursor() as cur:
        cur.execute("""
            SELECT loan_status, COUNT(*) AS total
            FROM silver.loan_accounts
            GROUP BY loan_status
            ORDER BY total DESC;
        """)
        rows = cur.fetchall()

    log.info("Loan Status Distribution:")
    for status, count in rows:
        log.info(f"   {status:<20} = {count:,} แถว")

    # 5 ตัวอย่างการคำนวณ Provision
    with conn.cursor() as cur:
        cur.execute("""
            SELECT
                delinquency_status,
                loan_status,
                provision_rate,
                ROUND(AVG(orig_balance_thb), 2)       AS avg_balance_thb,
                ROUND(AVG(provision_amount_thb), 2)   AS avg_provision_thb,
                COUNT(*)                               AS total
            FROM silver.loan_accounts
            GROUP BY delinquency_status, loan_status, provision_rate
            ORDER BY provision_rate;
        """)
        rows = cur.fetchall()

    log.info("Provision Summary:")
    log.info(f"   {'Delinquency':<10} {'Loan Status':<20} {'Rate':>6}  {'Avg Balance THB':>16}  {'Avg Provision THB':>18}  {'Count':>7}")
    log.info(f"   {'-'*85}")
    for row in rows:
        log.info(f"   {str(row[0]):<10} {str(row[1]):<20} {row[2]:>6.0%}  {row[3]:>16,.2f}  {row[4]:>18,.2f}  {row[5]:>7,}")

    return silver_count


# Main
def main():
    log.info("=" * 50)
    log.info("เริ่ม Silver Layer Transformation")
    log.info(f"   SQL File : {SQL_FILE}")
    log.info(f"   Source   : bronze.financial_transactions + raw.fx_rate")
    log.info(f"   Target   : silver.loan_accounts")
    log.info("=" * 50)

    conn = None
    try:
        check_config()
        conn = get_connection()

        # อ่าน SQL จากไฟล์
        sql = read_sql_file(SQL_FILE)

        # รัน Transform
        log.info("กำลัง Transform bronze → silver...")
        run_sql(conn, sql)

        # ตรวจสอบผล
        verify_silver(conn)

        log.info("Silver Transformation สำเร็จ!")

    except Exception as e:
        log.error(f"Silver Transformation ล้มเหลว: {e}")
        raise

    finally:
        if conn:
            conn.close()
            log.info("ปิดการเชื่อมต่อแล้ว")


if __name__ == "__main__":
    main()