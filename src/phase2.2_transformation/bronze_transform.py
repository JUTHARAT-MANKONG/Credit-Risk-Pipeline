"""
============================================================
bronze_transform.py
แปลงข้อมูลจาก raw.financial_transactions เข้า bronze layer
- ตรวจสอบและแปลง Data Type ให้ถูกต้อง
- มาตรฐาน Delinquency_Status เป็น M0, M1, M2, M3, M4+
- ข้อมูลที่ Type ผิดปกติ ถูกแยกไปเก็บที่ bronze.quarantine_log
============================================================
"""

import psycopg2
import psycopg2.extras
from dotenv import load_dotenv
import os
import json
import logging
from datetime import datetime

# ตั้งค่า Logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
log = logging.getLogger(__name__)

# โหลดค่าจาก .env
load_dotenv()
DB_CONFIG = {
    "host":     os.getenv("DB_HOST"),
    "port":     os.getenv("DB_PORT"),
    "dbname":   os.getenv("DB_NAME"),
    "user":     os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
}

def check_config():
    missing = [k for k, v in DB_CONFIG.items() if not v]
    if missing:
        raise ValueError(f"ไม่พบค่าใน .env: {missing}")
    log.info("✅ Config ครบถ้วน")


def get_connection():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        log.info("✅ เชื่อมต่อ PostgreSQL สำเร็จ")
        return conn
    except Exception as e:
        log.error(f"❌ เชื่อมต่อไม่ได้: {e}")
        raise


# ── 3. ฟังก์ชันแปลง Type แต่ละแบบ ────────────────────────────
# แต่ละฟังก์ชันรับค่า string จาก raw แล้วพยายามแปลง
# ถ้าแปลงไม่ได้ จะ raise ValueError ออกมา ให้ตัวเรียกจับได้

def to_int(value):
    """แปลง string เป็น integer เช่น '50' -> 50"""
    if value == "" or value is None:
        return None
    return int(value)


def to_decimal(value):
    """แปลง string เป็นทศนิยม เช่น '41397.17' -> 41397.17"""
    if value == "" or value is None:
        return None
    return float(value)


def to_boolean(value):
    """แปลง string เป็น True/False เช่น 'True' -> True, 'False' -> False"""
    if value == "" or value is None:
        return None
    if value in ("True", "true", "1"):
        return True
    if value in ("False", "false", "0"):
        return False
    raise ValueError(f"ไม่ใช่ค่า boolean ที่รู้จัก: '{value}'")


def to_date(value):
    """แปลง string เป็น date เช่น '2014-01-15' -> date object"""
    if value == "" or value is None:
        return None
    return datetime.strptime(value, "%Y-%m-%d").date()


def to_timestamp(value):
    """แปลง string เป็น timestamp เช่น '2024-09-16 19:56:16'"""
    if value == "" or value is None:
        return None
    return datetime.strptime(value, "%Y-%m-%d %H:%M:%S")


def to_text(value):
    """เก็บเป็น text ตรงๆ ไม่ต้องแปลง"""
    if value == "":
        return None
    return value


# ── 4. กำหนดว่า column ไหนต้องแปลงด้วยฟังก์ชันไหน ────────────
# Dictionary นี้คือ "พิมพ์เขียว" บอกว่า column ไหนต้อง validate ยังไง
COLUMN_RULES = {
    "cust_id":                       to_text,
    "cust_age":                      to_int,
    "cust_gender":                   to_text,
    "cust_marital_status":           to_text,
    "cust_dependents":               to_int,
    "cust_education":                to_text,
    "cust_employment_status":        to_text,
    "cust_occupation_sector":        to_text,
    "cust_annual_income_usd":        to_decimal,
    "cust_home_ownership":           to_text,

    "account_id":                    to_text,
    "account_type":                  to_text,
    "account_open_date":             to_date,
    "account_status":                to_text,
    "account_kyc_tier":              to_text,
    "primary_branch_region":         to_text,
    "total_assets_under_management": to_decimal,
    "has_active_credit_card":        to_boolean,
    "has_active_loan":               to_boolean,
    "digital_banking_enrollment":    to_boolean,

    "txn_id":                        to_text,
    "txn_timestamp":                 to_timestamp,
    "txn_type":                      to_text,
    "txn_channel":                   to_text,
    "txn_amount_usd":                to_decimal,
    "txn_currency":                  to_text,
    "counterparty_id":               to_text,
    "counterparty_type":             to_text,
    "merchant_category_code_mcc":    to_int,
    "txn_response_code":             to_text,

    "orig_balance_before":           to_decimal,
    "orig_balance_after":            to_decimal,
    "dest_balance_before":           to_decimal,
    "dest_balance_after":            to_decimal,
    "monthly_avg_inflow":            to_decimal,
    "monthly_avg_outflow":           to_decimal,
    "overdraft_limit_usd":           to_decimal,
    "days_in_overdraft_l12m":        to_int,

    "credit_card_utilization_rate":  to_decimal,
    "delinquency_status":            to_text,   # มาตรฐานทำในขั้นถัดไปแยก
    "risk_score_internal":           to_int,
    "bureau_credit_score":           to_int,

    "device_type":                   to_text,
    "device_ip_country":             to_text,
    "is_vpn_used":                   to_boolean,
    "login_attempts_fail_count":     to_int,
    "txn_velocity_1h":               to_int,
    "behavioral_anomaly_flag":       to_boolean,

    "target_credit_default":         to_boolean,
    "target_is_fraud_aml":           to_boolean,
}


# ── 5. มาตรฐาน Delinquency_Status ───────────────────────────
# แปลงค่าจาก raw (Current, 30_Days_Past_Due, ...) ให้เป็น M0-M4+
# ตามที่ตกลงไว้ใน Data Dictionary
DELINQUENCY_MAP = {
    "Current":                "M0",
    "30_Days_Past_Due":       "M1",
    "60_Days_Past_Due":       "M2",
    "90_Plus_Days_Past_Due":  "M3",   # จะถูกปรับเป็น M4+ ถ้า Target_Credit_Default = True
}


def standardize_delinquency(raw_status: str, is_default: bool) -> str:
    """
    แปลงค่า Delinquency_Status จาก raw ให้เป็นมาตรฐาน M0-M4+
    ถ้า 90_Plus_Days_Past_Due และผิดนัดชำระจริง (is_default=True) -> M4+
    """
    mapped = DELINQUENCY_MAP.get(raw_status)
    if mapped is None:
        raise ValueError(f"ไม่รู้จักค่า Delinquency_Status: '{raw_status}'")

    if mapped == "M3" and is_default:
        return "M4+"
    return mapped


# ── 6. แปลงข้อมูล 1 row ───────────────────────────────────────
# คืนค่า (ข้อมูลที่แปลงแล้ว, None) ถ้าสำเร็จ
# คืนค่า (None, รายละเอียด error) ถ้าพบปัญหา
def transform_row(raw_row: dict):
    transformed = {}

    for column, convert_func in COLUMN_RULES.items():
        raw_value = raw_row.get(column)
        try:
            transformed[column] = convert_func(raw_value)
        except (ValueError, TypeError) as e:
            # เจอ column แรกที่แปลงไม่ได้ หยุดทันที ส่งกลับไป quarantine
            error_info = {
                "failed_column": column,
                "failed_value": raw_value,
                "failure_reason": str(e),
            }
            return None, error_info

    # ผ่านการแปลง Type ทุก column แล้ว ลองมาตรฐาน Delinquency_Status ต่อ
    try:
        transformed["delinquency_status"] = standardize_delinquency(
            raw_row.get("delinquency_status"),
            transformed.get("target_credit_default", False)
        )
    except ValueError as e:
        error_info = {
            "failed_column": "delinquency_status",
            "failed_value": raw_row.get("delinquency_status"),
            "failure_reason": str(e),
        }
        return None, error_info

    return transformed, None


# ── 7. ดึงข้อมูลทั้งหมดจาก raw ────────────────────────────────
def fetch_raw_data(conn):
    log.info("📂 อ่านข้อมูลจาก raw.financial_transactions")

    # RealDictCursor ทำให้ผลลัพธ์แต่ละแถวเป็น dict
    # เข้าถึงค่าด้วยชื่อ column ได้เลย เช่น row["cust_age"]
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute("SELECT * FROM raw.financial_transactions;")
        rows = cur.fetchall()

    log.info(f"📊 อ่านข้อมูลได้ {len(rows):,} แถว")
    return rows


# ── 8. Insert ข้อมูลดีเข้า bronze.financial_transactions ─────
def insert_bronze(conn, good_rows: list):
    if not good_rows:
        log.warning("⚠️  ไม่มีข้อมูลดีให้ insert เข้า bronze")
        return 0

    columns = list(good_rows[0].keys())
    col_str = ", ".join(columns)

    # ON CONFLICT DO NOTHING ป้องกัน error ถ้า cust_id ซ้ำ (Primary Key)
    # เพราะ table bronze ตั้ง cust_id เป็น PRIMARY KEY ไว้
    sql = f"""
        INSERT INTO bronze.financial_transactions ({col_str})
        VALUES %s
        ON CONFLICT (cust_id) DO NOTHING;
    """

    values = [tuple(row[c] for c in columns) for row in good_rows]

    with conn.cursor() as cur:
        cur.execute("TRUNCATE TABLE bronze.financial_transactions;")
        psycopg2.extras.execute_values(cur, sql, values)
        conn.commit()

    log.info(f"✅ Insert ข้อมูลดีเข้า bronze.financial_transactions: {len(good_rows):,} แถว")
    return len(good_rows)


# ── 9. Insert ข้อมูลเสียเข้า bronze.quarantine_log ───────────
def insert_quarantine(conn, bad_rows: list):
    if not bad_rows:
        log.info("✅ ไม่มีข้อมูลผิดปกติ ไม่ต้อง quarantine")
        return 0

    sql = """
        INSERT INTO bronze.quarantine_log
            (cust_id, txn_id, failed_column, failed_value, failure_reason, raw_row_data)
        VALUES %s;
    """

    values = []
    for raw_row, error_info in bad_rows:
        values.append((
            raw_row.get("cust_id"),
            raw_row.get("txn_id"),
            error_info["failed_column"],
            error_info["failed_value"],
            error_info["failure_reason"],
            json.dumps(raw_row, default=str),   # เก็บทั้ง row เป็น JSON
        ))

    with conn.cursor() as cur:
        cur.execute("TRUNCATE TABLE bronze.quarantine_log;")
        psycopg2.extras.execute_values(cur, sql, values)
        conn.commit()

    log.warning(f"⚠️  Insert ข้อมูลผิดปกติเข้า bronze.quarantine_log: {len(bad_rows):,} แถว")
    return len(bad_rows)


# ── 10. Main ───────────────────────────────────────────────────
def main():
    log.info("=" * 50)
    log.info("🚀 เริ่ม Bronze Layer Transformation")
    log.info("=" * 50)

    try:
        check_config()
        conn = get_connection()

        raw_rows = fetch_raw_data(conn)

        good_rows = []   # ข้อมูลที่แปลง Type สำเร็จทุก column
        bad_rows  = []   # (raw_row, error_info) ของแถวที่แปลงพลาด

        for raw_row in raw_rows:
            transformed, error_info = transform_row(raw_row)
            if transformed is not None:
                good_rows.append(transformed)
            else:
                bad_rows.append((raw_row, error_info))

        log.info(f"📊 สรุป: ผ่าน {len(good_rows):,} แถว / ผิดปกติ {len(bad_rows):,} แถว")

        insert_bronze(conn, good_rows)
        insert_quarantine(conn, bad_rows)

        log.info("🎉 Bronze Transformation สำเร็จ!")

    except Exception as e:
        log.error(f"💥 Bronze Transformation ล้มเหลว: {e}")
        raise

    finally:
        if conn:
            conn.close()
            log.info("🔌 ปิดการเชื่อมต่อแล้ว")


if __name__ == "__main__":
    main()