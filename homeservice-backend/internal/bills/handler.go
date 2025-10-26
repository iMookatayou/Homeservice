package bills

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/render"
	"github.com/google/uuid"

	// ปรับ import ให้ตรงกับโมดูล auth ของคุณ
	"github.com/iMookatayou/homeservice-backend/internal/auth"
)

type Handler struct {
	Svc Service
}

func (h Handler) RegisterRoutes(r chi.Router) {
	r.Post("/bills", h.createBill)
	r.Get("/bills", h.listBills)
	r.Get("/bills/summary", h.summary)
}

func (h Handler) createBill(w http.ResponseWriter, r *http.Request) {
	var req Bill
	if err := render.DecodeJSON(r.Body, &req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	now := time.Now()
	req.ID = uuid.New()
	req.CreatedAt = now
	req.UpdatedAt = now

	userIDStr, ok := auth.UserIDFrom(r)
	if !ok {
		http.Error(w, "unauthenticated", http.StatusUnauthorized)
		return
	}

	userUUID, err := uuid.Parse(userIDStr)
	if err != nil {
		http.Error(w, "invalid user ID", http.StatusBadRequest)
		return
	}
	req.CreatedBy = userUUID

	if req.Status == "paid" {
		if req.PaidAt == nil {
			t := now
			req.PaidAt = &t
		}
	} else {
		req.PaidAt = nil
	}

	if err := h.Svc.CreateBill(r.Context(), &req); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	render.JSON(w, r, req)
}

func (h Handler) listBills(w http.ResponseWriter, r *http.Request) {
	list, err := h.Svc.ListBills(r.Context())
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	render.JSON(w, r, list)
}

func (h Handler) summary(w http.ResponseWriter, r *http.Request) {
	res, err := h.Svc.Summarize(r.Context())
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	render.JSON(w, r, res)
}
