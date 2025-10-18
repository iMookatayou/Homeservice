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
	ID        string    `json:"id"`
	Title     string    `json:"title"`
	Content   *string   `json:"content,omitempty"`
	Category  Category  `json:"category"`
	Pinned    bool      `json:"pinned"`
	CreatedBy string    `json:"created_by"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// payloads
type CreateNoteReq struct {
	Title    string   `json:"title"`
	Content  *string  `json:"content,omitempty"`
	Category Category `json:"category"`
	Pinned   bool     `json:"pinned"`
}

type UpdateNoteReq struct {
	Title    *string   `json:"title,omitempty"`
	Content  **string  `json:"content,omitempty"` // pointer-to-pointer = แยก null vs empty string
	Category *Category `json:"category,omitempty"`
	Pinned   *bool     `json:"pinned,omitempty"`
}
