package chores

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/iMookatayou/homeservice-backend/internal/auth"
	"github.com/iMookatayou/homeservice-backend/internal/httpx"
)

type Handler struct{ Repo Repo }

func (h Handler) RegisterRoutes(r chi.Router) {
	r.Route("/chores", func(r chi.Router) {
		r.Post("/", h.Create)                // สร้างงานบ้าน
		r.Post("/{id}/claim", h.Claim)       // กดรับทำ
		r.Post("/{id}/complete", h.Complete) // เสร็จงาน
		r.Get("/", h.List)
	})
}

func (h Handler) Create(w http.ResponseWriter, r *http.Request) {
	var req CreateChoreReq
	if err := httpx.BindJSON(r, &req); err != nil {
		httpx.WriteJSONError(w, http.StatusBadRequest, "validation failed", httpx.ValidationErrors(err))
		return
	}
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		httpx.WriteJSONError(w, http.StatusUnauthorized, "unauthorized", nil)
		return
	}

	c := &Chore{
		Title:     req.Title,
		Category:  req.Category,
		Note:      req.Note,
		CreatedBy: claims.UserID,
	}
	if err := h.Repo.Create(r.Context(), c); err != nil {
		httpx.WriteJSONError(w, http.StatusInternalServerError, err.Error(), nil)
		return
	}
	httpx.JSON(w, http.StatusCreated, c)
}

func (h Handler) Claim(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		httpx.WriteJSONError(w, http.StatusUnauthorized, "unauthorized", nil)
		return
	}
	id := chi.URLParam(r, "id")
	c, err := h.Repo.Claim(r.Context(), id, claims.UserID)
	if err != nil {
		httpx.WriteJSONError(w, http.StatusBadRequest, err.Error(), nil)
		return
	}
	httpx.JSON(w, http.StatusOK, c)
}

func (h Handler) Complete(w http.ResponseWriter, r *http.Request) {
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		httpx.WriteJSONError(w, http.StatusUnauthorized, "unauthorized", nil)
		return
	}
	id := chi.URLParam(r, "id")
	c, err := h.Repo.Complete(r.Context(), id, claims.UserID)
	if err != nil {
		httpx.WriteJSONError(w, http.StatusBadRequest, err.Error(), nil)
		return
	}
	httpx.JSON(w, http.StatusOK, c)
}

func (h Handler) List(w http.ResponseWriter, r *http.Request) {
	cs, err := h.Repo.List(r.Context(), 50)
	if err != nil {
		httpx.WriteJSONError(w, http.StatusInternalServerError, err.Error(), nil)
		return
	}
	httpx.JSON(w, http.StatusOK, cs)
}
