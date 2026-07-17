package notes

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/iMookatayou/homeservice-backend/internal/auth"
	"github.com/iMookatayou/homeservice-backend/internal/httpx"
)

type Handler struct {
	Repo Repo
}

func (h Handler) RegisterRoutes(r chi.Router) {
	r.Route("/notes", func(r chi.Router) {
		r.Get("/", h.list)
		r.Post("/", h.create)

		r.Route("/{id}", func(r chi.Router) {
			r.Get("/", h.getByID)
			r.Put("/", h.update)
			r.Delete("/", h.delete)
			r.Post("/pin", h.pin(true))
			r.Post("/unpin", h.pin(false))
			r.Post("/done", h.done)
			r.Post("/undone", h.undone)
		})
	})
}

func (h Handler) list(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	p := httpx.ParsePagination(r)

	var cat *Category
	if c := r.URL.Query().Get("category"); c != "" {
		cc := Category(c)
		cat = &cc
	}
	var pinned *bool
	if pn := r.URL.Query().Get("pinned"); pn != "" {
		v := pn == "1" || strings.EqualFold(pn, "true")
		pinned = &v
	}
	var done *bool
	if st := r.URL.Query().Get("status"); st != "" {
		if strings.EqualFold(st, "done") {
			v := true
			done = &v
		} else if strings.EqualFold(st, "active") {
			v := false
			done = &v
		}
	} else if d := r.URL.Query().Get("done"); d != "" {
		v := d == "1" || strings.EqualFold(d, "true")
		done = &v
	}

	items, err := h.Repo.List(r.Context(), claims.UserID, ListFilter{
		Query:    r.URL.Query().Get("q"),
		Category: cat,
		Pinned:   pinned,
		Done:     done,
		Limit:    p.Limit,
		Offset:   p.Offset,
	})
	if err != nil {
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.Paginate(w, items, p)
}

func (h Handler) getByID(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	n, err := h.Repo.GetByID(r.Context(), claims.UserID, chi.URLParam(r, "id"))
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, n)
}

func (h Handler) create(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	var p CreateNotePayload
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	if strings.TrimSpace(p.Title) == "" {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "title is required"})
		return
	}
	n, err := h.Repo.Create(r.Context(), claims.UserID, p)
	if err != nil {
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusCreated, n)
}

func (h Handler) update(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	var p UpdateNotePayload
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	n, err := h.Repo.Update(r.Context(), claims.UserID, chi.URLParam(r, "id"), p)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, n)
}

func (h Handler) delete(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if err := h.Repo.Delete(r.Context(), claims.UserID, chi.URLParam(r, "id")); err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h Handler) pin(set bool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		claims := auth.ClaimsFrom(r)
		if claims == nil {
			httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
			return
		}
		n, err := h.Repo.TogglePin(r.Context(), claims.UserID, chi.URLParam(r, "id"), set)
		if err != nil {
			if errors.Is(err, ErrNotFound) {
				httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
				return
			}
			httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
			return
		}
		httpx.JSON(w, http.StatusOK, n)
	}
}

func (h Handler) done(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	n, err := h.Repo.MarkDone(r.Context(), claims.UserID, chi.URLParam(r, "id"))
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, n)
}

func (h Handler) undone(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	n, err := h.Repo.MarkUndone(r.Context(), claims.UserID, chi.URLParam(r, "id"))
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, n)
}