// internal/medicine/model.go
package medicine

import "time"

// ---------- Domain Enums ----------

type Form string

const (
	FormTablet   Form = "tablet"
	FormCapsule  Form = "capsule"
	FormSyrup    Form = "syrup"
	FormOintment Form = "ointment"
	FormSpray    Form = "spray"
	FormDrop     Form = "drop"
	FormOther    Form = "other"
)

type TxnType string

const (
	TxnIn     TxnType = "in"     // รับเข้า
	TxnOut    TxnType = "out"    // เบิก/ใช้
	TxnAdjust TxnType = "adjust" // ปรับยอดจากการตรวจนับ
)

// ---------- Core Entities ----------

// MedicineItem = ข้อมูลยาต่อ 1 รายการ (คงหน่วยที่ระดับ item)
type MedicineItem struct {
	ID          string    `json:"id"`
	HouseholdID string    `json:"household_id"`
	Name        string    `json:"name"`
	GenericName *string   `json:"generic_name,omitempty"`
	Form        Form      `json:"form"`
	Strength    *string   `json:"strength,omitempty"` // e.g. "500 mg", "5 mg/5 mL"
	Category    *string   `json:"category,omitempty"` // e.g. "painkiller", "antihistamine"
	Unit        string    `json:"unit"`               // e.g. "tablet", "ml", "g", "piece"
	LocationID  *string   `json:"location_id,omitempty"`
	GTIN        *string   `json:"gtin,omitempty"`          // บาร์โค้ด/รหัสสินค้า (optional)
	PhotoFileID *string   `json:"photo_file_id,omitempty"` // อ้างไฟล์รูป (ถ้าโมดูลไฟล์มี)
	Notes       *string   `json:"notes,omitempty"`
	IsArchived  bool      `json:"is_archived"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// MedicineBatch = ล็อตของยา (วันหมดอายุ/เลขล็อต/คงเหลือ)
type MedicineBatch struct {
	ID        string     `json:"id"`
	ItemID    string     `json:"item_id"`
	LotNo     *string    `json:"lot_no,omitempty"`
	Expiry    *time.Time `json:"expiry_date,omitempty"` // อนุญาตว่างได้ (ไม่มีวันหมดอายุ)
	Qty       float64    `json:"qty"`                   // รองรับทศนิยม (ของเหลว)
	Unit      string     `json:"unit"`                  // ควรตรงกับ Item.Unit
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
}

// MedicineTxn = ธุรกรรมขยับสต็อก (บันทึก audit)
type MedicineTxn struct {
	ID        string    `json:"id"`
	ItemID    string    `json:"item_id"`
	BatchID   *string   `json:"batch_id,omitempty"`
	ActorID   string    `json:"actor_user_id"`
	Type      TxnType   `json:"type"`       // in|out|adjust
	QtyChange float64   `json:"qty_change"` // ค่าบวก/ลบ (+in, -out, ±adjust)
	Reason    *string   `json:"reason,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

// MedicineLocation = ตำแหน่งเก็บยาในบ้าน (เช่น ตู้ยา, ห้องครัว)
type MedicineLocation struct {
	ID          string    `json:"id"`
	HouseholdID string    `json:"household_id"`
	Name        string    `json:"name"`
	Notes       *string   `json:"notes,omitempty"`
	IsActive    bool      `json:"is_active"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// MedicineAlert = ค่าการแจ้งเตือนต่อ item (ขั้นต่ำ/ใกล้หมดอายุ)
type MedicineAlert struct {
	ItemID           string    `json:"item_id"`
	MinQty           *float64  `json:"min_qty,omitempty"`            // เตือนเมื่อรวม < min
	ExpiryWindowDays *int      `json:"expiry_window_days,omitempty"` // เตือนก่อนหมดอายุ N วัน
	IsEnabled        bool      `json:"is_enabled"`
	UpdatedAt        time.Time `json:"updated_at"`
}

// ---------- Query Filters (List) ----------

type ListItemFilter struct {
	Query        string // ค้นชื่อ/คำสำคัญ
	Category     string
	Form         string
	LocationID   string
	OnlyLow      bool   // แสดงเฉพาะที่ใกล้หมด
	OnlyExpiring bool   // แสดงเฉพาะที่ใกล้หมดอายุ
	Sort         string // name|stock_asc|stock_desc|expiry_asc|expiry_desc
}

// ---------- Read Models (DTOs สำหรับตอบ API) ----------

// ItemSummary = สรุปรายการยา + stock รวม + วันหมดอายุที่ใกล้สุด + flags
type ItemSummary struct {
	Item       MedicineItem `json:"item"`
	TotalQty   float64      `json:"total_qty"`
	NextExpiry *time.Time   `json:"next_expiry,omitempty"`
	LowStock   bool         `json:"low_stock"` // true เมื่อต่ำกว่า alert.MinQty
	Expiring   bool         `json:"expiring"`  // true เมื่อถึงกรอบ ExpiryWindowDays
}

// ItemDetail = สำหรับหน้า detail รวม batches, summary, alert
type ItemDetail struct {
	Item       MedicineItem    `json:"item"`
	Batches    []MedicineBatch `json:"batches"`
	TotalQty   float64         `json:"total_qty"`
	NextExpiry *time.Time      `json:"next_expiry,omitempty"`
	Alert      *MedicineAlert  `json:"alert,omitempty"`
}
