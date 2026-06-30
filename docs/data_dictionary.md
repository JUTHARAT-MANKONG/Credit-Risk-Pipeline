# Data Dictionary

## Project: Credit Risk Regulatory Reporting Pipeline

| | |
|---|---|
| **Version** | 1.0 |
| **Author** | Jutharat Mankong |
| **Date** | 2026-06-15 |
| **Source File** | Financial_Ecosystem_Dataset_T1_5k_.csv |
| **Total Columns** | 50 |
| **Total Rows** | 5,000 |

---

## คำอธิบาย

Data Dictionary คือเอกสารที่อธิบายความหมายของทุก Column ในข้อมูล เปรียบเหมือนพจนานุกรมของ Dataset ใครก็ตามที่เปิดเอกสารนี้จะเข้าใจทันทีว่าแต่ละ Column เก็บข้อมูลอะไร มีค่าอะไรได้บ้าง และนำไปใช้ทำอะไรในระบบ

---

## หมวดที่ 1 — ข้อมูลลูกค้า (Customer Information)

ข้อมูลพื้นฐานของลูกค้าแต่ละราย ใช้สำหรับจำแนกกลุ่มลูกค้าและวิเคราะห์ความเสี่ยงตามโปรไฟล์

| Column | ประเภทข้อมูล | ความหมาย | ค่าที่เป็นไปได้ | ตัวอย่าง |
|---|---|---|---|---|
| **Cust_ID** | TEXT | รหัสลูกค้า ไม่ซ้ำกันในระบบ | CUST-XXXXXXXX | CUST-00000001 |
| **Cust_Age** | INTEGER | อายุของลูกค้า หน่วยเป็นปี | 22 ถึง 61 | 50 |
| **Cust_Gender** | TEXT | เพศของลูกค้า | M = ชาย, F = หญิง | M |
| **Cust_Marital_Status** | TEXT | สถานภาพสมรส | Single, Married, Divorced, Widowed | Single |
| **Cust_Dependents** | INTEGER | จำนวนผู้อยู่ในความดูแล เช่น บุตร | 0 ขึ้นไป | 0 |
| **Cust_Education** | TEXT | ระดับการศึกษาสูงสุด | High_School, Undergraduate, Postgraduate, Doctorate | Undergraduate |
| **Cust_Employment_Status** | TEXT | สถานะการจ้างงานปัจจุบัน | Employed, Self-Employed, Unemployed, Retired, Student | Employed |
| **Cust_Occupation_Sector** | TEXT | สาขาอาชีพหรืออุตสาหกรรมที่ทำงาน | Finance, Tech, Healthcare, Government, Retail, Construction, Retired, Student, Unemployed | Finance |
| **Cust_Annual_Income_USD** | DECIMAL | รายได้ต่อปีของลูกค้า หน่วยเป็น USD | 7,487.50 ถึง 110,998.28 | 41,397.17 |
| **Cust_Home_Ownership** | TEXT | สถานะที่อยู่อาศัยปัจจุบัน | Own_Outright = เจ้าของกรรมสิทธิ์, Own_Mortgage = ผ่อนบ้าน, Rent = เช่า, Live_With_Parents = อยู่กับพ่อแม่ | Own_Mortgage |

---

## หมวดที่ 2 — ข้อมูลบัญชี (Account Information)

ข้อมูลบัญชีธนาคารของลูกค้า ใช้สำหรับจำแนกประเภทบัญชีและตรวจสอบสถานะการใช้งาน

| Column | ประเภทข้อมูล | ความหมาย | ค่าที่เป็นไปได้ | ตัวอย่าง |
|---|---|---|---|---|
| **Account_ID** | TEXT | รหัสบัญชี ไม่ซ้ำกันในระบบ | ACCT-XXXXXXXXX | ACCT-000000001 |
| **Account_Type** | TEXT | ประเภทบัญชีธนาคาร | Checking = บัญชีกระแสรายวัน, Savings = บัญชีออมทรัพย์, Credit_Card = บัตรเครดิต, Money_Market = บัญชีตลาดเงิน | Credit_Card |
| **Account_Open_Date** | DATE | วันที่เปิดบัญชี รูปแบบ YYYY-MM-DD | - | 2014-01-15 |
| **Account_Status** | TEXT | สถานะปัจจุบันของบัญชี | Active = ใช้งานปกติ, Dormant = ไม่มีการเคลื่อนไหวนาน, Suspended = ถูกระงับการใช้งาน | Active |
| **Account_KYC_Tier** | TEXT | ระดับการยืนยันตัวตนของลูกค้า (Know Your Customer) | Tier_1_Basic = พื้นฐาน, Tier_2_Standard = มาตรฐาน, Tier_3_Premium = พรีเมียม | Tier_3_Premium |
| **Primary_Branch_Region** | TEXT | ภูมิภาคของสาขาธนาคารหลักที่ลูกค้าใช้บริการ | North, South, East, West, Central | North |
| **Total_Assets_Under_Management** | DECIMAL | มูลค่าสินทรัพย์รวมของลูกค้าที่ธนาคารดูแล หน่วยเป็น USD | 0 ขึ้นไป | 18,422.44 |
| **Has_Active_Credit_Card** | BOOLEAN | มีบัตรเครดิตที่ยังใช้งานอยู่หรือไม่ | True = มี, False = ไม่มี | True |
| **Has_Active_Loan** | BOOLEAN | มีสินเชื่อที่ยังผ่อนชำระอยู่หรือไม่ | True = มี, False = ไม่มี | False |
| **Digital_Banking_Enrollment** | BOOLEAN | สมัครใช้บริการธนาคารออนไลน์หรือไม่ | True = สมัครแล้ว, False = ยังไม่ได้สมัคร | True |

---

## หมวดที่ 3 — ข้อมูลธุรกรรม (Transaction Information)

รายละเอียดของการทำธุรกรรมแต่ละครั้ง ใช้สำหรับวิเคราะห์พฤติกรรมการใช้เงินและตรวจจับความผิดปกติ

| Column | ประเภทข้อมูล | ความหมาย | ค่าที่เป็นไปได้ | ตัวอย่าง |
|---|---|---|---|---|
| **Txn_ID** | TEXT | รหัสธุรกรรม ไม่ซ้ำกันในระบบ | TXN-XXXXXXXXXX | TXN-0000000001 |
| **Txn_Timestamp** | TIMESTAMP | วันและเวลาที่ทำธุรกรรม รูปแบบ YYYY-MM-DD HH:MM:SS | - | 2024-09-16 19:56:16 |
| **Txn_Type** | TEXT | ประเภทของธุรกรรม | ACH_Debit = หักบัญชีอัตโนมัติ, ATM_Withdrawal = ถอนเงินสด, Cash_Deposit = ฝากเงินสด, Online_Shopping = ซื้อสินค้าออนไลน์, POS_Purchase = ชำระเงินที่ร้านค้า, Wire_Transfer = โอนเงินระหว่างธนาคาร, Crypto_Exchange_Purchase = ซื้อสกุลเงินดิจิทัล | ACH_Debit |
| **Txn_Channel** | TEXT | ช่องทางที่ใช้ทำธุรกรรม | Mobile_App = แอปมือถือ, Web_Portal = เว็บไซต์, Branch_ATM = ตู้ ATM สาขา, In_Person_Branch = เคาน์เตอร์สาขา | Mobile_App |
| **Txn_Amount_USD** | DECIMAL | จำนวนเงินในธุรกรรม หน่วยเป็น USD | 1.02 ถึง 2,947,518.44 | 16,369.01 |
| **Txn_Currency** | TEXT | สกุลเงินที่ใช้ในธุรกรรม | USD = ดอลลาร์สหรัฐ, EUR = ยูโร, GBP = ปอนด์อังกฤษ, Local = สกุลเงินท้องถิ่น | USD |
| **Counterparty_ID** | TEXT | รหัสของคู่ธุรกรรม (ผู้รับหรือผู้โอน) | CP-XXXXXXXXX | CP-002645610 |
| **Counterparty_Type** | TEXT | ประเภทของคู่ธุรกรรม | Individual = บุคคลธรรมดา, Small_Business = ธุรกิจขนาดเล็ก, Mega_Corporation = บริษัทขนาดใหญ่, Offshore_Entity = นิติบุคคลต่างประเทศ, High_Risk_Exchange = ตลาดแลกเปลี่ยนที่มีความเสี่ยงสูง | Individual |
| **Merchant_Category_Code_MCC** | INTEGER | รหัสประเภทร้านค้าตามมาตรฐานสากล เช่น 7995 = การพนัน | รหัสตัวเลข 4 หลัก | 7995 |
| **Txn_Response_Code** | TEXT | ผลลัพธ์ของธุรกรรม | Approved = อนุมัติ, Insufficient_Funds = ยอดเงินไม่พอ, Suspected_Fraud_Block = บล็อกเพราะสงสัยว่าเป็นการฉ้อโกง, System_Timeout = ระบบหมดเวลา | Approved |

---

## หมวดที่ 4 — ข้อมูลยอดคงเหลือ (Balance Information)

ยอดเงินก่อนและหลังการทำธุรกรรม ใช้สำหรับคำนวณ Outstanding Balance และ Provision Amount

| Column | ประเภทข้อมูล | ความหมาย | หมายเหตุ | ตัวอย่าง |
|---|---|---|---|---|
| **Orig_Balance_Before** | DECIMAL | ยอดเงินในบัญชีผู้โอน ก่อนทำธุรกรรม หน่วยเป็น USD | อาจติดลบหากมี Overdraft | 6,175.59 |
| **Orig_Balance_After** | DECIMAL | ยอดเงินในบัญชีผู้โอน หลังทำธุรกรรม หน่วยเป็น USD | **ใช้เป็น Outstanding Balance ในการคำนวณ** | -10,193.42 |
| **Dest_Balance_Before** | DECIMAL | ยอดเงินในบัญชีผู้รับ ก่อนทำธุรกรรม หน่วยเป็น USD | - | 35,282.83 |
| **Dest_Balance_After** | DECIMAL | ยอดเงินในบัญชีผู้รับ หลังทำธุรกรรม หน่วยเป็น USD | - | 51,651.84 |
| **Monthly_Avg_Inflow** | DECIMAL | ยอดเงินที่รับเข้าบัญชีเฉลี่ยต่อเดือน หน่วยเป็น USD | - | 2,658.43 |
| **Monthly_Avg_Outflow** | DECIMAL | ยอดเงินที่จ่ายออกจากบัญชีเฉลี่ยต่อเดือน หน่วยเป็น USD | - | 2,095.62 |
| **Overdraft_Limit_USD** | DECIMAL | วงเงินเบิกเกินบัญชีที่ได้รับอนุมัติ หน่วยเป็น USD | - | 7,069.86 |
| **Days_In_Overdraft_L12M** | INTEGER | จำนวนวันที่บัญชีติดลบในช่วง 12 เดือนที่ผ่านมา | 0 = ไม่เคยติดลบเลย | 0 |

---

## หมวดที่ 5 — ข้อมูลความเสี่ยง (Risk Information)

ข้อมูลที่ใช้ประเมินความเสี่ยงของลูกค้า ใช้สำหรับคำนวณ Loan Status และ Provision Amount

| Column | ประเภทข้อมูล | ความหมาย | ค่าที่เป็นไปได้ | ตัวอย่าง |
|---|---|---|---|---|
| **Credit_Card_Utilization_Rate** | DECIMAL | สัดส่วนการใช้วงเงินบัตรเครดิตต่อวงเงินทั้งหมด | 0.00 ถึง 1.00 โดย 1.00 = ใช้เต็มวงเงิน | 0.40 |
| **Delinquency_Status** | TEXT | สถานะการค้างชำระหนี้ **ใช้เป็น input หลักในการคำนวณ Loan Status** | Current = ชำระปกติ (M0), 30_Days_Past_Due = ค้าง 30 วัน (M1), 60_Days_Past_Due = ค้าง 60 วัน (M2), 90_Plus_Days_Past_Due = ค้างเกิน 90 วัน (M3 และ M4+) | Current |
| **Risk_Score_Internal** | INTEGER | คะแนนความเสี่ยงที่ธนาคารประเมินเอง ยิ่งสูงยิ่งดี | 494 ถึง 796 | 728 |
| **Bureau_Credit_Score** | INTEGER | คะแนนเครดิตจากบริษัทข้อมูลเครดิตภายนอก เช่น NCB | 519 ถึง 784 | 723 |

---

## หมวดที่ 6 — ข้อมูลดิจิทัลและการฉ้อโกง (Digital and Fraud Signals)

ข้อมูลพฤติกรรมดิจิทัลของลูกค้า ใช้สำหรับตรวจจับความผิดปกติและการฉ้อโกง

| Column | ประเภทข้อมูล | ความหมาย | ค่าที่เป็นไปได้ | ตัวอย่าง |
|---|---|---|---|---|
| **Device_Type** | TEXT | ประเภทอุปกรณ์ที่ใช้ทำธุรกรรม | iOS, Android, Windows, MacOS, Linux | iOS |
| **Device_IP_Country** | TEXT | รหัสประเทศของ IP Address ที่ใช้ทำธุรกรรม | รหัสประเทศ 2 ตัวอักษร เช่น US, TH, CN, RU | US |
| **Is_VPN_Used** | BOOLEAN | มีการใช้ VPN ในการทำธุรกรรมหรือไม่ | True = ใช้ VPN, False = ไม่ใช้ | False |
| **Login_Attempts_Fail_Count** | INTEGER | จำนวนครั้งที่ Login ผิดพลาดก่อนทำธุรกรรมสำเร็จ | 0 ถึง 3 | 0 |
| **Txn_Velocity_1H** | INTEGER | จำนวนธุรกรรมที่ทำภายใน 1 ชั่วโมงก่อนธุรกรรมนี้ | 0 ถึง 7 | 2 |
| **Behavioral_Anomaly_Flag** | BOOLEAN | ระบบตรวจพบพฤติกรรมผิดปกติหรือไม่ | True = ผิดปกติ, False = ปกติ | False |

---

## หมวดที่ 7 — ป้ายกำกับผลลัพธ์ (Target Labels)

ผลลัพธ์ที่ใช้วัดความถูกต้องของการประเมินความเสี่ยง ใช้สำหรับสร้าง KPI หลักของระบบ

| Column | ประเภทข้อมูล | ความหมาย | ค่าที่เป็นไปได้ | ตัวอย่าง |
|---|---|---|---|---|
| **Target_Credit_Default** | BOOLEAN | ลูกค้าผิดนัดชำระหนี้จริงหรือไม่ ใช้ร่วมกับ Delinquency_Status ในการระบุ NPL | True = ผิดนัด, False = ไม่ผิดนัด | False |
| **Target_Is_Fraud_AML** | BOOLEAN | ธุรกรรมนี้เป็นการฉ้อโกงหรือเข้าข่าย AML หรือไม่ | True = เป็นการฉ้อโกง, False = ปกติ | False |

---

## หมายเหตุสำคัญ

> **Delinquency_Status ใน Dataset นี้ใช้คำแตกต่างจาก BRD** ต้องแปลงค่าใน Bronze Layer ดังนี้

| ค่าใน Dataset | ค่าที่ใช้ใน BRD | ความหมาย |
|---|---|---|
| Current | M0 | ชำระปกติ |
| 30_Days_Past_Due | M1 | ค้างชำระ 30 วัน |
| 60_Days_Past_Due | M2 | ค้างชำระ 60 วัน |
| 90_Plus_Days_Past_Due | M3 หรือ M4+ | ค้างชำระ 90 วันขึ้นไป |

> ถ้า 90_Plus_Days_Past_Due และ Target_Credit_Default = True ให้จัดเป็น M4+ (NPL) ทันที
EOF