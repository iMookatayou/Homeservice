package purchases

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/yourname/homeservice-backend/internal/auth"
	"github.com/yourname/homeservice-backend/internal/httputil"
)

// ใช้กับกลุ่มที่ถูกครอบด้วย RequireAuth ไว้แล้วใน main.go
type AttachHandler struct {
	Repo      AttachRepo
	JWTSecret string // เผื่อใช้อนาคต
}

// ให้ main.go เรียก: attHandler.RegisterRoutes(pr)
func (h AttachHandler) RegisterRoutes(r chi.Router) {
	r.Get("/purchases/requests/{id}/attachments", h.list)
	r.Post("/purchases/requests/{id}/attachments", h.attach)
	r.Delete("/purchases/requests/{id}/attachments/{file_id}", h.detach)
}

func (h AttachHandler) list(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	out, err := h.Repo.List(r.Context(), id)
	if err != nil {
		httputil.Error(w, http.StatusInternalServerError, "INTERNAL", err.Error(), "")
		return
	}
	httputil.OK(w, out)
}

func (h AttachHandler) attach(w http.ResponseWriter, r *http.Request) {
	pid := chi.URLParam(r, "id")
	uid, _ := auth.UserIDFrom(r)

	// owner เท่านั้น หรือ admin
	if ok, _ := h.Repo.IsOwner(r.Context(), pid, uid); !ok {
		if c := auth.ClaimsFrom(r); c == nil || c.Role != "admin" {
			httputil.Error(w, http.StatusForbidden, "FORBIDDEN", "not owner", "")
			return
		}
	}

	var body struct {
		FileIDs []string `json:"file_ids"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || len(body.FileIDs) == 0 {
		httputil.Error(w, http.StatusBadRequest, "BAD_REQUEST", "invalid body", "")
		return
	}
	for _, fid := range body.FileIDs {
		_ = h.Repo.Attach(r.Context(), pid, fid) // ข้ามอันที่ซ้ำ
	}
	httputil.OK(w, map[string]string{"purchase_id": pid, "status": "attached"})
}

func (h AttachHandler) detach(w http.ResponseWriter, r *http.Request) {
	pid := chi.URLParam(r, "id")
	fid := chi.URLParam(r, "file_id")
	uid, _ := auth.UserIDFrom(r)

	// owner หรือ admin
	if ok, _ := h.Repo.IsOwner(r.Context(), pid, uid); !ok {
		if c := auth.ClaimsFrom(r); c == nil || c.Role != "admin" {
			httputil.Error(w, http.StatusForbidden, "FORBIDDEN", "not owner", "")
			return
		}
	}

	if err := h.Repo.Detach(r.Context(), pid, fid); err != nil {
		httputil.Error(w, http.StatusInternalServerError, "INTERNAL", err.Error(), "")
		return
	}
	httputil.OK(w, map[string]string{"detached": fid})
}
