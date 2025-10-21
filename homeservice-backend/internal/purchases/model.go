package purchases

import "time"

type Priority string
type Status string

const (
	PriorityLow    Priority = "low"
	PriorityMedium Priority = "medium"
	PriorityHigh   Priority = "high"
	PriorityUrgent Priority = "urgent"

	StatusDraft     Status = "draft"
	StatusRequested Status = "requested"
	StatusApproved  Status = "approved"
	StatusRejected  Status = "rejected"
	StatusPurchased Status = "purchased"
	StatusCancelled Status = "cancelled"
)

type Request struct {
	ID            string    `json:"id"`
	UserID        string    `json:"user_id"`
	Title         string    `json:"title"`
	Description   *string   `json:"description,omitempty"`
	Priority      Priority  `json:"priority"`
	Status        Status    `json:"status"`
	PriceEstimate *float64  `json:"price_estimate,omitempty"`
	MediaURLs     []string  `json:"media_urls"`
	NotesAdmin    *string   `json:"notes_admin,omitempty"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

type Item struct {
	ID            string    `json:"id"`
	RequestID     string    `json:"request_id"`
	Name          string    `json:"name"`
	Qty           float64   `json:"qty"`
	Unit          string    `json:"unit"`
	PriceEstimate *float64  `json:"price_estimate,omitempty"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

type Message struct {
	ID        string    `json:"id"`
	RequestID string    `json:"request_id"`
	UserID    string    `json:"user_id"`
	Body      string    `json:"body"`
	MediaURLs []string  `json:"media_urls"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type CreateRequestInput struct {
	Title         string    `json:"title"`
	Description   *string   `json:"description"`
	Priority      *Priority `json:"priority"`
	PriceEstimate *float64  `json:"price_estimate"`
	MediaURLs     []string  `json:"media_urls"`
}

type UpdateRequestInput struct {
	Title         *string   `json:"title"`
	Description   *string   `json:"description"`
	Priority      *Priority `json:"priority"`
	Status        *Status   `json:"status"`
	PriceEstimate *float64  `json:"price_estimate"`
	MediaURLs     *[]string `json:"media_urls"`
	NotesAdmin    *string   `json:"notes_admin"`
}

type CreateItemInput struct {
	Name          string   `json:"name"`
	Qty           *float64 `json:"qty"`
	Unit          *string  `json:"unit"`
	PriceEstimate *float64 `json:"price_estimate"`
}

type CreateMessageInput struct {
	Body      string   `json:"body"`
	MediaURLs []string `json:"media_urls"`
}
