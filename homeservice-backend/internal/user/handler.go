package user

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"github.com/iMookatayou/homeservice-backend/internal/auth"
	"github.com/iMookatayou/homeservice-backend/internal/httpx"
)

type Handler struct {
	Repo      Repo
	JWTSecret string
}

func (h Handler) RegisterRoutes(r interface{ Get(string, http.HandlerFunc); Post(string, http.HandlerFunc); Patch(string, http.HandlerFunc) }) {
}

func (h Handler) Register(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Name     string `json:"name"`
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}

	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	if req.Name == "" || req.Email == "" || len(req.Password) < 6 {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "name, email and password (min 6) are required"})
		return
	}

	pwHash, _ := auth.HashPassword(req.Password)
	u := &User{Name: req.Name, Email: req.Email, PasswordHash: pwHash}
	if err := h.Repo.Create(r.Context(), u); err != nil {
		httpx.JSON(w, http.StatusConflict, map[string]string{"error": "email already exists"})
		return
	}

	accessTok, _ := auth.SignJWTWithRole(h.JWTSecret, u.ID, u.Email, u.Role, 24*time.Hour)
	refreshTok, _ := auth.SignJWTWithRole(h.JWTSecret, u.ID, u.Email, u.Role, 7*24*time.Hour)
	httpx.JSON(w, http.StatusCreated, map[string]any{
		"user": map[string]any{
			"id":    u.ID,
			"name":  u.Name,
			"email": u.Email,
			"role":  u.Role,
		},
		"access_token":  accessTok,
		"refresh_token": refreshTok,
		"expires_in":    24 * 3600,
	})
}

func (h Handler) Login(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}

	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	u, err := h.Repo.ByEmail(r.Context(), req.Email)
	if err != nil || !auth.CheckPassword(u.PasswordHash, req.Password) {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid credentials"})
		return
	}

	accessTok, _ := auth.SignJWTWithRole(h.JWTSecret, u.ID, u.Email, u.Role, 24*time.Hour)
	refreshTok, _ := auth.SignJWTWithRole(h.JWTSecret, u.ID, u.Email, u.Role, 7*24*time.Hour)
	httpx.JSON(w, http.StatusCreated, map[string]any{
		"user": map[string]any{
			"id":    u.ID,
			"name":  u.Name,
			"email": u.Email,
			"role":  u.Role,
		},
		"access_token":  accessTok,
		"refresh_token": refreshTok,
		"expires_in":    24 * 3600,
	})
}

func (h Handler) Refresh(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	if req.RefreshToken == "" {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "refresh_token required"})
		return
	}

	claims := auth.NewClaims()
	parser := jwt.NewParser(
		jwt.WithValidMethods([]string{"HS256", "HS384", "HS512"}),
		jwt.WithLeeway(60*time.Second),
	)
	token, err := parser.ParseWithClaims(req.RefreshToken, claims, func(t *jwt.Token) (interface{}, error) {
		return []byte(h.JWTSecret), nil
	})
	if err != nil || !token.Valid {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid refresh token"})
		return
	}

	// Verify user still exists
	u, err := h.Repo.ByID(r.Context(), claims.UserID)
	if err != nil {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "user not found"})
		return
	}

	accessTok, _ := auth.SignJWTWithRole(h.JWTSecret, u.ID, u.Email, u.Role, 24*time.Hour)
	refreshTok, _ := auth.SignJWTWithRole(h.JWTSecret, u.ID, u.Email, u.Role, 7*24*time.Hour)

	httpx.JSON(w, http.StatusOK, map[string]any{
		"access_token":  accessTok,
		"refresh_token": refreshTok,
		"expires_in":    24 * 3600,
	})
}

func (h Handler) Me(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	u, err := h.Repo.ByID(r.Context(), claims.UserID)
	if err != nil {
		httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "user not found"})
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{
		"id":    u.ID,
		"name":  u.Name,
		"email": u.Email,
		"role":  u.Role,
	})
}

func (h Handler) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	var req struct {
		Name string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	if strings.TrimSpace(req.Name) == "" {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "name is required"})
		return
	}
	u, err := h.Repo.UpdateName(r.Context(), claims.UserID, req.Name)
	if err != nil {
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{
		"id":    u.ID,
		"name":  u.Name,
		"email": u.Email,
	})
}

func (h Handler) ChangePassword(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	var req struct {
		OldPassword string `json:"old_password"`
		NewPassword string `json:"new_password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	if len(req.NewPassword) < 6 {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "new password must be at least 6 characters"})
		return
	}

	u, err := h.Repo.ByID(r.Context(), claims.UserID)
	if err != nil {
		httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "user not found"})
		return
	}
	if !auth.CheckPassword(u.PasswordHash, req.OldPassword) {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid old password"})
		return
	}

	newHash, _ := auth.HashPassword(req.NewPassword)
	if err := h.Repo.UpdatePassword(r.Context(), claims.UserID, newHash); err != nil {
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]string{"message": "password updated"})
}

	func (h Handler) Logout(w http.ResponseWriter, r *http.Request) {
		httpx.JSON(w, http.StatusOK, map[string]string{"message": "logged out"})
	}

	func (h Handler) ForgotPassword(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email string `json:"email"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	if req.Email == "" {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "email is required"})
		return
	}

	// ไม่บอกว่า email มีอยู่ไหม กัน enumeration attack
	u, err := h.Repo.ByEmail(r.Context(), req.Email)
	if err != nil {
		httpx.JSON(w, http.StatusOK, map[string]string{"message": "if email exists, reset link will be sent"})
		return
	}

	token, err := h.Repo.CreatePasswordReset(r.Context(), u.ID)
	if err != nil {
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}

	// TODO: ส่ง email จริงๆ ตอนนี้ log token ไว้ก่อน
	// log.Printf("reset token for %s: %s", req.Email, token)
	_ = token

	httpx.JSON(w, http.StatusOK, map[string]string{"message": "if email exists, reset link will be sent"})}

	func (h Handler) ResetPassword(w http.ResponseWriter, r *http.Request) {
		var req struct {
			Token       string `json:"token"`
			NewPassword string `json:"new_password"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
			return
		}
		if req.Token == "" || len(req.NewPassword) < 6 {
			httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "token and new_password (min 6) are required"})
			return
		}

		userID, err := h.Repo.ValidatePasswordReset(r.Context(), req.Token)
		if err != nil {
			httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid or expired token"})
			return
		}

		newHash, _ := auth.HashPassword(req.NewPassword)
		if err := h.Repo.UpdatePassword(r.Context(), userID, newHash); err != nil {
			httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
			return
		}

		if err := h.Repo.MarkPasswordResetUsed(r.Context(), req.Token); err != nil {
			httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
			return
		}

	httpx.JSON(w, http.StatusOK, map[string]string{"message": "password reset successful"})
}	

var _ = errors.New