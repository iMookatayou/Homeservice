package purchases

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/yourname/homeservice-backend/internal/auth"
	"github.com/yourname/homeservice-backend/internal/httputil"
)

type Handler struct {
	Repo Repo
}

func (h Handler) RegisterRoutes(r chi.Router) {
	r.Route("/purchases", func(r chi.Router) {
		r.Get("/requests", h.listMine)
		r.Post("/requests", h.create)

		r.Route("/requests/{id}", func(r chi.Router) {
			r.Get("/", h.get)
			r.Patch("/", h.update)
			r.Delete("/", h.remove)

			r.Post("/items", h.addItem)
			r.Get("/items", h.listItems)

			r.Post("/messages", h.addMessage)
			r.Get("/messages", h.listMessages)
		})
	})
}

/* ===== Requests ===== */

func (h Handler) create(w http.ResponseWriter, r *http.Request) {
	uid, ok := auth.UserIDFrom(r)
	if !ok {
		httputil.Error(w, http.StatusUnauthorized, "UNAUTHORIZED", "missing auth", "")
		return
	}
	var in CreateRequestInput
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		httputil.Error(w, http.StatusBadRequest, "BAD_REQUEST", "invalid json body", "")
		return
	}
	if in.Title == "" {
		httputil.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "title is required", "")
		return
	}
	rec, err := h.Repo.CreateRequest(r.Context(), uid, in)
	if err != nil {
		httputil.Error(w, http.StatusInternalServerError, "CREATE_FAILED", "could not create purchase request", "")
		return
	}
	httputil.Created(w, rec)
}

func (h Handler) listMine(w http.ResponseWriter, r *http.Request) {
	uid, ok := auth.UserIDFrom(r)
	if !ok {
		httputil.Error(w, http.StatusUnauthorized, "UNAUTHORIZED", "missing auth", "")
		return
	}
	limit := 20
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= 100 {
			limit = n
		}
	}
	cursor := r.URL.Query().Get("cursor")
	list, next, err := h.Repo.ListMyRequests(r.Context(), uid, limit, cursor)
	if err != nil {
		httputil.Error(w, http.StatusInternalServerError, "LIST_FAILED", "could not list purchase requests", "")
		return
	}
	httputil.OK(w, map[string]interface{}{"items": list, "next": next})
}

func (h Handler) get(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	rec, err := h.Repo.GetRequest(r.Context(), id)
	if err != nil {
		httputil.Error(w, http.StatusNotFound, "NOT_FOUND", "request not found", "")
		return
	}
	httputil.OK(w, rec)
}

func (h Handler) update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var in UpdateRequestInput
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		httputil.Error(w, http.StatusBadRequest, "BAD_REQUEST", "invalid json body", "")
		return
	}
	rec, err := h.Repo.UpdateRequest(r.Context(), id, in)
	if err != nil {
		httputil.Error(w, http.StatusNotFound, "NOT_FOUND", "request not found", "")
		return
	}
	httputil.OK(w, rec)
}

func (h Handler) remove(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := h.Repo.DeleteRequest(r.Context(), id); err != nil {
		httputil.Error(w, http.StatusNotFound, "NOT_FOUND", "request not found", "")
		return
	}
	httputil.OK(w, map[string]string{"deleted": id})
}

/* ===== Items ===== */

func (h Handler) addItem(w http.ResponseWriter, r *http.Request) {
	reqID := chi.URLParam(r, "id")
	var in CreateItemInput
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		httputil.Error(w, http.StatusBadRequest, "BAD_REQUEST", "invalid json body", "")
		return
	}
	if in.Name == "" {
		httputil.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "name is required", "")
		return
	}
	it, err := h.Repo.AddItem(r.Context(), reqID, in)
	if err != nil {
		httputil.Error(w, http.StatusInternalServerError, "CREATE_FAILED", "could not add item", "")
		return
	}
	httputil.Created(w, it)
}

func (h Handler) listItems(w http.ResponseWriter, r *http.Request) {
	reqID := chi.URLParam(r, "id")
	items, err := h.Repo.ListItems(r.Context(), reqID)
	if err != nil {
		httputil.Error(w, http.StatusInternalServerError, "LIST_FAILED", "could not list items", "")
		return
	}
	httputil.OK(w, items)
}

/* ===== Messages ===== */

func (h Handler) addMessage(w http.ResponseWriter, r *http.Request) {
	reqID := chi.URLParam(r, "id")
	uid, ok := auth.UserIDFrom(r)
	if !ok {
		httputil.Error(w, http.StatusUnauthorized, "UNAUTHORIZED", "missing auth", "")
		return
	}
	var in CreateMessageInput
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		httputil.Error(w, http.StatusBadRequest, "BAD_REQUEST", "invalid json body", "")
		return
	}
	if in.Body == "" {
		httputil.Error(w, http.StatusBadRequest, "VALIDATION_ERROR", "body is required", "")
		return
	}
	msg, err := h.Repo.AddMessage(r.Context(), reqID, uid, in)
	if err != nil {
		httputil.Error(w, http.StatusInternalServerError, "CREATE_FAILED", "could not add message", "")
		return
	}
	httputil.Created(w, msg)
}

func (h Handler) listMessages(w http.ResponseWriter, r *http.Request) {
	reqID := chi.URLParam(r, "id")
	msgs, err := h.Repo.ListMessages(r.Context(), reqID)
	if err != nil {
		httputil.Error(w, http.StatusInternalServerError, "LIST_FAILED", "could not list messages", "")
		return
	}
	httputil.OK(w, msgs)
}
