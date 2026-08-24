package config

import (
	"log"
	"os"
	"strconv"
)

type Config struct {
	AppPort    string
	DSN        string
	JWTSecret  string
	CorsOrigin string

	StorageBackend string
	LocalDir       string
	PublicBaseURL  string

	// Cloudflare R2
	R2AccountID string
	R2AccessKey string
	R2SecretKey string
	R2Bucket    string
	R2PublicURL string
}

func Getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func Getbool(key string, def bool) bool {
	v := os.Getenv(key)
	if v == "" {
		return def
	}
	b, err := strconv.ParseBool(v)
	if err != nil {
		return def
	}
	return b
}

func Load() Config {
	c := Config{
		AppPort:    Getenv("APP_PORT", "8080"),
		DSN:        Getenv("DB_DSN", "postgres://dev:devpass@localhost:5432/homeservice?sslmode=disable"),
		JWTSecret:  Getenv("JWT_SECRET", "change-me"),
		CorsOrigin: Getenv("CORS_ALLOW_ORIGIN", "*"),

		StorageBackend: Getenv("STORAGE_BACKEND", "local"),
		LocalDir:       Getenv("LOCAL_STORAGE_DIR", "./data/uploads"),
		PublicBaseURL:  Getenv("PUBLIC_BASE_URL", "http://localhost:8080/static"),

		R2AccountID: Getenv("R2_ACCOUNT_ID", ""),
		R2AccessKey: Getenv("R2_ACCESS_KEY_ID", ""),
		R2SecretKey: Getenv("R2_SECRET_ACCESS_KEY", ""),
		R2Bucket:    Getenv("R2_BUCKET", ""),
		R2PublicURL: Getenv("R2_PUBLIC_URL", ""),
	}

	if c.JWTSecret == "change-me" {
		log.Println("[WARN] using default JWT secret; set JWT_SECRET in production")
	}

	return c
}