package notes

import "time"

type Category string

const (
	CatGeneral     Category = "general"
	CatBills       Category = "bills"
	CatChores      Category = "chores"
	CatAppointment Category = "appointment"
)

type Note struct {
	ID        string     `json:"id"`
	UserID    string     `json:"user_id"`
	Title     string     `json:"title"`
	Content   *string    `json:"content,omitempty"`
	Category  Category   `json:"category"`
	Pinned    bool       `json:"pinned"`
	Priority  int16      `json:"priority"`
	DueAt     *time.Time `json:"due_at,omitempty"`
	DoneAt    *time.Time `json:"done_at,omitempty"`
	Tags      []string   `json:"tags"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
}

type CreateNotePayload struct {
	Title    string     `json:"title"`
	Content  *string    `json:"content,omitempty"`
	Category Category   `json:"category"`
	Pinned   bool       `json:"pinned"`
	Priority int16      `json:"priority"`
	DueAt    *time.Time `json:"due_at,omitempty"`
	Tags     []string   `json:"tags"`
}

type UpdateNotePayload struct {
	Title    *string    `json:"title,omitempty"`
	Content  *string    `json:"content,omitempty"`
	Category *Category  `json:"category,omitempty"`
	Pinned   *bool      `json:"pinned,omitempty"`
	Priority *int16     `json:"priority,omitempty"`
	DueAt    *time.Time `json:"due_at,omitempty"`
	Tags     *[]string  `json:"tags,omitempty"`
}

type ListFilter struct {
	Query    string
	Category *Category
	Pinned   *bool
	Done     *bool
	Limit    int
	Offset   int
}