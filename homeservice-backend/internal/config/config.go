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
	}
	if c.JWTSecret == "change-me" {
		log.Println("[WARN] using default JWT secret; set JWT_SECRET in production")
	}
	return c
}
