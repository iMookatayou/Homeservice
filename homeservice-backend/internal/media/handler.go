package media

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
)

type Handler struct {
	Svc *Service
}

func NewHandler(s *Service) *Handler { return &Handler{Svc: s} }

func (h *Handler) Mount(r chi.Router) {
	// Channels (global)
	r.Post("/media/channels", h.postChannel)
	r.Get("/media/channels", h.getChannel) // ?source=youtube&channel_id=UCxxxx
	r.Delete("/media/channels/{channel_uuid}", h.deleteChannel)

	// Watch subscriptions
	r.Route("/stocks/watch/{watch_id}", func(r chi.Router) {
		r.Post("/channels", h.subscribe)
		r.Get("/channels", h.listSubs)
		r.Delete("/channels/{channel_uuid}", h.unsubscribe)

		// Aggregated media feed for a watch
		r.Get("/media", h.listMedia)
	})
}

// --- helpers ---
func writeJSON(w http.ResponseWriter, code int, v interface{}) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}
func writeErr(w http.ResponseWriter, code, msg string, httpStatus int, details interface{}) {
	writeJSON(w, httpStatus, NewAPIError(code, msg, details))
}

// --- Channels ---
func (h *Handler) postChannel(w http.ResponseWriter, r *http.Request) {
	var p CreateChannelPayload
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		writeErr(w, ErrCodeBadInput, "invalid json", http.StatusBadRequest, nil)
		return
	}
	// TODO: ดึง user id จาก context ถ้ามี JWT และส่งให้ createdBy
	ch, err := h.Svc.CreateOrUpsertChannel(r.Context(), p, nil)
	if err != nil {
		if err.Error() == ErrCodeBadInput {
			writeErr(w, ErrCodeBadInput, "invalid source or channel_id", http.StatusBadRequest, nil)
			return
		}
		writeErr(w, "INTERNAL", err.Error(), http.StatusInternalServerError, nil)
		return
	}
	writeJSON(w, http.StatusOK, ch)
}

func (h *Handler) getChannel(w http.ResponseWriter, r *http.Request) {
	source := r.URL.Query().Get("source")
	channelID := r.URL.Query().Get("channel_id")
	if source == "" || channelID == "" {
		writeErr(w, ErrCodeBadInput, "source & channel_id are required", http.StatusBadRequest, nil)
		return
	}
	ch, err := h.Svc.GetChannel(r.Context(), source, channelID)
	if err != nil {
		writeErr(w, "INTERNAL", err.Error(), http.StatusInternalServerError, nil)
		return
	}
	if ch == nil {
		writeErr(w, ErrCodeNotFound, "channel not found", http.StatusNotFound, nil)
		return
	}
	writeJSON(w, http.StatusOK, ch)
}

func (h *Handler) deleteChannel(w http.ResponseWriter, r *http.Request) {
	channelUUID := chi.URLParam(r, "channel_uuid")
	if channelUUID == "" {
		writeErr(w, ErrCodeBadInput, "channel_uuid required", http.StatusBadRequest, nil)
		return
	}
	if err := h.Svc.DeleteChannel(r.Context(), channelUUID); err != nil {
		writeErr(w, "INTERNAL", err.Error(), http.StatusInternalServerError, nil)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// --- Subscriptions ---
func (h *Handler) subscribe(w http.ResponseWriter, r *http.Request) {
	watchID := chi.URLParam(r, "watch_id")
	var p SubscribePayload
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		writeErr(w, ErrCodeBadInput, "invalid json", http.StatusBadRequest, nil)
		return
	}
	sub, err := h.Svc.Subscribe(r.Context(), watchID, p)
	if err != nil {
		writeErr(w, "INTERNAL", err.Error(), http.StatusInternalServerError, nil)
		return
	}
	writeJSON(w, http.StatusOK, sub)
}

func (h *Handler) listSubs(w http.ResponseWriter, r *http.Request) {
	watchID := chi.URLParam(r, "watch_id")
	out, err := h.Svc.ListWatchChannels(r.Context(), watchID)
	if err != nil {
		writeErr(w, "INTERNAL", err.Error(), http.StatusInternalServerError, nil)
		return
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *Handler) unsubscribe(w http.ResponseWriter, r *http.Request) {
	watchID := chi.URLParam(r, "watch_id")
	channelUUID := chi.URLParam(r, "channel_uuid")
	if watchID == "" || channelUUID == "" {
		writeErr(w, ErrCodeBadInput, "watch_id & channel_uuid required", http.StatusBadRequest, nil)
		return
	}
	if err := h.Svc.Unsubscribe(r.Context(), watchID, channelUUID); err != nil {
		writeErr(w, "INTERNAL", err.Error(), http.StatusInternalServerError, nil)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type listMediaResp struct {
	Items      []MediaPost `json:"items"`
	NextCursor *string     `json:"next_cursor,omitempty"`
}

func (h *Handler) listMedia(w http.ResponseWriter, r *http.Request) {
	watchID := chi.URLParam(r, "watch_id")
	q := r.URL.Query()

	limit := 20
	if v := q.Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			limit = n
		}
	}
	var cursor *string
	if c := q.Get("cursor"); c != "" {
		cursor = &c
	}

	items, next, err := h.Svc.ListMedia(r.Context(), watchID, limit, cursor)
	if err != nil {
		writeErr(w, "INTERNAL", err.Error(), http.StatusInternalServerError, nil)
		return
	}
	writeJSON(w, http.StatusOK, &listMediaResp{Items: items, NextCursor: next})
}
