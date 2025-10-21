package files

import "time"

type File struct {
	ID         string    `json:"id"`
	OwnerID    string    `json:"owner_id"`
	Filename   string    `json:"filename"`
	MIME       string    `json:"mimetype"`
	Size       int64     `json:"size"`
	StorageURL string    `json:"storage_url"`
	CreatedAt  time.Time `json:"created_at"`
}
