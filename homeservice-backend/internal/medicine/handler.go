package medicine

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/iMookatayou/homeservice-backend/internal/httpx"
)

func MountHTTP(r chi.Router, svc *Service) {
	h := &Handler{svc: svc}

	r.Get("/", h.listItems)
	r.Post("/", h.createItem)
	r.Get("/{id}", h.getItem)
	r.Patch("/{id}", h.updateItem)
	r.Delete("/{id}", h.archiveItem)

	r.Route("/{id}/batches", func(r chi.Router) {
		r.Post("/", h.addBatch)
		r.Get("/", h.listBatches)
	})

	r.Route("/{id}/txns", func(r chi.Router) {
		r.Post("/in", h.receiveIn)
		r.Post("/out", h.useOut)
		r.Post("/adjust", h.adjust)
	})

	r.Route("/{id}/alert", func(r chi.Router) {
		r.Put("/", h.setAlert)
		r.Get("/", h.getAlert)
	})

	r.Get("/locations", h.listLocations)
	r.Post("/locations", h.createLocation)
}

type Handler struct {
	svc *Service
}

func (h *Handler) listItems(w http.ResponseWriter, r *http.Request) {
	householdID := r.Header.Get("X-Debug-Household")
	f := ListItemFilter{
		Query:        r.URL.Query().Get("q"),
		Category:     r.URL.Query().Get("category"),
		Form:         r.URL.Query().Get("form"),
		LocationID:   r.URL.Query().Get("location_id"),
		OnlyLow:      r.URL.Query().Get("only_low") == "1",
		OnlyExpiring: r.URL.Query().Get("only_expiring") == "1",
		Sort:         r.URL.Query().Get("sort"),
	}

	items, err := h.svc.ListItems(r.Context(), householdID, f)
	if err != nil {
		httpx.JSON(w, 500, map[string]any{"error": err.Error()})
		return
	}
	httpx.JSON(w, 200, items)
}

func (h *Handler) createItem(w http.ResponseWriter, r *http.Request) {
	householdID := r.Header.Get("X-Debug-Household")
	var it MedicineItem
	if err := httpx.BindJSON(r, &it); err != nil {
		httpx.JSON(w, 400, map[string]any{"error": "invalid JSON"})
		return
	}
	it.ID = uuid.NewString()
	it.HouseholdID = householdID

	if err := h.svc.CreateItem(r.Context(), &it); err != nil {
		httpx.JSON(w, 400, map[string]any{"error": err.Error()})
		return
	}
	httpx.JSON(w, 201, it)
}

func (h *Handler) getItem(w http.ResponseWriter, r *http.Request) {
	householdID := r.Header.Get("X-Debug-Household")
	id := chi.URLParam(r, "id")

	item, err := h.svc.GetItemFull(r.Context(), householdID, id)
	if err != nil {
		code := 500
		if err == ErrNotFound {
			code = 404
		}
		httpx.JSON(w, code, map[string]any{"error": err.Error()})
		return
	}
	httpx.JSON(w, 200, item)
}

func (h *Handler) updateItem(w http.ResponseWriter, r *http.Request) {
	householdID := r.Header.Get("X-Debug-Household")
	id := chi.URLParam(r, "id")
	var patch map[string]any
	if err := httpx.BindJSON(r, &patch); err != nil {
		httpx.JSON(w, 400, map[string]any{"error": "invalid JSON"})
		return
	}
	if err := h.svc.UpdateItemPartial(r.Context(), householdID, id, patch); err != nil {
		httpx.JSON(w, 400, map[string]any{"error": err.Error()})
		return
	}
	httpx.JSON(w, 200, map[string]any{"updated": true})
}

func (h *Handler) archiveItem(w http.ResponseWriter, r *http.Request) {
	householdID := r.Header.Get("X-Debug-Household")
	id := chi.URLParam(r, "id")
	if err := h.svc.ArchiveItem(r.Context(), householdID, id); err != nil {
		httpx.JSON(w, 400, map[string]any{"error": err.Error()})
		return
	}
	httpx.JSON(w, 200, map[string]any{"archived": true})
}

// ------------------- Batch -------------------

func (h *Handler) addBatch(w http.ResponseWriter, r *http.Request) {
	householdID := r.Header.Get("X-Debug-Household")
	itemID := chi.URLParam(r, "id")
	var b MedicineBatch
	if err := httpx.BindJSON(r, &b); err != nil {
		httpx.JSON(w, 400, map[string]any{"error": "invalid JSON"})
		return
	}
	b.ID = uuid.NewString()
	b.ItemID = itemID
	if err := h.svc.AddBatch(r.Context(), householdID, &b); err != nil {
		httpx.JSON(w, 400, map[string]any{"error": err.Error()})
		return
	}
	httpx.JSON(w, 201, b)
}

func (h *Handler) listBatches(w http.ResponseWriter, r *http.Request) {
	itemID := chi.URLParam(r, "id")
	bs, err := h.svc.Repo.GetBatchesByItem(r.Context(), itemID)
	if err != nil {
		httpx.JSON(w, 500, map[string]any{"error": err.Error()})
		return
	}
	httpx.JSON(w, 200, bs)
}

// ------------------- Transactions -------------------

func (h *Handler) receiveIn(w http.ResponseWriter, r *http.Request) {
	itemID := chi.URLParam(r, "id")
	var payload struct {
		BatchID string  `json:"batch_id"`
		Qty     float64 `json:"qty"`
		Reason  *string `json:"reason"`
		Actor   string  `json:"actor_user_id"`
	}
	if err := httpx.BindJSON(r, &payload); err != nil {
		httpx.JSON(w, 400, map[string]any{"error": "invalid JSON"})
		return
	}
	res, err := h.svc.ReceiveIn(r.Context(), itemID, payload.BatchID, payload.Qty, payload.Reason, payload.Actor)
	if err != nil {
		httpx.JSON(w, 400, map[string]any{"error": err.Error()})
		return
	}
	httpx.JSON(w, 200, res)
}

func (h *Handler) useOut(w http.ResponseWriter, r *http.Request) {
	itemID := chi.URLParam(r, "id")
	var payload struct {
		Qty    float64 `json:"qty"`
		Reason *string `json:"reason"`
		Actor  string  `json:"actor_user_id"`
	}
	if err := httpx.BindJSON(r, &payload); err != nil {
		httpx.JSON(w, 400, map[string]any{"error": "invalid JSON"})
		return
	}
	res, err := h.svc.UseOut(r.Context(), itemID, payload.Qty, payload.Reason, payload.Actor)
	if err != nil {
		httpx.JSON(w, 400, map[string]any{"error": err.Error()})
		return
	}
	httpx.JSON(w, 200, res)
}

func (h *Handler) adjust(w http.ResponseWriter, r *http.Request) {
	itemID := chi.URLParam(r, "id")
	var payload struct {
		BatchID string  `json:"batch_id"`
		Delta   float64 `json:"delta"`
		Reason  *string `json:"reason"`
		Actor   string  `json:"actor_user_id"`
	}
	if err := httpx.BindJSON(r, &payload); err != nil {
		httpx.JSON(w, 400, map[string]any{"error": "invalid JSON"})
		return
	}
	res, err := h.svc.Adjust(r.Context(), itemID, payload.BatchID, payload.Delta, payload.Reason, payload.Actor)
	if err != nil {
		httpx.JSON(w, 400, map[string]any{"error": err.Error()})
		return
	}
	httpx.JSON(w, 200, res)
}

// ------------------- Alerts -------------------

func (h *Handler) setAlert(w http.ResponseWriter, r *http.Request) {
	itemID := chi.URLParam(r, "id")
	var payload struct {
		MinQty     *float64 `json:"min_qty"`
		ExpiryDays *int     `json:"expiry_window_days"`
		IsEnabled  *bool    `json:"is_enabled"`
	}
	if err := httpx.BindJSON(r, &payload); err != nil {
		httpx.JSON(w, 400, map[string]any{"error": "invalid JSON"})
		return
	}
	if err := h.svc.SetAlert(r.Context(), itemID, payload.MinQty, payload.ExpiryDays, payload.IsEnabled); err != nil {
		httpx.JSON(w, 400, map[string]any{"error": err.Error()})
		return
	}
	httpx.JSON(w, 200, map[string]any{"updated": true})
}

func (h *Handler) getAlert(w http.ResponseWriter, r *http.Request) {
	itemID := chi.URLParam(r, "id")
	al, err := h.svc.Repo.GetAlert(r.Context(), itemID)
	if err != nil {
		httpx.JSON(w, 400, map[string]any{"error": err.Error()})
		return
	}
	httpx.JSON(w, 200, al)
}

// ------------------- Locations -------------------

func (h *Handler) listLocations(w http.ResponseWriter, r *http.Request) {
	householdID := r.Header.Get("X-Debug-Household")
	locs, err := h.svc.Repo.ListLocations(r.Context(), householdID)
	if err != nil {
		httpx.JSON(w, 400, map[string]any{"error": err.Error()})
		return
	}
	httpx.JSON(w, 200, locs)
}

func (h *Handler) createLocation(w http.ResponseWriter, r *http.Request) {
	householdID := r.Header.Get("X-Debug-Household")
	var loc MedicineLocation
	if err := httpx.BindJSON(r, &loc); err != nil {
		httpx.JSON(w, 400, map[string]any{"error": "invalid JSON"})
		return
	}
	loc.ID = uuid.NewString()
	loc.HouseholdID = householdID
	if err := h.svc.Repo.CreateLocation(r.Context(), &loc); err != nil {
		httpx.JSON(w, 400, map[string]any{"error": err.Error()})
		return
	}
	httpx.JSON(w, 201, loc)
}
