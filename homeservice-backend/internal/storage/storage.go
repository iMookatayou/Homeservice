package storage

import (
	"context"
	"errors"
	"io"
	"time"
)

var ErrNotSupported = errors.New("storage: operation not supported")

type PutResult struct {
	URL      string
	Filename string
	Size     int64
	MIME     string
}

type Presign struct {
	URL     string            `json:"url"`
	Headers map[string]string `json:"headers"`
	Expire  time.Time         `json:"expire"`
}

type Service interface {
	Save(ctx context.Context, ownerID string, r io.Reader, filename, mime string, size int64) (PutResult, error)
	PresignPut(ctx context.Context, ownerID, filename, mime string, size int64) (Presign, error)
}
