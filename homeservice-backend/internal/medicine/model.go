package medicine

import "time"

type MedicineItem struct {
	ID         string     `json:"id"`
	Name       string     `json:"name"`
	Form       *string    `json:"form,omitempty"`
	Unit       *string    `json:"unit,omitempty"`
	Category   *string    `json:"category,omitempty"`
	StockQty   float64    `json:"stock_qty"`
	ExpiryDate *time.Time `json:"expiry_date,omitempty"`
	Location   *string    `json:"location,omitempty"`
	Note       *string    `json:"note,omitempty"`
	CreatedAt  time.Time  `json:"created_at"`
	UpdatedAt  time.Time  `json:"updated_at"`
}

type MedicineAlert struct {
	ID               string   `json:"id"`
	ItemID           string   `json:"item_id"`
	MinQty           *float64 `json:"min_qty,omitempty"`
	ExpiryWindowDays *int     `json:"expiry_window_days,omitempty"`
	IsEnabled        bool     `json:"is_enabled"`
}

type CreateItemPayload struct {
	Name       string     `json:"name"`
	Form       *string    `json:"form,omitempty"`
	Unit       *string    `json:"unit,omitempty"`
	Category   *string    `json:"category,omitempty"`
	StockQty   float64    `json:"stock_qty"`
	ExpiryDate *time.Time `json:"expiry_date,omitempty"`
	Location   *string    `json:"location,omitempty"`
	Note       *string    `json:"note,omitempty"`
}

type UpdateItemPayload struct {
	Name       *string    `json:"name,omitempty"`
	Form       *string    `json:"form,omitempty"`
	Unit       *string    `json:"unit,omitempty"`
	Category   *string    `json:"category,omitempty"`
	StockQty   *float64   `json:"stock_qty,omitempty"`
	ExpiryDate *time.Time `json:"expiry_date,omitempty"`
	Location   *string    `json:"location,omitempty"`
	Note       *string    `json:"note,omitempty"`
}

type ListItemFilter struct {
	Query        string
	Category     string
	OnlyLow      bool
	OnlyExpiring bool
	Limit        int
	Offset       int
}