package storage

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/iMookatayou/homeservice-backend/internal/config"
)

type Local struct {
	dir  string
	base string
}

func NewLocal(cfg config.Config) *Local {
	_ = os.MkdirAll(cfg.LocalDir, 0o755)
	return &Local{dir: cfg.LocalDir, base: strings.TrimRight(cfg.PublicBaseURL, "/")}
}

func randName(n int) (string, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

func sanitize(name string) string {
	name = filepath.Base(name)
	name = strings.ReplaceAll(name, "..", "")
	return name
}

func (l *Local) Save(ctx context.Context, ownerID string, r io.Reader, filename, mime string, size int64) (PutResult, error) {
	fn := sanitize(filename)
	randPart, err := randName(8)
	if err != nil {
		return PutResult{}, err
	}
	outName := fmt.Sprintf("%s_%s", randPart, fn)
	dst := filepath.Join(l.dir, outName)

	f, err := os.Create(dst)
	if err != nil {
		return PutResult{}, err
	}
	defer f.Close()

	if _, err := io.Copy(f, r); err != nil {
		return PutResult{}, err
	}
	return PutResult{
		URL:      fmt.Sprintf("%s/%s", l.base, outName),
		Filename: outName,
		Size:     size,
		MIME:     mime,
	}, nil
}

func (l *Local) PresignPut(ctx context.Context, ownerID, filename, mime string, size int64) (Presign, error) {
	return Presign{}, ErrNotSupported
}
