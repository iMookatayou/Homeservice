package auth

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type ctxKey int

const userCtxKey ctxKey = iota

func bearerTokenFromHeader(h string) (string, bool) {
	if h == "" {
		return "", false
	}
	if len(h) < 8 || !strings.EqualFold(h[:7], "bearer ") {
		return "", false
	}
	return strings.TrimSpace(h[7:]), true
}

func keyFuncHMAC(secret string) jwt.Keyfunc {
	return func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return []byte(secret), nil
	}
}

func RequireAuth(secret string, newClaims func() *Claims) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			raw, ok := bearerTokenFromHeader(r.Header.Get("Authorization"))
			if !ok {
				http.Error(w, "missing bearer token", http.StatusUnauthorized)
				return
			}
			claims := newClaims()
			parser := jwt.NewParser(
				jwt.WithValidMethods([]string{"HS256", "HS384", "HS512"}),
				jwt.WithLeeway(60*time.Second),
			)
			token, err := parser.ParseWithClaims(raw, claims, keyFuncHMAC(secret))
			if err != nil || !token.Valid {
				http.Error(w, "invalid token", http.StatusUnauthorized)
				return
			}
			ctx := context.WithValue(r.Context(), userCtxKey, claims)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func OptionalAuth(secret string, newClaims func() *Claims) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			raw, ok := bearerTokenFromHeader(r.Header.Get("Authorization"))
			if ok {
				claims := newClaims()
				parser := jwt.NewParser(
					jwt.WithValidMethods([]string{"HS256", "HS384", "HS512"}),
					jwt.WithLeeway(60*time.Second),
				)
				if token, err := parser.ParseWithClaims(raw, claims, keyFuncHMAC(secret)); err == nil && token.Valid {
					r = r.WithContext(context.WithValue(r.Context(), userCtxKey, claims))
				}
			}
			next.ServeHTTP(w, r)
		})
	}
}

// คืน *Claims (pointer) -> ใช้เทียบ nil ได้สบาย
func ClaimsFrom(r *http.Request) *Claims {
	if v := r.Context().Value(userCtxKey); v != nil {
		if c, ok := v.(*Claims); ok {
			return c
		}
	}
	return nil
}

func UserIDFrom(r *http.Request) (string, bool) {
	if c := ClaimsFrom(r); c != nil && c.UserID != "" {
		return c.UserID, true
	}
	return "", false
}

func RequireAdmin(secret string, newClaims func() *Claims) func(http.Handler) http.Handler {
	base := RequireAuth(secret, newClaims)
	return func(next http.Handler) http.Handler {
		return base(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if c := ClaimsFrom(r); c == nil || c.Role != "admin" {
				http.Error(w, "forbidden", http.StatusForbidden)
				return
			}
			next.ServeHTTP(w, r)
		}))
	}
}
