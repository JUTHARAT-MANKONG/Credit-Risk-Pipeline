# ตั้งค่า logging สำหรับใช้ซ้ำในทุกไฟล์

import logging

def get_logger(name : str) -> logging.Logger :   # -> คือเครื่องหมายคืนค่า
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s"
    )
    return logging.getLogger(name)
