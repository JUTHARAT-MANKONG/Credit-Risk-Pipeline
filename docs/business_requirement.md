# Business Requirements Document (BRD)
## Project: Credit Risk Regulatory Reporting Pipeline

| **Version** | 1.0 |
| **Author** | Jutharat Mankong |
| **Date** | 2026-06-15 |
| **Status** | Draft |

---

## 1. Project Overview

ระบบนี้ออกแบบมาเพื่อรับข้อมูล Transaction และข้อมูลความเสี่ยงของลูกค้าจากระบบธนาคารหลัก (Core Banking System) แล้วนำมาประมวลผลและจัดรูปแบบให้ถูกต้อง เพื่อสร้างรายงานความเสี่ยงด้านสินเชื่อ (Credit Risk Regulatory Report) ส่งให้ธนาคารแห่งประเทศไทย (BoT) ตามมาตรฐานสากล Basel III

Basel III คือกฎที่ธนาคารทั่วโลกต้องปฏิบัติตาม โดยกำหนดว่าธนาคารต้องกันเงินสำรองไว้ตามระดับความเสี่ยงของลูกหนี้แต่ละราย เพื่อป้องกันไม่ให้ธนาคารล้มละลายในกรณีที่ลูกหนี้ไม่ชำระหนี้คืน

---

## 2. Data Source

| Item | Detail |
|---|---|
| Source System | Core Banking System (CBS) |
| Source File | Financial_Ecosystem_Dataset_T1_5k_.csv |
| Total Records | 5,000 rows |
| Reporting Grain | Account Level (รายบัญชี) |
| Reporting Frequency | Monthly (รายเดือน) |
| Report Reference Date | Month-End (วันสุดท้ายของเดือน) |
| Load Type | Full Load |

---

## 3. Key Performance Indicators (KPIs)

| KPI | Definition | Formula | Source Columns |
|---|---|---|---|
| Outstanding Balance | ยอดหนี้คงเหลือรวมในระบบ | SUM(orig_balance_after) | `orig_balance_after` |
| NPL Ratio (%) | อัตราส่วนหนี้เสียต่อสินเชื่อรวม | COUNT(NPL) / COUNT(*) × 100 | `delinquency_status`, `target_credit_default` |
| Total Provision Amount | เงินสำรองรวมที่ธนาคารต้องถือครอง | SUM(orig_balance_after × Provision Rate) | `orig_balance_after`, `delinquency_status` |

---

## 4. Business Rules

Business Rules คือกฎที่ใช้แปลงข้อมูลดิบให้กลายเป็นข้อมูลที่มีความหมายทางธุรกิจ

### 4.1 Loan Status Classification (การจำแนกประเภทลูกหนี้)

| Loan Status | Condition | Description |
|---|---|---|
| Performing | Delinquency_Status = 'M0' | ลูกหนี้ปกติ ชำระตรงเวลา |
| Under-Performing | Delinquency_Status IN ('M1','M2','M3') | ลูกหนี้เริ่มมีปัญหา |
| NPL | Delinquency_Status = 'M4+' OR Target_Credit_Default = 1 | หนี้เสีย ค้างชำระเกิน 3 เดือน หรือผิดนัดชำระแล้ว |

### 4.2 Provision Rate (ตามมาตรฐาน BoT / Basel III)

| Loan Status | Delinquency_Status | Provision Rate |
|---|---|---|
| Performing | M0 | 1% |
| Under-Performing | M1 | 2% |
| Under-Performing | M2 | 10% |
| Under-Performing | M3 | 50% |
| NPL | M4+ หรือ Default = 1 | 100% |

### 4.3 Provision Calculation

Provision_Amount = orig_balance_after × Provision_Rate

---

## 5. Assumptions & Constraints
Assumptions คือสิ่งที่เราสมมติว่าเป็นจริงสำหรับโปรเจกต์นี้ เนื่องจากข้อมูลที่มีไม่ครบ 100%

- 1 row ใน dataset = 1 transaction record ของ 1 account
- ใช้ `orig_balance_after` แทน Outstanding Balance
- Provision Rate ใช้ตาม BoT standard guidelines
- ไม่มีข้อมูล Write-off ใน dataset นี้
- exchange rate: ใช้ USD ตาม dataset (ไม่แปลงสกุลเงิน)

---

## 6. Out of Scope

- การคำนวณ Capital Adequacy Ratio (CAR)
- Stress Testing
- FX Conversion