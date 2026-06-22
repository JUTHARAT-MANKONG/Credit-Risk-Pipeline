#ดึง raw data เข้า database(postgresql)
# Password ดึงมาจากไฟล์ .env
#--------------------------------------

import pandas as pd
from sqlalchemy import create_engine
from dotenv import load_dotenv
import os
import logging
from datetime import datetime

# ตั้งค่า logging : บันทึกสิ่งที่โปรแกรมทำออกมาให้เห็น
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
log = logging.getLogger(__name__)

# โหลดค่าจากไฟล์ .env
load_dotenv()
DB_CONFIG = {
    "host" : os.getenv("DB_HOST"),
    "port" : os.getenv("DB_PORT"),
    "dbname" : os.getenv("DB_NAME"),
    "user" : os.getenv("DB_USER"),
    "password" : os.getenv("DB_PASSWORD")
}
# ตรวจสอบว่า .env ครบไหม เพื่อป้องกันปัญหา connect ไม่ได้เพราะลืมใส่ค่าใน .env
def check_config():
    missing = [k for k,v in DB_CONFIG.items() if not v]
    if missing :
        raise ValueError(f"ไม่พบค่าใน.env : {missing}")
    log.info("Config ครบถ้วน")
    

# สร้าง SQLAlchemy Engine
def get_engine():
    try :
        url = (
            f"postgresql://{DB_CONFIG['user']}:{DB_CONFIG['password']}"
            f"@{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['dbname']}"
        )
        engine = create_engine(url)
        log.info("สร้าง Engine เชื่อมต่อ PostgreSQL สำเร็จ")
        return engine
    except Exception as e:
        log.error(f"สร้าง Engine ไม่ได้ : {e}")
        raise

#โหลด CSV เข้า PostgreSQL
def load_csv(engine , filepath : str , schema : str , table : str) :
    log.info(f"อ่านไฟล์  {filepath}")

    df = pd.read_csv(filepath , dtype = str)
    df = df.fillna("")
    df.columns = [c.lower() for c in df.columns]

    df["_loaded_at"] = datetime.now().isoformat()
    df["_source_file"] = os.path.basename(filepath)

    total = len(df)
    log.info(f"จำนวนแถวทั้งหมด : {total : ,}")

    df.to_sql(
        name=table,
        con=engine,
        schema=schema,
        if_exists="replace",  
        index=False,
        chunksize=500 #insert ทีละ 500 แถว
    )
    log.info(f"โหลดเสร็จสิ้น {total : ,} แถว เข้า {schema}.{table}")
    return total

#ตรวจสอบจำนวนแถวหลัง load (เพื่อให้มั่นใจว่าข้อมูลถูกดึงไปครบ ไม่ตกหล่น)
def verify(engine,schema : str , table : str , expected : int) :
    query = f"SELECT COUNT(*) FROM {schema}.{table};"
    actual = pd.read_sql(query,engine).iloc[0,0]

    if actual == expected :
        log.info(f"Reconciliation ผ่าน: DB={actual:,} = CSV={expected:,}")
    else:
        raise ValueError(
            f"Reconciliation ล้มเหลว: DB={actual:,} ≠ CSV={expected:,}"
        )

# Main
def main():
    SOURCE_FILE = "data/raw/Financial_Ecosystem_Dataset_T1_5k_.csv"
    SCHEMA      = "raw"
    TABLE       = "financial_transactions"

    log.info("=" *50) 
    log.info("เริ่ม Raw Data Ingestion Pipeline")
    log.info(f" Source : {SOURCE_FILE}")
    log.info(f" Target : {SCHEMA}.{TABLE}")
    log.info("=" *50)

    try :
        check_config()  #ตรวจว่า .env ครบไหม
        engine = get_engine() #เชื่อมต่อ DB
        expected = load_csv(engine,SOURCE_FILE,SCHEMA,TABLE) #โหลด csv เข้า DB ได้ total แถว
        verify(engine,SCHEMA,TABLE,expected) #ตรวจว่า DB มีแถวตรงกับ CSV ไหม
        log.info("Pipeline สำเร็จ") #ถ้าทุกอย่างผ่านบันทึกว่าสำเร็จ

    except Exception as e :
        log.error(f"Pipeline ล้มเหลว : {e}")
        raise

if __name__== "__main__":
     main()