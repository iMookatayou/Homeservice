package files

import (
	"encoding/json"
	"mime"
	"net/http"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/iMookatayou/homeservice-backend/internal/auth"
	"github.com/iMookatayou/homeservice-backend/internal/httputil"
	"github.com/iMookatayou/homeservice-backend/internal/storage"
)

type Handler struct {
	Repo      Repo
	Storage   storage.Service
	JWTSecret string
}

func (h Handler) RegisterRoutes(r chi.Router) {
	// local upload
	r.Post("/uploads", h.UploadLocal)
	// s3 presign (ยังไม่รองรับใน LocalStorage -> จะส่ง 501)
	r.Post("/uploads/presign", h.Presign)
	r.Post("/uploads/confirm", h.Confirm)

	r.Get("/files/{id}", h.Get)
	r.Delete("/files/{id}", h.Delete)
}

func (h Handler) Routes(secret string) http.Handler {
	r := chi.NewRouter()
	r.Use(auth.RequireAuth(secret, auth.NewClaims))
	h.RegisterRoutes(r)
	return r
}

func (h Handler) UploadLocal(w http.ResponseWriter, r *http.Request) {
	uid, _ := auth.UserIDFrom(r)

	if err := r.ParseMultipartForm(32 << 20); err != nil {
		httputil.Error(w, http.StatusBadRequest, "BAD_REQUEST", err.Error(), "")
		return
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		httputil.Error(w, http.StatusBadRequest, "BAD_REQUEST", "missing file", "")
		return
	}
	defer file.Close()

	// --- MIME resolve: header → by extension ---
	mtype := header.Header.Get("Content-Type")
	if mtype == "" {
		mtype = mime.TypeByExtension(filepath.Ext(header.Filename)) // ต้องใส่ .ext ไม่ใช่ทั้งชื่อไฟล์
	}
	if !allowMIME(mtype) {
		httputil.Error(w, http.StatusBadRequest, "BAD_REQUEST", "unsupported mimetype", "")
		return
	}

	// --- Size resolve: header → override ด้วย form value ได้ ---
	size := header.Size
	if size <= 0 {
		if v := r.FormValue("size"); v != "" {
			if n, _ := strconv.ParseInt(v, 10, 64); n > 0 {
				size = n
			}
		}
	}
	if size <= 0 || size > (25<<20) { // 25MB
		httputil.Error(w, http.StatusBadRequest, "BAD_REQUEST", "invalid file size", "")
		return
	}

	// --- Save to storage (local) ---
	put, err := h.Storage.Save(r.Context(), uid, file, header.Filename, mtype, size)
	if err != nil {
		httputil.Error(w, http.StatusBadGateway, "UPLOAD_FAILED", err.Error(), "")
		return
	}

	// --- Record (ใช้เฉพาะฟิลด์ที่มีใน type File เดิม) ---
	rec := &File{
		OwnerID:    uid,
		Filename:   put.Filename,
		MIME:       mtype,
		Size:       put.Size,
		StorageURL: put.URL,
	}

	if err := h.Repo.Create(r.Context(), rec); err != nil {
		httputil.Error(w, http.StatusInternalServerError, "INTERNAL", err.Error(), "")
		return
	}
	httputil.Created(w, rec)
}

func (h Handler) Presign(w http.ResponseWriter, r *http.Request) {
	uid, _ := auth.UserIDFrom(r)
	_ = uid

	var payload struct {
		Filename string `json:"filename"`
		MIME     string `json:"mimetype"`
		Size     int64  `json:"size"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		httputil.Error(w, http.StatusBadRequest, "BAD_REQUEST", err.Error(), "")
		return
	}
	if payload.Filename == "" || payload.MIME == "" || payload.Size <= 0 {
		httputil.Error(w, http.StatusBadRequest, "BAD_REQUEST", "missing filename/mimetype/size", "")
		return
	}
	if !allowMIME(payload.MIME) {
		httputil.Error(w, http.StatusBadRequest, "BAD_REQUEST", "invalid mimetype", "")
		return
	}
	// local backend ไม่รองรับ presign
	httputil.Error(w, http.StatusNotImplemented, "NOT_SUPPORTED", "presign not supported for local storage", "")
}

func (h Handler) Confirm(w http.ResponseWriter, r *http.Request) {
	uid, _ := auth.UserIDFrom(r)

	var payload struct {
		Filename string `json:"filename"`
		MIME     string `json:"mimetype"`
		Size     int64  `json:"size"`
		URL      string `json:"url"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		httputil.Error(w, http.StatusBadRequest, "BAD_REQUEST", err.Error(), "")
		return
	}
	if payload.URL == "" || payload.Filename == "" || payload.MIME == "" || payload.Size <= 0 {
		httputil.Error(w, http.StatusBadRequest, "BAD_REQUEST", "missing fields", "")
		return
	}
	if !allowMIME(payload.MIME) {
		httputil.Error(w, http.StatusBadRequest, "BAD_REQUEST", "invalid mimetype", "")
		return
	}

	rec := &File{
		OwnerID:    uid,
		Filename:   payload.Filename,
		MIME:       payload.MIME,
		Size:       payload.Size,
		StorageURL: payload.URL,
	}
	if err := h.Repo.Create(r.Context(), rec); err != nil {
		httputil.Error(w, http.StatusInternalServerError, "INTERNAL", err.Error(), "")
		return
	}
	httputil.Created(w, rec)
}

func (h Handler) Get(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	f, err := h.Repo.Get(r.Context(), id)
	if err != nil {
		httputil.Error(w, http.StatusNotFound, "NOT_FOUND", "file not found", "")
		return
	}
	httputil.OK(w, f)
}

func (h Handler) Delete(w http.ResponseWriter, r *http.Request) {
	uid, _ := auth.UserIDFrom(r)
	id := chi.URLParam(r, "id")
	if err := h.Repo.Delete(r.Context(), uid, id); err != nil {
		httputil.Error(w, http.StatusNotFound, "NOT_FOUND", "file not found or not owner", "")
		return
	}
	httputil.OK(w, map[string]string{"deleted": id})
}

func allowMIME(m string) bool {
	if m == "" {
		return false
	}
	if strings.HasPrefix(m, "image/") {
		return true
	}
	if m == "video/mp4" {
		return true
	}
	return false
}
