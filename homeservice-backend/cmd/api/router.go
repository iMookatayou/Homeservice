package main

import (
	"log"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"

	"github.com/iMookatayou/homeservice-backend/internal/purchases"
	"github.com/iMookatayou/homeservice-backend/internal/stocks"
)

type Deps struct {
	PurchasesSvc *purchases.Service
	StocksSvc    *stocks.Service
}

func NewRouter(deps Deps) http.Handler {
	r := chi.NewRouter()

	// Middlewares
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Logger)
	r.Use(middleware.Timeout(30 * time.Second))
	r.Use(middleware.RedirectSlashes) // normalize / กับ ไม่มี /

	// health
	r.Get("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	// API v1 (ครอบที่นี่ที่เดียว)
	r.Route("/api/v1", func(r chi.Router) {
		purchases.Registrar{
			H: purchases.Handler{Svc: deps.PurchasesSvc},
		}.Register(r)

		stocks.RegisterRoutes(r, &stocks.Handler{SVC: deps.StocksSvc})
	})

	// DEBUG: พิมพ์ route ทั้งหมด (ช่วยไล่ 404)
	_ = chi.Walk(r, func(method, route string, _ http.Handler, _ ...func(http.Handler) http.Handler) error {
		log.Printf("%s %s", method, route)
		return nil
	})

	return r
}
