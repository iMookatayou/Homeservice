package stocks

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
)

type Handler struct {
	SVC *Service
}

func RegisterRoutes(r chi.Router, h *Handler) {
	r.Route("/api/v1/stocks", func(r chi.Router) {
		r.Get("/watch", h.listWatch)
		r.Post("/watch", h.createWatch)
		r.Patch("/watch/{id}", h.updateWatch)
		r.Delete("/watch/{id}", h.deleteWatch)

		r.Get("/quote", h.getQuote)
		r.Get("/quotes:batch", h.batchQuotes)

		// compile error
		r.Post("/watch/{id}/snapshots", h.createSnapshot)
		r.Get("/watch/{id}/snapshots", h.listSnapshots)
	})
}

func (h *Handler) createWatch(w http.ResponseWriter, r *http.Request) {
	var p CreateWatchPayload
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		http.Error(w, err.Error(), 400)
		return
	}
	userID := r.Header.Get("X-Debug-User")       // TODO: ดึงจาก auth/context ของคุณ
	householdID := r.Header.Get("X-Debug-House") // "
	res, err := h.SVC.AddWatch(r.Context(), userID, householdID, p)
	if err != nil {
		http.Error(w, err.Error(), 400)
		return
	}
	writeJSON(w, 201, res)
}

func (h *Handler) listWatch(w http.ResponseWriter, r *http.Request) {
	// TODO: เรียก repo.ListWatch จริง ๆ
	writeJSON(w, 200, map[string]any{"items": []any{}})
}

func (h *Handler) updateWatch(w http.ResponseWriter, r *http.Request) { w.WriteHeader(204) }
func (h *Handler) deleteWatch(w http.ResponseWriter, r *http.Request) { w.WriteHeader(204) }

func (h *Handler) getQuote(w http.ResponseWriter, r *http.Request) {
	ex := r.URL.Query().Get("exchange")
	sym := r.URL.Query().Get("symbol")
	if ex == "" || sym == "" {
		http.Error(w, "missing symbol/exchange", 400)
		return
	}

	q, err := h.SVC.GetLatestQuote(r.Context(), ex, sym)
	if err != nil {
		http.Error(w, err.Error(), 404)
		return
	}
	writeJSON(w, 200, q)
}

func (h *Handler) batchQuotes(w http.ResponseWriter, r *http.Request) {
	raw := r.URL.Query().Get("symbols") // eg "SET:CK,SET:PTT"
	if raw == "" {
		writeJSON(w, 200, BatchQuotesResponse{Items: []QuoteResponse{}, FetchedAt: time.Now()})
		return
	}
	parts := strings.Split(raw, ",")
	var pairs [][2]string
	for _, p := range parts {
		x := strings.SplitN(p, ":", 2)
		if len(x) != 2 {
			continue
		}
		pairs = append(pairs, [2]string{x[0], x[1]})
	}
	resp, _ := h.SVC.GetBatchQuotes(r.Context(), pairs)
	writeJSON(w, 200, resp)
}

// ------- เมธอดที่หายไป (ใส่กลับมาให้) -------
func (h *Handler) createSnapshot(w http.ResponseWriter, r *http.Request) {
	var p CreateSnapshotPayload
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		http.Error(w, err.Error(), 400)
		return
	}
	watchID := chi.URLParam(r, "id")
	ss, err := h.SVC.AddSnapshot(r.Context(), watchID, p)
	if err != nil {
		http.Error(w, err.Error(), 400)
		return
	}
	writeJSON(w, 201, ss)
}

func (h *Handler) listSnapshots(w http.ResponseWriter, r *http.Request) {
	// TODO: ใช้ repo.ListSnapshots จริง ๆ
	writeJSON(w, 200, map[string]any{"items": []any{}})
}

// ------- helper สำหรับเขียน JSON (ถ้าอยากใช้ของโปรเจกต์เดิมแทน ให้เรียก internal/httpx.JSON) -------
func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}
