package medicine

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/iMookatayou/homeservice-backend/internal/httpx"
)

type Handler struct {
	Svc *Service
}

func NewHandler(svc *Service) *Handler {
	return &Handler{Svc: svc}
}

func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Get("/low-stock", h.listLowStock)
	r.Get("/expiring", h.listExpiringSoon)
	r.Get("/expired", h.listExpired)

	r.Route("/{id}", func(r chi.Router) {
		r.Get("/", h.getByID)
		r.Patch("/", h.update)
		r.Delete("/", h.delete)
		r.Post("/stock", h.adjustStock)
		r.Get("/alert", h.getAlert)
		r.Put("/alert", h.upsertAlert)
	})
}

func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	p := httpx.ParsePagination(r)
	f := ListItemFilter{
		Query:        r.URL.Query().Get("q"),
		Category:     r.URL.Query().Get("category"),
		OnlyLow:      r.URL.Query().Get("only_low") == "1",
		OnlyExpiring: r.URL.Query().Get("only_expiring") == "1",
		Limit:        p.Limit,
		Offset:       p.Offset,
	}
	items, err := h.Svc.ListItems(r.Context(), f)
	if err != nil {
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.Paginate(w, items, p)
}

func (h *Handler) getByID(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	it, err := h.Svc.GetItem(r.Context(), id)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, it)
}

func (h *Handler) create(w http.ResponseWriter, r *http.Request) {
	var p CreateItemPayload
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	it, err := h.Svc.CreateItem(r.Context(), p)
	if err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusCreated, it)
}

func (h *Handler) update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var p UpdateItemPayload
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	it, err := h.Svc.UpdateItem(r.Context(), id, p)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, it)
}

func (h *Handler) delete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := h.Svc.DeleteItem(r.Context(), id); err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) adjustStock(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var p struct {
		Delta float64 `json:"delta"`
	}
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	it, err := h.Svc.AdjustStock(r.Context(), id, p.Delta)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, it)
}

func (h *Handler) getAlert(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	a, err := h.Svc.GetAlert(r.Context(), id)
	if err != nil {
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	if a == nil {
		httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "no alert set"})
		return
	}
	httpx.JSON(w, http.StatusOK, a)
}

func (h *Handler) upsertAlert(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var a MedicineAlert
	if err := json.NewDecoder(r.Body).Decode(&a); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	a.ItemID = id
	if err := h.Svc.UpsertAlert(r.Context(), &a); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, a)
}

func (h *Handler) listLowStock(w http.ResponseWriter, r *http.Request) {
	items, err := h.Svc.ListLowStock(r.Context())
	if err != nil {
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, items)
}

func (h *Handler) listExpiringSoon(w http.ResponseWriter, r *http.Request) {
	items, err := h.Svc.ListExpiringSoon(r.Context())
	if err != nil {
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, items)
}

func (h *Handler) listExpired(w http.ResponseWriter, r *http.Request) {
	items, err := h.Svc.ListExpired(r.Context())
	if err != nil {
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, items)
}