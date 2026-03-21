package storage

import (
	"log"

	"github.com/iMookatayou/homeservice-backend/internal/config"
)

func New(cfg config.Config) Service {
	switch cfg.StorageBackend {
	case "r2":
		r2, err := NewR2(cfg)
		if err != nil {
			log.Fatalf("failed to init R2: %v", err)
		}
		return r2
	default:
		return NewLocal(cfg)
	}
}