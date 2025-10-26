package purchases

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
)

type Handler struct {
	Svc *Service
}

// ------- routes (ไม่มี /api/v1 ที่นี่) -------
func (h Handler) RegisterRoutes(r chi.Router) {
	r.Route("/purchases", func(r chi.Router) {
		r.Get("/", h.List)
		r.Post("/", h.Create)

		r.Get("/{id}", h.Detail)
		r.Patch("/{id}", h.UpdateByRequester)
		r.Delete("/{id}", h.Delete)

		r.Post("/{id}/claim", h.Claim)
		r.Post("/{id}/progress", h.Progress)
		r.Post("/{id}/done", h.Done)
		r.Post("/{id}/cancel", h.Cancel)

		r.Post("/{id}/attachments", h.AddAttachment)
		r.Delete("/{id}/attachments/{fileID}", h.RemoveAttachment)
	})
}

// ------- helpers -------
func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, err error) {
	code := http.StatusInternalServerError

	switch {
	case errors.Is(err, ErrBadRequest):
		code = http.StatusBadRequest
	case errors.Is(err, ErrForbidden):
		code = http.StatusForbidden
	case errors.Is(err, ErrConflict):
		code = http.StatusConflict
	case errors.Is(err, ErrNotFound):
		code = http.StatusNotFound
	}

	http.Error(w, err.Error(), code)
}

func userIDFromCtx(r *http.Request) string {
	if v := r.Context().Value("uid"); v != nil {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}

func parseLimitOffset(r *http.Request) (limit, offset int) {
	const defaultLimit, maxLimit = 20, 100
	limit, _ = strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ = strconv.Atoi(r.URL.Query().Get("offset"))
	if limit <= 0 {
		limit = defaultLimit
	}
	if limit > maxLimit {
		limit = maxLimit
	}
	if offset < 0 {
		offset = 0
	}
	return
}

// ------- handlers -------
func (h Handler) List(w http.ResponseWriter, r *http.Request) {
	if h.Svc == nil {
		http.Error(w, "service not initialized", http.StatusInternalServerError)
		return
	}
	q := r.URL.Query().Get("q")
	if q == "" {
		q = r.URL.Query().Get("query")
	}
	mine := r.URL.Query().Get("mine")
	category := r.URL.Query().Get("category")
	statusStr := r.URL.Query().Get("status")

	var st *Status
	if statusStr != "" {
		s := Status(statusStr)
		st = &s
	}
	limit, offset := parseLimitOffset(r)

	f := ListFilter{
		Query:    q,
		Status:   st,
		Category: category,
		Mine:     mine,
		UserID:   userIDFromCtx(r),
		Limit:    limit,
		Offset:   offset,
	}
	list, err := h.Svc.List(r.Context(), f)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, list)
}

func (h Handler) Create(w http.ResponseWriter, r *http.Request) {
	if h.Svc == nil {
		http.Error(w, "service not initialized", http.StatusInternalServerError)
		return
	}
	var in CreatePayload
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&in); err != nil {
		http.Error(w, "invalid json: "+err.Error(), http.StatusBadRequest)
		return
	}
	uid := userIDFromCtx(r)
	p, err := h.Svc.Create(r.Context(), uid, in)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, p)
}

func (h Handler) Detail(w http.ResponseWriter, r *http.Request) {
	if h.Svc == nil {
		http.Error(w, "service not initialized", http.StatusInternalServerError)
		return
	}
	id := chi.URLParam(r, "id")
	p, err := h.Svc.Get(r.Context(), id)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, p)
}

func (h Handler) Delete(w http.ResponseWriter, r *http.Request) {
	if h.Svc == nil {
		http.Error(w, "service not initialized", http.StatusInternalServerError)
		return
	}
	id := chi.URLParam(r, "id")
	uid := userIDFromCtx(r)
	if err := h.Svc.Delete(r.Context(), uid, id); err != nil {
		writeErr(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h Handler) UpdateByRequester(w http.ResponseWriter, r *http.Request) {
	if h.Svc == nil {
		http.Error(w, "service not initialized", http.StatusInternalServerError)
		return
	}
	id := chi.URLParam(r, "id")
	var in UpdateRequesterPayload
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&in); err != nil {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}
	uid := userIDFromCtx(r)
	p, err := h.Svc.UpdateByRequester(r.Context(), uid, id, in)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, p)
}

func (h Handler) Claim(w http.ResponseWriter, r *http.Request) {
	if h.Svc == nil {
		http.Error(w, "service not initialized", http.StatusInternalServerError)
		return
	}
	id := chi.URLParam(r, "id")
	uid := userIDFromCtx(r)
	p, err := h.Svc.Claim(r.Context(), uid, id)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, p)
}

func (h Handler) Progress(w http.ResponseWriter, r *http.Request) {
	if h.Svc == nil {
		http.Error(w, "service not initialized", http.StatusInternalServerError)
		return
	}
	id := chi.URLParam(r, "id")
	uid := userIDFromCtx(r)
	var in ProgressPayload
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&in); err != nil {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}
	p, err := h.Svc.Progress(r.Context(), uid, id, in)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, p)
}

func (h Handler) Done(w http.ResponseWriter, r *http.Request) {
	if h.Svc == nil {
		http.Error(w, "service not initialized", http.StatusInternalServerError)
		return
	}
	id := chi.URLParam(r, "id")
	uid := userIDFromCtx(r)

	// ถ้าโปรเจกต์คุณยังไม่มี StatusDone ให้ใช้ StatusDelivered ไปก่อน
	p, err := h.Svc.Progress(r.Context(), uid, id, ProgressPayload{NextStatus: StatusDelivered})
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, p)
}

func (h Handler) Cancel(w http.ResponseWriter, r *http.Request) {
	if h.Svc == nil {
		http.Error(w, "service not initialized", http.StatusInternalServerError)
		return
	}
	id := chi.URLParam(r, "id")
	uid := userIDFromCtx(r)
	p, err := h.Svc.Cancel(r.Context(), uid, id)
	if err != nil {
		writeErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, p)
}

type addAttachmentPayload struct {
	FileID string `json:"file_id"`
}

func (h Handler) AddAttachment(w http.ResponseWriter, r *http.Request) {
	if h.Svc == nil {
		http.Error(w, "service not initialized", http.StatusInternalServerError)
		return
	}
	id := chi.URLParam(r, "id")
	uid := userIDFromCtx(r)
	var in addAttachmentPayload
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&in); err != nil || in.FileID == "" {
		http.Error(w, "file_id required", http.StatusBadRequest)
		return
	}
	if err := h.Svc.AddAttachment(r.Context(), uid, id, in.FileID); err != nil {
		writeErr(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h Handler) RemoveAttachment(w http.ResponseWriter, r *http.Request) {
	if h.Svc == nil {
		http.Error(w, "service not initialized", http.StatusInternalServerError)
		return
	}
	id := chi.URLParam(r, "id")
	fileID := chi.URLParam(r, "fileID")
	uid := userIDFromCtx(r)
	if fileID == "" {
		http.Error(w, "fileID required", http.StatusBadRequest)
		return
	}
	if err := h.Svc.RemoveAttachment(r.Context(), uid, id, fileID); err != nil {
		writeErr(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
