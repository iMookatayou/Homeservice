package chores

import "time"

type Chore struct {
	ID          string     `json:"id"`
	Title       string     `json:"title"`
	Category    string     `json:"category"` // chore_category: general|kitchen|bathroom|outdoor
	Status      string     `json:"status"`   // chore_status: open|claimed|completed
	ClaimedBy   *string    `json:"claimed_by,omitempty"`
	ClaimedAt   *time.Time `json:"claimed_at,omitempty"`
	CompletedBy *string    `json:"completed_by,omitempty"`
	CompletedAt *time.Time `json:"completed_at,omitempty"`
	Note        *string    `json:"note,omitempty"`
	CreatedBy   string     `json:"created_by"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
}

type CreateChoreReq struct {
	Title    string  `json:"title" validate:"required,min=1"`
	Category string  `json:"category" validate:"required,oneof=general kitchen bathroom outdoor"`
	Note     *string `json:"note,omitempty"`
}
