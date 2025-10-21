package httpx

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
)

// SecurityHeaders: เสริมความปลอดภัยฝั่งบราวเซอร์
func SecurityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Security / clickjacking / MIME
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")

		// Referrer & Permissions
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("Permissions-Policy", "geolocation=(), microphone=(), camera=()")

		// Cross-origin isolation/resource policy (เหมาะกับ API)
		w.Header().Set("Cross-Origin-Opener-Policy", "same-origin")
		w.Header().Set("Cross-Origin-Resource-Policy", "same-origin")

		// HSTS (เปิดเมื่ออยู่หลัง HTTPS เท่านั้น)
		// ถ้าพัฒนา local ที่เป็น http ให้คอมเมนต์ออก
		if r.TLS != nil {
			w.Header().Set("Strict-Transport-Security", "max-age=63072000; includeSubDomains; preload")
		}

		// CSP – สำหรับ API ให้ปิดทุกอย่าง
		w.Header().Set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'")

		next.ServeHTTP(w, r)
	})
}

// NoCache: ปิด cache สำหรับทุก response API
func NoCache(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
		w.Header().Set("Pragma", "no-cache")
		w.Header().Set("Expires", "0")
		next.ServeHTTP(w, r)
	})
}

func CommonMiddlewares(allowOrigin string) []func(http.Handler) http.Handler {
	return []func(http.Handler) http.Handler{
		middleware.RequestID,
		middleware.RealIP,
		middleware.Recoverer,
		middleware.Timeout(60 * time.Second),

		middleware.AllowContentType("application/json", "multipart/form-data"),

		middleware.Compress(5),
		middleware.Logger,
		SecurityHeaders,
		NoCache,
		cors.Handler(cors.Options{
			AllowedOrigins:   []string{allowOrigin, "http://localhost:*", "http://127.0.0.1:*"},
			AllowedMethods:   []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"},
			AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token"},
			ExposedHeaders:   []string{"Link"},
			AllowCredentials: true,
			MaxAge:           300,
		}),
		func(next http.Handler) http.Handler {
			return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.Header().Add("Vary", "Origin")
				next.ServeHTTP(w, r)
			})
		},
	}
}
