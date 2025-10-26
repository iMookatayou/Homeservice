package bills

import (
	"time"

	"github.com/google/uuid"
)

type Bill struct {
	ID                 uuid.UUID  `json:"id"`
	Type               string     `json:"type"`
	Title              string     `json:"title"`
	Amount             float64    `json:"amount"`
	BillingPeriodStart *time.Time `json:"billing_period_start,omitempty"`
	BillingPeriodEnd   *time.Time `json:"billing_period_end,omitempty"`
	DueDate            time.Time  `json:"due_date"`
	Status             string     `json:"status"`
	PaidAt             *time.Time `json:"paid_at,omitempty"`
	Note               *string    `json:"note,omitempty"`
	CreatedBy          uuid.UUID  `json:"created_by"`
	CreatedAt          time.Time  `json:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at"`
}

type Summary struct {
	Type        string  `json:"type"`
	TotalAmount float64 `json:"total_amount"`
	TotalPaid   float64 `json:"total_paid"`
	TotalUnpaid float64 `json:"total_unpaid"`
	Count       int     `json:"count"`
}
