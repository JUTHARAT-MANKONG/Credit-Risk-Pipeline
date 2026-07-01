/*
============================================================
create_raw_fx_rate_table.sql
สร้าง Table ใน Schema raw
ทุก column เป็น text
============================================================
*/

CREATE TABLE IF NOT EXISTS fx_rate(
    rate_month    TEXT,
    currency_code TEXT,
    rate_to_thb   TEXT,
    source        TEXT,

    -- Metadata
    _load_at      TIMESTAMP DEFAULT NOW(),
    _source_file  TEXT
);

COMMENT ON TABLE raw.fx_rate IS
'Raw landing table - BOT Reference Rate รายเดือน โหลดจาก CSV ดิบ';