package user

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/yourname/homeservice-backend/internal/auth"
)

type Handler struct {
	Repo      Repo
	JWTSecret string
}

type registerReq struct {
	Name     string `json:"name"`
	Email    string `json:"email"`
	Password string `json:"password"`
}
type loginReq struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}
type tokenRes struct {
	AccessToken string `json:"access_token"`
	ExpiresIn   int64  `json:"expires_in"`
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func (h Handler) Register(w http.ResponseWriter, r *http.Request) {
	var req registerReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "bad json", http.StatusBadRequest)
		return
	}
	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	if req.Name == "" || req.Email == "" || len(req.Password) < 6 {
		http.Error(w, "invalid input", http.StatusBadRequest)
		return
	}
	pwHash, _ := auth.HashPassword(req.Password)
	u := &User{Name: req.Name, Email: req.Email, PasswordHash: pwHash}
	if err := h.Repo.Create(r.Context(), u); err != nil {
		http.Error(w, "email exists?", http.StatusConflict)
		return
	}
	tok, _ := auth.SignJWT(h.JWTSecret, u.ID, u.Email, 24*time.Hour)
	writeJSON(w, http.StatusCreated, map[string]any{
		"user":   map[string]any{"id": u.ID, "name": u.Name, "email": u.Email},
		"tokens": tokenRes{AccessToken: tok, ExpiresIn: 24 * 3600},
	})
}

func (h Handler) Login(w http.ResponseWriter, r *http.Request) {
	var req loginReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "bad json", http.StatusBadRequest)
		return
	}
	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	u, err := h.Repo.ByEmail(r.Context(), req.Email)
	if err != nil {
		http.Error(w, "invalid credentials", http.StatusUnauthorized)
		return
	}
	if !auth.CheckPassword(u.PasswordHash, req.Password) {
		http.Error(w, "invalid credentials", http.StatusUnauthorized)
		return
	}
	tok, _ := auth.SignJWT(h.JWTSecret, u.ID, u.Email, 24*time.Hour)
	writeJSON(w, http.StatusOK, map[string]any{
		"user":   map[string]any{"id": u.ID, "name": u.Name, "email": u.Email},
		"tokens": tokenRes{AccessToken: tok, ExpiresIn: 24 * 3600},
	})
}

func (h Handler) Me(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		http.Error(w, "no claims", http.StatusUnauthorized)
		return
	}
	u, err := h.Repo.ByID(r.Context(), claims.UserID)
	if err != nil {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"id": u.ID, "name": u.Name, "email": u.Email,
	})
}

// helpers
var ErrBad = errors.New("bad request")
