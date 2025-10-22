package notes

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/yourname/homeservice-backend/internal/auth"
)

type Handler struct {
	Repo Repo
}

func (h Handler) RegisterRoutes(r chi.Router) {
	r.Route("/notes", func(r chi.Router) {
		r.Get("/", h.list)
		r.Post("/", h.create)

		// กลุ่มที่ผูกกับ {id} — รวม CRUD และ action ไว้ที่เดียวกัน
		r.Route("/{id}", func(r chi.Router) {
			r.Get("/", h.get)
			r.Put("/", h.update)
			r.Delete("/", h.delete)

			// actions
			r.Post("/pin", h.pin(true))
			r.Post("/unpin", h.pin(false))
			r.Post("/done", h.done)
			r.Post("/undone", h.undone)

			// ถ้าจะรองรับ PATCH เพิ่มด้วยก็เปิดได้
			// r.Patch("/done", h.done)
			// r.Patch("/undone", h.undone)
		})
	})
}

func (h Handler) list(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))

	var cat *Category
	if c := r.URL.Query().Get("category"); c != "" {
		cc := Category(c)
		cat = &cc
	}
	var pinned *bool
	if p := r.URL.Query().Get("pinned"); p != "" {
		val := p == "1" || strings.EqualFold(p, "true")
		pinned = &val
	}

	items, err := h.Repo.List(r.Context(), claims.UserID, ListFilter{
		Query:    q,
		Category: cat,
		Pinned:   pinned,
		Limit:    limit,
		Offset:   offset,
	})
	if err != nil {
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, items)
}

func (h Handler) get(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	id := chi.URLParam(r, "id")
	n, err := h.Repo.Get(r.Context(), claims.UserID, id)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, n)
}

func (h Handler) create(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	var in CreateNoteReq
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	if strings.TrimSpace(in.Title) == "" {
		http.Error(w, "title is required", http.StatusBadRequest)
		return
	}
	if in.Category == "" {
		in.Category = CatGeneral
	}
	n, err := h.Repo.Create(r.Context(), claims.UserID, in)
	if err != nil {
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusCreated, n)
}

func (h Handler) update(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	var in UpdateNoteReq
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	id := chi.URLParam(r, "id")
	n, err := h.Repo.Update(r.Context(), claims.UserID, id, in)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, n)
}

func (h Handler) delete(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	id := chi.URLParam(r, "id")
	if err := h.Repo.Delete(r.Context(), claims.UserID, id); err != nil {
		if errors.Is(err, ErrNotFound) {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h Handler) pin(set bool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		claims := auth.ClaimsFrom(r)
		if claims == nil {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		id := chi.URLParam(r, "id")
		n, err := h.Repo.TogglePin(r.Context(), claims.UserID, id, set)
		if err != nil {
			if errors.Is(err, ErrNotFound) {
				http.Error(w, "not found", http.StatusNotFound)
				return
			}
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		writeJSON(w, http.StatusOK, n)
	}
}

// ---------- เสร็จสิ้น / ยกเลิกเสร็จสิ้น ----------

func (h Handler) done(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	id := chi.URLParam(r, "id")
	n, err := h.Repo.MarkDone(r.Context(), claims.UserID, id)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, n)
}

func (h Handler) undone(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	id := chi.URLParam(r, "id")
	n, err := h.Repo.MarkUndone(r.Context(), claims.UserID, id)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, n)
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}
