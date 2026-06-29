#ดึง raw data เข้า database(postgresql)
#--------------------------------------

import pandas as pd
import sys
import os
from datetime import datetime

# ระบุ directory ของ push_data_to_pgsql.py
current_dir = os.path.dirname(os.path.abspath(__file__))

# ถอย directory กลับไปที่ src
src_dir = os.path.abspath(os.path.join(current_dir, ".."))

# หาก syspath ไม่ตรงกับ src_dir ให้เอา src_dir เข้าไปแทนที่ โดย Python จะใช้ syspath เป็นจุดค้นหา module หรือ library ต่าง ๆ 
if src_dir not in sys.path:
    sys.path.insert(0, src_dir)

from common.logger import get_logger
from common.db_connection import check_config,get_engine

# ตั้งค่า logging : บันทึกสิ่งที่โปรแกรมทำออกมาให้เห็น
log = get_logger(__name__)

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