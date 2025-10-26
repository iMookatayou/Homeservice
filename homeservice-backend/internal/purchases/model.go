package purchases

import (
	"encoding/json"
	"time"
)

// ENUMs
type Status string

const (
	StatusPlanned   Status = "planned"
	StatusOrdered   Status = "ordered"
	StatusBought    Status = "bought"
	StatusDelivered Status = "delivered"
	StatusCancelled Status = "cancelled"
)

type Item struct {
	Name      string  `json:"name"`
	Qty       float64 `json:"qty"`
	Unit      string  `json:"unit,omitempty"`
	Brand     string  `json:"brand,omitempty"`
	Note      string  `json:"note,omitempty"`
	UnitPrice float64 `json:"unit_price,omitempty"`
}

// JSONB helper (ถ้าใช้อยู่แล้วคงไว้)
type Items []Item

func (it Items) Value() ([]byte, error) { return json.Marshal(it) }
func (it *Items) Scan(src any) error {
	switch v := src.(type) {
	case []byte:
		return json.Unmarshal(v, it)
	case string:
		return json.Unmarshal([]byte(v), it)
	default:
		return nil
	}
}

// Main model (response shape)
type Purchase struct {
	ID              string    `json:"id" db:"id"`
	Title           string    `json:"title" db:"title"`
	Note            string    `json:"note,omitempty" db:"note"`
	Items           Items     `json:"items,omitempty" db:"items"`
	AmountEstimated float64   `json:"amount_estimated,omitempty" db:"amount_estimated"`
	AmountPaid      float64   `json:"amount_paid,omitempty" db:"amount_paid"`
	Currency        string    `json:"currency" db:"currency"`
	Category        string    `json:"category,omitempty" db:"category"`
	Store           string    `json:"store,omitempty" db:"store"`
	Status          Status    `json:"status" db:"status"`
	RequesterID     string    `json:"requester_id" db:"requester_id"`
	BuyerID         string    `json:"buyer_id,omitempty" db:"buyer_id"`
	EditableUntil   time.Time `json:"editable_until" db:"editable_until"`
	CreatedAt       time.Time `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time `json:"updated_at" db:"updated_at"`
}
