package auth

import (
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func SignJWT(secret, uid, email string, ttl time.Duration) (string, error) {
	return SignJWTWithRole(secret, uid, email, "user", ttl)
}

func SignJWTWithRole(secret, uid, email, role string, ttl time.Duration) (string, error) {
	now := time.Now().UTC()
	claims := Claims{
		UserID: uid,
		Email:  email,
		Role:   role,
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    Issuer,
			Subject:   uid,
			IssuedAt:  jwt.NewNumericDate(now),
			NotBefore: jwt.NewNumericDate(now.Add(-30 * time.Second)),
			ExpiresAt: jwt.NewNumericDate(now.Add(ttl)),
		},
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return tok.SignedString([]byte(secret))
}
