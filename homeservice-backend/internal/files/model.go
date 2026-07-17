package files

import "time"

type File struct {
	ID        string    `json:"id"`
	OwnerID   string    `json:"owner_id"`
	Filename  string    `json:"filename"`
	MIME      string    `json:"mime"`
	Size      int64     `json:"size"`
	URL       string    `json:"url"`
	CreatedAt time.Time `json:"created_at"`
}