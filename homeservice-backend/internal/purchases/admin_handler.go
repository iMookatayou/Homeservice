package purchases

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/yourname/homeservice-backend/internal/httputil"
)

// AdminHandler ให้ main ครอบด้วย auth.RequireAdmin(...)
type AdminHandler struct {
	Repo      AdminRepo
	JWTSecret string // ไม่จำเป็นถ้าใช้ RegisterRoutes; เก็บไว้เผื่ออนาคต
}

// ใช้ตัวนี้ใน main:
//
//	api.Group(func(ad chi.Router) {
//	  ad.Use(auth.RequireAdmin(cfg.JWTSecret, auth.NewClaims))
//	  adminHandler.RegisterRoutes(ad)
//	})
func (h AdminHandler) RegisterRoutes(r chi.Router) {
	r.Get("/purchases/requests", h.list)
	r.Post("/purchases/requests/{id}/approve", h.approve)
	r.Post("/purchases/requests/{id}/reject", h.reject)
}

/* ===== handlers ===== */

func (h AdminHandler) list(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	var status *string
	if s := q.Get("status"); s != "" {
		status = &s
	}
	limit, _ := strconv.Atoi(q.Get("limit"))
	offset, _ := strconv.Atoi(q.Get("offset"))
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	out, err := h.Repo.List(r.Context(), status, limit, offset)
	if err != nil {
		httputil.Error(w, http.StatusInternalServerError, "INTERNAL", err.Error(), "")
		return
	}
	httputil.OK(w, out)
}

func (h AdminHandler) approve(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := h.Repo.UpdateStatus(r.Context(), id, StatusApproved, "", ""); err != nil {
		httputil.Error(w, http.StatusNotFound, "NOT_FOUND", "request not found", "")
		return
	}
	httputil.OK(w, map[string]string{"id": id, "status": "approved"})
}

func (h AdminHandler) reject(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var body struct {
		Reason string `json:"reason"`
	}
	_ = json.NewDecoder(r.Body).Decode(&body)
	if err := h.Repo.UpdateStatus(r.Context(), id, StatusRejected, body.Reason, ""); err != nil {
		httputil.Error(w, http.StatusNotFound, "NOT_FOUND", "request not found", "")
		return
	}
	httputil.OK(w, map[string]string{"id": id, "status": "rejected"})
}
