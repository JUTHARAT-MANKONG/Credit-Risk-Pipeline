/*
============================================================
 5_create_audit_table.sql
 สร้าง Table บันทึกประวัติการรัน Pipeline
 เก็บไว้ใน Schema gold เพราะเป็นข้อมูลสรุประดับสูงสุด
============================================================
*/

CREATE TABLE IF NOT EXISTS gold.pipeline_run_log (

    -- Key
    run_id          SERIAL PRIMARY KEY,    -- เลขรันอัตโนมัติ 1, 2, 3, ...

    -- ข้อมูลการรัน
    pipeline_name   TEXT NOT NULL,         -- ชื่อ pipeline เช่น "full_pipeline"
    step_name       TEXT NOT NULL,         -- ชื่อ step เช่น "bronze_transform"
    status          TEXT NOT NULL,         -- SUCCESS หรือ FAILED

    -- เวลา
    started_at      TIMESTAMP NOT NULL,    -- เวลาเริ่มต้น step นี้
    finished_at     TIMESTAMP,             -- เวลาจบ (NULL ถ้ายังไม่จบ)
    duration_sec    NUMERIC(10,2),         -- ใช้เวลากี่วินาที

    -- ข้อมูลเพิ่มเติม
    rows_processed  INTEGER,               -- ประมวลผลกี่แถว (ถ้ามี)
    error_message   TEXT,                  -- ข้อความ error (ถ้าพัง)
    run_date        DATE DEFAULT CURRENT_DATE  -- วันที่รัน ใช้ filter ง่าย

);

COMMENT ON TABLE gold.pipeline_run_log IS
    'Audit log บันทึกทุกครั้งที่ Pipeline รัน
     ใช้สำหรับ Production Monitoring และตอบคำถาม BoT';

COMMENT ON COLUMN gold.pipeline_run_log.status IS
    'SUCCESS = สำเร็จ | FAILED = ล้มเหลว | RUNNING = กำลังรันอยู่';