package media

import (
	"time"
)

const SourceYouTube = "youtube"

type MediaChannel struct {
	ID          string    `json:"id"`
	Source      string    `json:"source"`
	ChannelID   string    `json:"channel_id"`
	DisplayName *string   `json:"display_name,omitempty"`
	URL         *string   `json:"url,omitempty"`
	CreatedBy   *string   `json:"created_by,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
}

type WatchMediaSubscription struct {
	ID        string    `json:"id"`
	WatchID   string    `json:"watch_id"`
	ChannelID string    `json:"channel_id"`
	Notify    bool      `json:"notify"`
	CreatedAt time.Time `json:"created_at"`
}

type MediaPost struct {
	ID           string     `json:"id"`
	ChannelID    string     `json:"channel_id"`
	Source       string     `json:"source"`
	ExternalID   string     `json:"external_id"`
	Title        string     `json:"title"`
	URL          string     `json:"url"`
	ThumbnailURL *string    `json:"thumbnail_url,omitempty"`
	PublishedAt  *time.Time `json:"published_at,omitempty"`
	CreatedAt    time.Time  `json:"created_at"`
}

// Error codes ตามมาตรฐานระบบ
const (
	ErrCodeBadInput                = "BAD_INPUT"
	ErrCodeMediaChannelExists      = "MEDIA_CHANNEL_EXISTS"
	ErrCodeMediaSubscriptionExists = "MEDIA_SUBSCRIPTION_EXISTS"
	ErrCodeWatchNotFound           = "WATCH_NOT_FOUND"
	ErrCodeNotFound                = "NOT_FOUND"
)

type APIError struct {
	Error struct {
		Code    string      `json:"code"`
		Message string      `json:"message"`
		Details interface{} `json:"details,omitempty"`
	} `json:"error"`
}

func NewAPIError(code, msg string, details interface{}) *APIError {
	e := &APIError{}
	e.Error.Code = code
	e.Error.Message = msg
	e.Error.Details = details
	return e
}
