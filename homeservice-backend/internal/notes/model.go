package notes

import "time"

type Category string

const (
	CatBills       Category = "bills"
	CatChores      Category = "chores"
	CatAppointment Category = "appointment"
	CatGeneral     Category = "general"
)

type Note struct {
	ID    string `json:"id"`
	Title string `json:"title"`
	// DB column = body; API ใช้ชื่อ content
	Content *string `json:"content,omitempty"`

	// งาน/การจัดหมวด
	Category Category `json:"category"`
	Pinned   bool     `json:"pinned"`
	Priority int16    `json:"priority"` // 0=ปกติ, 1=สูง, ...

	// ผู้สร้าง/ผู้รับงาน (0007: อนุญาต NULL)
	CreatedBy  *string `json:"created_by,omitempty"`
	AssignedTo *string `json:"assigned_to,omitempty"`

	// เวลาเดดไลน์/เตือน/เสร็จสิ้น
	DueAt    *time.Time `json:"due_at,omitempty"`
	RemindAt *time.Time `json:"remind_at,omitempty"`
	DoneAt   *time.Time `json:"done_at,omitempty"`

	// อื่น ๆ จากสคีมาเดิม
	Tags     []string `json:"tags"`
	Link     *string  `json:"link,omitempty"`
	Location *string  `json:"location,omitempty"`

	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// payloads
type CreateNoteReq struct {
	Title    string   `json:"title"`
	Content  *string  `json:"content,omitempty"`
	Category Category `json:"category"`
	Pinned   bool     `json:"pinned"`

	// ถ้าต้องการสร้างงานพร้อมกำหนดรายละเอียด (optional)
	AssignedTo *string    `json:"assigned_to,omitempty"`
	DueAt      *time.Time `json:"due_at,omitempty"`
	Priority   *int16     `json:"priority,omitempty"`
	Location   *string    `json:"location,omitempty"`
	Tags       []string   `json:"tags,omitempty"`
	Link       *string    `json:"link,omitempty"`
}

type UpdateNoteReq struct {
	Title *string `json:"title,omitempty"`

	// ใช้ pointer-to-pointer แยก null vs empty string:
	//   - nil   = ไม่แก้ไข
	//   - &nil  = ตั้งค่าเป็น NULL
	//   - &""   = ตั้งค่าเป็นค่าว่าง
	Content **string `json:"content,omitempty"`

	Category *Category `json:"category,omitempty"`
	Pinned   *bool     `json:"pinned,omitempty"`

	// งาน (แก้เฉพาะฟิลด์ที่ส่งมา)
	AssignedTo *string    `json:"assigned_to,omitempty"`
	DueAt      *time.Time `json:"due_at,omitempty"`
	Priority   *int16     `json:"priority,omitempty"`
	Done       *bool      `json:"done,omitempty"` // true=mark done, false=undone (ให้ handler ตีความ)
	Location   *string    `json:"location,omitempty"`
	Tags       *[]string  `json:"tags,omitempty"`
	Link       **string   `json:"link,omitempty"` // เหมือน content: รองรับล้างเป็น NULL ได้
}
