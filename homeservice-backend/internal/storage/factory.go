package storage

import "github.com/iMookatayou/homeservice-backend/internal/config"

func New(cfg config.Config) Service {
	switch cfg.StorageBackend {
	case "local":
		return NewLocal(cfg)
		// case "s3": // ไว้ค่อยเพิ่ม หากต้องการ Presign S3
		//  if s3, err := NewS3(cfg); err == nil { return s3 }
	}
	return NewLocal(cfg) // fallback local
}
