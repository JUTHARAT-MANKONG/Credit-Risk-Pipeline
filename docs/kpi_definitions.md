# KPI Definitions

## Project: Credit Risk Regulatory Reporting Pipeline

| | |
|---|---|
| **Version** | 1.0 |
| **Author** | Jutharat Mankong |
| **Date** | 2026-06-15 |
| **อ้างอิง** | Basel III, BoT Regulatory Guidelines |

---

## คำอธิบาย

KPI Definition คือเอกสารที่อธิบายวิธีคำนวณตัวชี้วัดแต่ละตัวอย่างละเอียด ใครก็ตามที่เปิดเอกสารนี้จะสามารถเขียน SQL หรือ Python เพื่อคำนวณได้ทันทีโดยไม่ต้องเดา

---

## KPI ที่ 1 — Outstanding Balance (ยอดหนี้คงเหลือรวม)

### ความหมาย

ยอดหนี้คงเหลือรวมทั้งหมดในระบบ ณ วันที่รายงาน แสดงให้เห็นว่าธนาคารมีลูกหนี้รวมกันเป็นมูลค่าเท่าไหร่ในเดือนนั้น

### สูตรคำนวณ

```
Outstanding_Balance_THB = SUM(Orig_Balance_After x FX_Rate_THB)

เงื่อนไข:
- นับเฉพาะแถวที่ Orig_Balance_After มีค่ามากกว่า 0
- แปลงสกุลเงินเป็น THB ก่อนรวมยอดเสมอ
- ใช้ FX Rate ณ วันสุดท้ายของเดือนที่รายงาน
```

### ตัวอย่างการคำนวณ

```
ลูกหนี้ A  ยอดคงเหลือ  1,000 USD x 35.25 =  35,250 THB
ลูกหนี้ B  ยอดคงเหลือ    500 EUR x 38.10 =  19,050 THB
ลูกหนี้ C  ยอดคงเหลือ 50,000 Local x 1.00 = 50,000 THB

Outstanding_Balance_THB = 35,250 + 19,050 + 50,000 = 104,300 THB
```

### Column ที่ใช้

| Column | มาจาก Table | หน้าที่ |
|---|---|---|
| Orig_Balance_After | silver.loan_accounts | ยอดหนี้คงเหลือก่อนแปลงสกุลเงิน |
| FX_Rate_THB | silver.fx_rate | อัตราแลกเปลี่ยนเป็น THB |
| Txn_Currency | silver.loan_accounts | สกุลเงินที่ต้องแปลง |

### เงื่อนไขสำคัญ

| เงื่อนไข | รายละเอียด |
|---|---|
| **กรองข้อมูล** | Orig_Balance_After > 0 เท่านั้น ยอดติดลบคือ Overdraft ไม่นับเป็นหนี้ |
| **สกุลเงิน** | แปลงทุกสกุลเป็น THB ก่อนรวม |
| **วันที่** | ใช้ข้อมูล ณ วันสุดท้ายของเดือน (Month-End Snapshot) |

### เป้าหมาย

ใช้สำหรับติดตามขนาดพอร์ตสินเชื่อรวม ไม่มีค่า Threshold กำหนด แต่ต้องรายงานให้ BoT ทุกเดือน

---

## KPI ที่ 2 — NPL Ratio (อัตราส่วนหนี้เสีย)

### ความหมาย

สัดส่วนของลูกหนี้ที่เป็นหนี้เสีย (NPL) เทียบกับลูกหนี้ทั้งหมด บอกว่ามีลูกหนี้กี่เปอร์เซ็นต์ที่ไม่ชำระหนี้แล้ว ยิ่งสูงยิ่งแย่

### สูตรคำนวณ

```
NPL_Ratio (%) = COUNT(แถวที่เป็น NPL) / COUNT(ทั้งหมด) x 100

เงื่อนไขการนับว่าเป็น NPL:
- Delinquency_Status = '90_Plus_Days_Past_Due'  หรือ
- Target_Credit_Default = True
```

### ตัวอย่างการคำนวณ

```
ลูกหนี้ทั้งหมดในระบบ          = 5,000 ราย
ลูกหนี้ที่เป็น NPL              =   350 ราย

NPL_Ratio = 350 / 5,000 x 100 = 7.00%
```

### Column ที่ใช้

| Column | มาจาก Table | หน้าที่ |
|---|---|---|
| Delinquency_Status | silver.loan_accounts | ตรวจสอบว่าค้างชำระเกิน 90 วันหรือไม่ |
| Target_Credit_Default | silver.loan_accounts | ตรวจสอบว่าผิดนัดชำระแล้วหรือไม่ |

### เงื่อนไขสำคัญ

| เงื่อนไข | รายละเอียด |
|---|---|
| **นิยาม NPL** | ค้างชำระเกิน 90 วัน หรือ Target_Credit_Default = True อย่างใดอย่างหนึ่ง |
| **ฐานการคำนวณ** | นับทุกบัญชีที่ Active ในเดือนนั้น |
| **ไม่รวม** | บัญชีที่ถูก Write-off ออกไปแล้ว |

### เป้าหมายและการแจ้งเตือน

| ระดับ | NPL Ratio | การดำเนินการ |
|---|---|---|
| **ปกติ** | ต่ำกว่า 3% | รายงานตามปกติ |
| **ต้องเฝ้าระวัง** | 3% ถึง 5% | แจ้งเตือนทีม Risk Management |
| **วิกฤต** | สูงกว่า 5% | รายงานฉุกเฉินถึงผู้บริหารและ BoT |

---

## KPI ที่ 3 — Total Provision Amount (เงินสำรองรวม)

### ความหมาย

จำนวนเงินสำรองรวมที่ธนาคารต้องกันไว้ตามกฎของ BoT และมาตรฐาน Basel III เพื่อรองรับความเสี่ยงที่ลูกหนี้จะไม่ชำระหนี้คืน

### สูตรคำนวณ

```
Total_Provision_THB = SUM(Amount_THB x Provision_Rate)

โดย Provision_Rate กำหนดตาม Loan Status ดังนี้:
- Performing    (Current)              = 1%
- Under-Performing (30_Days_Past_Due)  = 2%
- Under-Performing (60_Days_Past_Due)  = 10%
- Under-Performing (90_Plus_Past_Due)  = 50%
- NPL          (Default หรือ M4+)      = 100%
```

### ตัวอย่างการคำนวณ

```
ลูกหนี้ A  ยอดหนี้ 35,250 THB  สถานะ Current        x  1% =    352.50 THB
ลูกหนี้ B  ยอดหนี้ 19,050 THB  สถานะ 30_Days_Due    x  2% =    381.00 THB
ลูกหนี้ C  ยอดหนี้ 50,000 THB  สถานะ 60_Days_Due    x 10% =  5,000.00 THB
ลูกหนี้ D  ยอดหนี้ 80,000 THB  สถานะ NPL            x100% = 80,000.00 THB

Total_Provision_THB = 352.50 + 381.00 + 5,000 + 80,000 = 85,733.50 THB
```

### Column ที่ใช้

| Column | มาจาก Table | หน้าที่ |
|---|---|---|
| Orig_Balance_After | silver.loan_accounts | ยอดหนี้ก่อนแปลงสกุลเงิน |
| FX_Rate_THB | silver.fx_rate | อัตราแลกเปลี่ยนเป็น THB |
| Delinquency_Status | silver.loan_accounts | กำหนด Provision Rate |
| Target_Credit_Default | silver.loan_accounts | ระบุ NPL ร่วมกับ Delinquency_Status |
| Loan_Status | silver.loan_accounts | ผลลัพธ์หลังจำแนกประเภทแล้ว |

### เงื่อนไขสำคัญ

| เงื่อนไข | รายละเอียด |
|---|---|
| **ลำดับการคำนวณ** | แปลงเป็น THB ก่อน แล้วค่อยคูณ Provision Rate |
| **กรณี NPL** | ใช้ Provision Rate 100% เสมอ ไม่ว่ายอดหนี้จะเป็นเท่าไหร่ |
| **สกุลเงิน** | ผลลัพธ์ทั้งหมดต้องเป็น THB เท่านั้น |

### เป้าหมาย

ใช้สำหรับรายงาน Capital Adequacy ให้ BoT ทุกเดือน ไม่มีค่า Threshold แต่ต้องคำนวณและรายงานให้ถูกต้อง 100%

---

## สรุป KPI ทั้งหมด

| KPI | สูตรย่อ | หน่วย | รายงานให้ |
|---|---|---|---|
| **Outstanding Balance** | SUM(ยอดหนี้ x FX Rate) | THB | BoT รายเดือน |
| **NPL Ratio** | COUNT(NPL) / COUNT(ทั้งหมด) x 100 | % | BoT รายเดือน |
| **Total Provision Amount** | SUM(ยอดหนี้ THB x Provision Rate) | THB | BoT รายเดือน |

---

## ลำดับการคำนวณที่ถูกต้อง

ทุกครั้งที่รันระบบต้องทำตามลำดับนี้เสมอ เพราะ KPI แต่ละตัวขึ้นอยู่กับผลลัพธ์ของขั้นก่อนหน้า

```
ขั้นที่ 1 → โหลด FX Rate ของเดือนนั้นเข้าระบบก่อน
              ถ้าไม่มี FX Rate ให้หยุดทำงานทันที

ขั้นที่ 2 → แปลงยอดหนี้ทุกรายการเป็น THB

ขั้นที่ 3 → จำแนก Loan Status ของลูกหนี้แต่ละราย

ขั้นที่ 4 → กำหนด Provision Rate ตาม Loan Status

ขั้นที่ 5 → คำนวณ KPI ทั้ง 3 ตัว

ขั้นที่ 6 → ตรวจสอบความถูกต้องก่อน Export รายงาน
```
EOF