package main

import (
	"context"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/yourname/homeservice-backend/internal/auth"
	"github.com/yourname/homeservice-backend/internal/config"
	"github.com/yourname/homeservice-backend/internal/db"
	"github.com/yourname/homeservice-backend/internal/health"
	"github.com/yourname/homeservice-backend/internal/httpx"
	"github.com/yourname/homeservice-backend/internal/notes"
	"github.com/yourname/homeservice-backend/internal/user"
	"github.com/yourname/homeservice-backend/internal/weather"
	"go.uber.org/zap"
)

func main() {
	cfg := config.Load()
	logger, _ := zap.NewProduction()
	defer logger.Sync()

	ctx := context.Background()
	pool, err := db.Connect(ctx, cfg.DSN)
	if err != nil {
		logger.Fatal("db connect", zap.Error(err))
	}
	defer pool.Close()

	uRepo := user.Repo{DB: pool}
	uHandler := user.Handler{Repo: uRepo, JWTSecret: cfg.JWTSecret}

	nRepo := notes.Repo{DB: pool}
	nHandler := notes.Handler{Repo: nRepo}

	wHandler := weather.Handler{}

	r := chi.NewRouter()
	for _, m := range httpx.CommonMiddlewares(cfg.CorsOrigin) {
		r.Use(m)
	}

	r.Get("/healthz", health.Live)
	r.Get("/readyz", health.Ready)
	r.Route("/api/v1", func(api chi.Router) {
		api.Post("/auth/register", uHandler.Register)
		api.Post("/auth/login", uHandler.Login)
		api.Get("/weather/today", wHandler.Today)
		api.Group(func(pr chi.Router) {
			pr.Use(auth.RequireAuth(cfg.JWTSecret, auth.NewClaims))
			pr.Get("/me", uHandler.Me)
			nHandler.RegisterRoutes(pr)
		})
	})

	srv := &http.Server{
		Addr:              ":" + cfg.AppPort,
		Handler:           r,
		ReadHeaderTimeout: 10 * time.Second,
	}
	logger.Info("listening", zap.String("addr", srv.Addr))
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		logger.Fatal("server", zap.Error(err))
	}
}
