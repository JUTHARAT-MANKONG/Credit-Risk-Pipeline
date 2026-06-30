# รวมฟังก์ชั่นเชื่อมต่อ Database

import os
import psycopg2
from sqlalchemy import create_engine
from dotenv import load_dotenv
from common.logger import get_logger

log = get_logger(__name__)

# โหลดค่าจาก .env
load_dotenv()

DB_CONFIG = {
    "host" : os.getenv("DB_HOST"),
    "port" : os.getenv("DB_PORT"),
    "dbname" : os.getenv("DB_NAME"),
    "user" : os.getenv("DB_USER"),
    "password" : os.getenv("DB_PASSWORD")
}

# ตรวจสอบว่า .env ครบทุกค่าไหม
def check_config() :
    missing = [k for k,v in DB_CONFIG.items() if not v]
    if missing :
        raise ValueError(f"ไม่พบค่าใน .env : {missing}")
    log.info ("config ครบถ้วน")

# เชื่อมต่อ PostgreSQL ด้วย psycopg2
def get_connection() :
    try :
        conn = psycopg2.connect(**DB_CONFIG)
        log.info ("เชื่อมต่อ PostgreSQL สำเร็จ")
        return conn
    except Exception as e :
        log.error (f"เชื่อมต่อ PostgreSQL ไม่สำเร็จ : {e}")
        raise

#สร้าง SQLAlchemy Engine
def get_engine() :
    try:
        url = (
            f"postgresql://{DB_CONFIG["user"]}:{DB_CONFIG["password"]}"
            f"@{DB_CONFIG["host"]}:{DB_CONFIG["port"]}/{DB_CONFIG["dbname"]}"

        )
        engine = create_engine(url)
        log.info("สร้าง engine เชื่อมต่อ PostgreSQL สำเร็จ")
        return engine
    except Exception as e :
        log.error(f"สร้าง Engine เชื่อมต่อ ไม่ได้ : {e}")
        raise


