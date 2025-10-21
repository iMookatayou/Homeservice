package auth

import "github.com/golang-jwt/jwt/v5"

const Issuer = "homeservice-api"

type Claims struct {
	UserID string `json:"uid"`
	Email  string `json:"email"`
	Role   string `json:"role"` // "user" | "admin"
	jwt.RegisteredClaims
}

func (c *Claims) GetUserID() string { return c.UserID }
func (c *Claims) IsAdmin() bool     { return c.Role == "admin" }
func NewClaims() *Claims            { return &Claims{} }
