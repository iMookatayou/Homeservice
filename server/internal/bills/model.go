package bills

import (
	"errors"
	"time"

	"github.com/google/uuid"
)

var ErrNotFound = errors.New("not found")

type Bill struct {
	ID        uuid.UUID  `json:"id"`
	Type      string     `json:"type"`
	Title     string     `json:"title"`
	Amount    float64    `json:"amount"`
	DueDate   time.Time  `json:"due_date"`
	Status    string     `json:"status"`
	PaidAt    *time.Time `json:"paid_at,omitempty"`
	Note      *string    `json:"note,omitempty"`
	CreatedBy uuid.UUID  `json:"created_by"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
}

type Summary struct {
	Type        string  `json:"type"`
	TotalAmount float64 `json:"total_amount"`
	TotalPaid   float64 `json:"total_paid"`
	TotalUnpaid float64 `json:"total_unpaid"`
	Count       int     `json:"count"`
}

type CreateBillPayload struct {
	Type    string     `json:"type"`
	Title   string     `json:"title"`
	Amount  float64    `json:"amount"`
	DueDate time.Time  `json:"due_date"`
	Status  string     `json:"status"`
	Note    *string    `json:"note,omitempty"`
}

type UpdateBillPayload struct {
	Type    *string    `json:"type,omitempty"`
	Title   *string    `json:"title,omitempty"`
	Amount  *float64   `json:"amount,omitempty"`
	DueDate *time.Time `json:"due_date,omitempty"`
	Status  *string    `json:"status,omitempty"`
	Note    *string    `json:"note,omitempty"`
}