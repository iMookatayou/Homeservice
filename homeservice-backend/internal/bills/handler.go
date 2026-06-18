package bills

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/iMookatayou/homeservice-backend/internal/auth"
	"github.com/iMookatayou/homeservice-backend/internal/httpx"
)

type Handler struct {
	Svc Service
}

func (h Handler) RegisterRoutes(r chi.Router) {
	r.Get("/bills", h.list)
	r.Post("/bills", h.create)
	r.Get("/bills/summary", h.summary)
	r.Get("/bills/{id}", h.getByID)
	r.Put("/bills/{id}", h.update)
	r.Patch("/bills/{id}", h.update)
	r.Delete("/bills/{id}", h.delete)
	r.Post("/bills/{id}/pay", h.markPaid)
}

func (h Handler) list(w http.ResponseWriter, r *http.Request) {
	p := httpx.ParsePagination(r)
	list, err := h.Svc.ListBills(r.Context(), p.Limit, p.Offset)
	if err != nil {
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.Paginate(w, list, p)
}

func (h Handler) getByID(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	bill, err := h.Svc.GetBill(r.Context(), id)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, bill)
}

func (h Handler) create(w http.ResponseWriter, r *http.Request) {
	userID, ok := auth.UserIDFrom(r)
	if !ok {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	var p CreateBillPayload
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	bill, err := h.Svc.CreateBill(r.Context(), userID, p)
	if err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusCreated, bill)
}

func (h Handler) update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var p UpdateBillPayload
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	bill, err := h.Svc.UpdateBill(r.Context(), id, p)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, bill)
}

func (h Handler) delete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := h.Svc.DeleteBill(r.Context(), id); err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h Handler) markPaid(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	bill, err := h.Svc.MarkPaid(r.Context(), id)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, bill)
}

func (h Handler) summary(w http.ResponseWriter, r *http.Request) {
	res, err := h.Svc.Summarize(r.Context())
	if err != nil {
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, res)
}
