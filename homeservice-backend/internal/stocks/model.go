package stocks

import "time"

// --- DB Models ---

type StockWatch struct {
	ID          string    `json:"id"`
	Symbol      string    `json:"symbol"`
	Exchange    string    `json:"exchange"`
	DisplayName *string   `json:"display_name,omitempty"`
	Note        *string   `json:"note,omitempty"`
	Tags        []string  `json:"tags,omitempty"`
	Scope       string    `json:"scope"` // household | private
	HouseholdID *string   `json:"household_id,omitempty"`
	CreatedBy   string    `json:"created_by"`
	CreatedAt   time.Time `json:"created_at"`
}

type StockSnapshot struct {
	ID           string           `json:"id"`
	StockWatchID string           `json:"watch_id"`
	Title        string           `json:"title"`
	Reason       *string          `json:"reason,omitempty"`
	PriceTarget  *float64         `json:"price_target,omitempty"`
	Files        []map[string]any `json:"files,omitempty"` // [{id,url,mime,size}]
	CapturedAt   time.Time        `json:"captured_at"`
	CreatedAt    time.Time        `json:"created_at"`
}

type StockQuote struct {
	Symbol    string    `json:"symbol"`
	Exchange  string    `json:"exchange"`
	TS        time.Time `json:"ts"`
	Price     float64   `json:"price"`
	Change    *float64  `json:"change,omitempty"`
	ChangePct *float64  `json:"change_pct,omitempty"`
}

// --- DTOs ---

type CreateWatchPayload struct {
	Symbol      string   `json:"symbol"`
	Exchange    string   `json:"exchange"`
	DisplayName *string  `json:"display_name"`
	Note        *string  `json:"note"`
	Tags        []string `json:"tags"`
	Scope       string   `json:"scope"` // household|private
}

type UpdateWatchPayload struct {
	DisplayName *string  `json:"display_name"`
	Note        *string  `json:"note"`
	Tags        []string `json:"tags"`
	Scope       *string  `json:"scope"`
}

type CreateSnapshotPayload struct {
	Title       string           `json:"title"`
	Reason      *string          `json:"reason"`
	PriceTarget *float64         `json:"price_target"`
	Files       []map[string]any `json:"files"`
}

type QuoteResponse struct {
	Symbol    string    `json:"symbol"`
	Exchange  string    `json:"exchange"`
	Price     float64   `json:"price"`
	Change    *float64  `json:"change,omitempty"`
	ChangePct *float64  `json:"change_pct,omitempty"`
	TS        time.Time `json:"ts"`
	Stale     bool      `json:"stale"`
	Provider  string    `json:"provider"`
}

type BatchQuotesResponse struct {
	Items     []QuoteResponse `json:"items"`
	FetchedAt time.Time       `json:"fetched_at"`
	NotFound  []string        `json:"not_found,omitempty"`
}

// ฟิลเตอร์เบื้องต้น
type WatchFilter struct {
	Query  string
	Tags   []string
	Scope  string // "", household, private
	Limit  int
	Cursor string
}
