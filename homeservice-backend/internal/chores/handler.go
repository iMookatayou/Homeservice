package chores

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/iMookatayou/homeservice-backend/internal/auth"
	"github.com/iMookatayou/homeservice-backend/internal/httpx"
)

type Handler struct {
	Repo Repo
}

func (h Handler) RegisterRoutes(r chi.Router) {
	r.Route("/chores", func(r chi.Router) {
		r.Get("/", h.list)
		r.Post("/", h.create)
		r.Route("/{id}", func(r chi.Router) {
			r.Post("/claim", h.claim)
			r.Post("/complete", h.complete)
			r.Delete("/", h.delete)
		})
	})
}

func (h Handler) list(w http.ResponseWriter, r *http.Request) {
	p := httpx.ParsePagination(r)
	cs, err := h.Repo.List(r.Context(), p.Limit, p.Offset)
	if err != nil {
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.Paginate(w, cs, p)
}

func (h Handler) create(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	var req CreateChoreReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	if req.Title == "" {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "title is required"})
		return
	}
	c := &Chore{
		Title:     req.Title,
		Category:  req.Category,
		Note:      req.Note,
		CreatedBy: claims.UserID,
	}
	if err := h.Repo.Create(r.Context(), c); err != nil {
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusCreated, c)
}

func (h Handler) claim(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	c, err := h.Repo.Claim(r.Context(), chi.URLParam(r, "id"), claims.UserID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		if errors.Is(err, ErrConflict) {
			httpx.JSON(w, http.StatusConflict, map[string]string{"error": "already claimed"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, c)
}

func (h Handler) complete(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	c, err := h.Repo.Complete(r.Context(), chi.URLParam(r, "id"), claims.UserID)
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

func (h Handler) delete(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if err := h.Repo.Delete(r.Context(), chi.URLParam(r, "id"), claims.UserID); err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		if errors.Is(err, ErrForbidden) {
			httpx.JSON(w, http.StatusForbidden, map[string]string{"error": "forbidden"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}