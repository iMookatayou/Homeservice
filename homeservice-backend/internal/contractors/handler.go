package contractors

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/iMookatayou/homeservice-backend/internal/auth"
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
	r.Get("/search", h.search)
	r.Get("/favorites", h.listFavorites)

	r.Route("/{id}", func(r chi.Router) {
		r.Get("/", h.getByID)
		r.Patch("/", h.update)
		r.Delete("/", h.delete)
		r.Post("/favorite", h.toggleFavorite)
	})
}

func (h *Handler) search(w http.ResponseWriter, r *http.Request) {
	p := httpx.ParsePagination(r)
	items, err := h.Svc.List(r.Context(), false, p.Limit, p.Offset)
	if err != nil {
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, items)
}

func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	p := httpx.ParsePagination(r)
	items, err := h.Svc.List(r.Context(), false, p.Limit, p.Offset)
	if err != nil {
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.Paginate(w, items, p)
}

func (h *Handler) listFavorites(w http.ResponseWriter, r *http.Request) {
	p := httpx.ParsePagination(r)
	items, err := h.Svc.List(r.Context(), true, p.Limit, p.Offset)
	if err != nil {
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.Paginate(w, items, p)
}

func (h *Handler) getByID(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	c, err := h.Svc.GetByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, c)
}

func (h *Handler) create(w http.ResponseWriter, r *http.Request) {
	userID, ok := auth.UserIDFrom(r)
	if !ok {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	var p CreateContractorPayload
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	c, err := h.Svc.Create(r.Context(), userID, p)
	if err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusCreated, c)
}

func (h *Handler) update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var p UpdateContractorPayload
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	c, err := h.Svc.Update(r.Context(), id, p)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, c)
}

func (h *Handler) delete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := h.Svc.Delete(r.Context(), id); err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) toggleFavorite(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	c, err := h.Svc.ToggleFavorite(r.Context(), id)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, c)
}
