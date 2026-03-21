package files

import (
	"encoding/json"
	"errors"
	"mime"
	"net/http"
	"path/filepath"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/iMookatayou/homeservice-backend/internal/auth"
	"github.com/iMookatayou/homeservice-backend/internal/httpx"
	"github.com/iMookatayou/homeservice-backend/internal/storage"
)

type Handler struct {
	Repo      Repo
	Storage   storage.Service
	JWTSecret string
}

func (h Handler) RegisterRoutes(r chi.Router) {
	r.Post("/uploads", h.upload)
	r.Post("/uploads/presign", h.presign)
	r.Get("/files/{id}", h.getFile)
	r.Delete("/files/{id}", h.deleteFile)
}

func (h Handler) upload(w http.ResponseWriter, r *http.Request) {
	uid, ok := auth.UserIDFrom(r)
	if !ok {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	if err := r.ParseMultipartForm(32 << 20); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid form"})
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "missing file"})
		return
	}
	defer file.Close()

	mtype := header.Header.Get("Content-Type")
	if mtype == "" {
		mtype = mime.TypeByExtension(filepath.Ext(header.Filename))
	}
	if !allowedMIME(mtype) {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "unsupported file type"})
		return
	}
	if header.Size > 25<<20 {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "file too large (max 25MB)"})
		return
	}

	result, err := h.Storage.Save(r.Context(), uid, file, header.Filename, mtype, header.Size)
	if err != nil {
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": "upload failed"})
		return
	}

	rec := &File{
		OwnerID:  uid,
		Filename: result.Filename,
		MIME:     mtype,
		Size:     result.Size,
		URL:      result.URL,
	}
	if err := h.Repo.Create(r.Context(), rec); err != nil {
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusCreated, rec)
}

func (h Handler) presign(w http.ResponseWriter, r *http.Request) {
	uid, ok := auth.UserIDFrom(r)
	if !ok {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	var p struct {
		Filename string `json:"filename"`
		MIME     string `json:"mime"`
		Size     int64  `json:"size"`
	}
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	if p.Filename == "" || p.MIME == "" || p.Size <= 0 {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "filename, mime, size are required"})
		return
	}
	if !allowedMIME(p.MIME) {
		httpx.JSON(w, http.StatusBadRequest, map[string]string{"error": "unsupported file type"})
		return
	}

	presign, err := h.Storage.PresignPut(r.Context(), uid, p.Filename, p.MIME, p.Size)
	if err != nil {
		if errors.Is(err, storage.ErrNotSupported) {
			httpx.JSON(w, http.StatusNotImplemented, map[string]string{"error": "presign not supported"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, presign)
}

func (h Handler) getFile(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	f, err := h.Repo.Get(r.Context(), id)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	httpx.JSON(w, http.StatusOK, f)
}

func (h Handler) deleteFile(w http.ResponseWriter, r *http.Request) {
	uid, ok := auth.UserIDFrom(r)
	if !ok {
		httpx.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	id := chi.URLParam(r, "id")
	if err := h.Repo.Delete(r.Context(), uid, id); err != nil {
		if errors.Is(err, ErrNotFound) {
			httpx.JSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		httpx.JSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func allowedMIME(m string) bool {
	if m == "" {
		return false
	}
	if strings.HasPrefix(m, "image/") {
		return true
	}
	if m == "video/mp4" || m == "application/pdf" {
		return true
	}
	return false
}