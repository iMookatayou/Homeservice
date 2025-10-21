package bills

import "time"

type Bill struct {
	ID                 string     `json:"id"`
	Type               string     `json:"type"` // bill_type enum: electric|water|internet
	Title              string     `json:"title"`
	Amount             float64    `json:"amount"`
	BillingPeriodStart *time.Time `json:"billing_period_start,omitempty"`
	BillingPeriodEnd   *time.Time `json:"billing_period_end,omitempty"`
	DueDate            *time.Time `json:"due_date,omitempty"`
	Status             string     `json:"status"` // bill_status enum: unpaid|paid|overdue
	PaidAt             *time.Time `json:"paid_at,omitempty"`
	Note               *string    `json:"note,omitempty"`
	CreatedBy          string     `json:"created_by"`
	CreatedAt          time.Time  `json:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at"`
}

type CreateBillReq struct {
	Type        string  `json:"type" validate:"required,oneof=electric water internet"`
	Title       string  `json:"title" validate:"required,min=1"`
	Amount      float64 `json:"amount" validate:"required,gt=0"`
	DueDate     *string `json:"due_date,omitempty"` // RFC3339 or YYYY-MM-DD
	Note        *string `json:"note,omitempty"`
	PeriodStart *string `json:"billing_period_start,omitempty"`
	PeriodEnd   *string `json:"billing_period_end,omitempty"`
}
