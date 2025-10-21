package bills

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/yourname/homeservice-backend/internal/auth"
	"github.com/yourname/homeservice-backend/internal/httpx"
)

type Handler struct {
	Repo Repo
}

func (h Handler) RegisterRoutes(r chi.Router) {
	r.Route("/bills", func(r chi.Router) {
		r.Post("/", h.Create)      // POST /api/v1/bills
		r.Post("/{id}/pay", h.Pay) // POST /api/v1/bills/{id}/pay
		r.Get("/", h.List)         // GET  /api/v1/bills?limit=20
	})
}

func (h Handler) Create(w http.ResponseWriter, r *http.Request) {
	var req CreateBillReq
	if err := httpx.BindJSON(r, &req); err != nil {
		httpx.WriteJSONError(w, http.StatusBadRequest, "validation failed", httpx.ValidationErrors(err))
		return
	}
	claims := auth.ClaimsFrom(r)
	if claims == nil {
		httpx.WriteJSONError(w, http.StatusUnauthorized, "unauthorized", nil)
		return
	}

	var due, ps, pe *time.Time
	parseDate := func(s *string) *time.Time {
		if s == nil || *s == "" {
			return nil
		}
		// รองรับทั้ง date และ datetime
		if t, err := time.Parse(time.RFC3339, *s); err == nil {
			return &t
		}
		if d, err := time.Parse("2006-01-02", *s); err == nil {
			return &d
		}
		return nil
	}
	due = parseDate(req.DueDate)
	ps = parseDate(req.PeriodStart)
	pe = parseDate(req.PeriodEnd)

	b := &Bill{
		Type:               req.Type,
		Title:              req.Title,
		Amount:             req.Amount,
		BillingPeriodStart: ps,
		BillingPeriodEnd:   pe,
		DueDate:            due,
		Note:               req.Note,
		CreatedBy:          claims.UserID,
	}
	if err := h.Repo.Create(r.Context(), b); err != nil {
		httpx.WriteJSONError(w, http.StatusInternalServerError, err.Error(), nil)
		return
	}
	httpx.JSON(w, http.StatusCreated, b)
}

func (h Handler) Pay(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	b, err := h.Repo.MarkPaid(r.Context(), id)
	if err != nil {
		httpx.WriteJSONError(w, http.StatusBadRequest, err.Error(), nil)
		return
	}
	httpx.JSON(w, http.StatusOK, b)
}

func (h Handler) List(w http.ResponseWriter, r *http.Request) {
	bs, err := h.Repo.List(r.Context(), 50)
	if err != nil {
		httpx.WriteJSONError(w, http.StatusInternalServerError, err.Error(), nil)
		return
	}
	httpx.JSON(w, http.StatusOK, bs)
}
