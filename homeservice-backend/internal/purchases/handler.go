package purchases

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

func (h Handler) RegisterRoutes(r chi.Router) {
	r.Route("/purchases", func(r chi.Router) {
		r.Get("/", h.list)
		r.Post("/", h.create)
		r.Get("/{id}", h.getByID)
		r.Patch("/{id}", h.update)
		r.Delete("/{id}", h.delete)
		r.Post("/{id}/claim", h.claim)
		r.Post("/{id}/progress", h.progress)
		r.Post("/{id}/cancel", h.cancel)

		r.Route("/{id}/attachments", func(r chi.Router) {
			r.Post("/", h.linkAttachment)
			r.Delete("/{file_id}", h.unlinkAttachment)
		})
	})
}

func (h Handler) list(w http.ResponseWriter, r *http.Request) {
	p := httpx.ParsePagination(r)
	uid, _ := auth.UserIDFrom(r)

	var st *Status
	if s := r.URL.Query().Get("status"); s != "" {
		sv := Status(s)
		st = &sv
	}

	list, err := h.Svc.List(r.Context(), ListFilter{
		Query:    r.URL.Query().Get("q"),
		Status:   st,
		Category: r.URL.Query().Get("category"),
		Mine:     r.URL.Query().Get("mine"),
		UserID:   uid,
		Limit:    p.Limit,
		Offset:   p.Offset,
	})
	if err != nil {
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.Paginate(w, list, p)
}

func (h Handler) getByID(w http.ResponseWriter, r *http.Request) {
	p, err := h.Svc.Get(r.Context(), chi.URLParam(r, "id"))
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, p)
}

func (h Handler) create(w http.ResponseWriter, r *http.Request) {
	uid, ok := auth.UserIDFrom(r)
	if !ok {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	var in CreatePayload
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	if in.Title == "" {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "title is required"})
		return
	}
	p, err := h.Svc.Create(r.Context(), uid, in)
	if err != nil {
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusCreated, p)
}

func (h Handler) update(w http.ResponseWriter, r *http.Request) {
	uid, ok := auth.UserIDFrom(r)
	if !ok {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	var in UpdateRequesterPayload
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	p, err := h.Svc.UpdateByRequester(r.Context(), uid, chi.URLParam(r, "id"), in)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		if errors.Is(err, ErrForbidden) {
			httpx.JSON(w, http.StatusForbidden, map[string]string{"error": "forbidden"})
			return
		}
		if errors.Is(err, ErrConflict) {
			httpx.JSON(w, http.StatusConflict, map[string]string{"error": "edit window expired"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, p)
}

func (h Handler) delete(w http.ResponseWriter, r *http.Request) {
	uid, ok := auth.UserIDFrom(r)
	if !ok {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if err := h.Svc.Delete(r.Context(), uid, chi.URLParam(r, "id")); err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		if errors.Is(err, ErrForbidden) {
			httpx.JSON(w, http.StatusForbidden, map[string]string{"error": "forbidden"})
			return
		}
		if errors.Is(err, ErrConflict) {
			httpx.JSON(w, http.StatusConflict, map[string]string{"error": "cannot delete"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h Handler) claim(w http.ResponseWriter, r *http.Request) {
	uid, ok := auth.UserIDFrom(r)
	if !ok {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	p, err := h.Svc.Claim(r.Context(), uid, chi.URLParam(r, "id"))
	if err != nil {
		if errors.Is(err, ErrConflict) {
			httpx.JSON(w, http.StatusConflict, map[string]string{"error": "already claimed"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, p)
}

func (h Handler) progress(w http.ResponseWriter, r *http.Request) {
	uid, ok := auth.UserIDFrom(r)
	if !ok {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	var in ProgressPayload
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	p, err := h.Svc.Progress(r.Context(), uid, chi.URLParam(r, "id"), in)
	if err != nil {
		if errors.Is(err, ErrForbidden) {
			httpx.JSON(w, http.StatusForbidden, map[string]string{"error": "forbidden"})
			return
		}
		if errors.Is(err, ErrConflict) {
			httpx.JSON(w, http.StatusConflict, map[string]string{"error": "invalid transition"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, p)
}

func (h Handler) cancel(w http.ResponseWriter, r *http.Request) {
	uid, ok := auth.UserIDFrom(r)
	if !ok {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	p, err := h.Svc.Cancel(r.Context(), uid, chi.URLParam(r, "id"))
	if err != nil {
		if errors.Is(err, ErrForbidden) {
			httpx.JSON(w, http.StatusForbidden, map[string]string{"error": "forbidden"})
			return
		}
		if errors.Is(err, ErrConflict) {
			httpx.JSON(w, http.StatusConflict, map[string]string{"error": "cannot cancel"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, p)
}

func (h Handler) linkAttachment(w http.ResponseWriter, r *http.Request) {
	uid, ok := auth.UserIDFrom(r)
	if !ok {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	var in struct {
		FileID string `json:"file_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	if in.FileID == "" {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "file_id is required"})
		return
	}

	id := chi.URLParam(r, "id")
	if err := h.Svc.LinkAttachment(r.Context(), uid, id, in.FileID); err != nil {
		if errors.Is(err, ErrForbidden) {
			httpx.JSON(w, http.StatusForbidden, map[string]string{"error": "forbidden"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	
	p, err := h.Svc.Get(r.Context(), id)
	if err != nil {
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusCreated, p)
}

func (h Handler) unlinkAttachment(w http.ResponseWriter, r *http.Request) {
	uid, ok := auth.UserIDFrom(r)
	if !ok {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	
	id := chi.URLParam(r, "id")
	if err := h.Svc.UnlinkAttachment(r.Context(), uid, id, chi.URLParam(r, "file_id")); err != nil {
		if errors.Is(err, ErrForbidden) {
			httpx.JSON(w, http.StatusForbidden, map[string]string{"error": "forbidden"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	
	p, err := h.Svc.Get(r.Context(), id)
	if err != nil {
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, p)
}