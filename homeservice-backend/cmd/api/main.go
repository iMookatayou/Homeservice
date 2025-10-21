package main

import (
	"context"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"go.uber.org/zap"

	"github.com/yourname/homeservice-backend/internal/auth"
	"github.com/yourname/homeservice-backend/internal/config"
	"github.com/yourname/homeservice-backend/internal/db"
	"github.com/yourname/homeservice-backend/internal/health"
	"github.com/yourname/homeservice-backend/internal/httpx"
	"github.com/yourname/homeservice-backend/internal/notes"
	"github.com/yourname/homeservice-backend/internal/user"
	"github.com/yourname/homeservice-backend/internal/weather"

	// new
	"github.com/yourname/homeservice-backend/internal/files"
	"github.com/yourname/homeservice-backend/internal/purchases"
	"github.com/yourname/homeservice-backend/internal/storage"
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

	// storage & new modules
	st := storage.New(cfg)

	fRepo := files.Repo{DB: pool}
	fHandler := files.Handler{Repo: fRepo, Storage: st, JWTSecret: cfg.JWTSecret}

	attRepo := purchases.AttachRepo{DB: pool}
	attHandler := purchases.AttachHandler{Repo: attRepo, JWTSecret: cfg.JWTSecret}

	adminRepo := purchases.AdminRepo{DB: pool}
	adminHandler := purchases.AdminHandler{Repo: adminRepo, JWTSecret: cfg.JWTSecret}

	r := chi.NewRouter()
	for _, m := range httpx.CommonMiddlewares(cfg.CorsOrigin) {
		r.Use(m)
	}

	// serve local uploads (dev only)
	if cfg.StorageBackend == "local" && cfg.LocalDir != "" {
		fs := http.StripPrefix("/static/", http.FileServer(http.Dir(cfg.LocalDir)))
		r.Handle("/static/*", fs)
	}

	r.Get("/healthz", health.Live)
	r.Get("/readyz", health.Ready)

	r.Route("/api/v1", func(api chi.Router) {
		// public
		api.Post("/auth/register", uHandler.Register)
		api.Post("/auth/login", uHandler.Login)
		api.Get("/weather/today", wHandler.Today)

		// auth-required
		api.Group(func(pr chi.Router) {
			pr.Use(auth.RequireAuth(cfg.JWTSecret, auth.NewClaims))
			pr.Get("/me", uHandler.Me)

			nHandler.RegisterRoutes(pr)

			// uploads/files
			fHandler.RegisterRoutes(pr)

			// purchases attachments
			attHandler.RegisterRoutes(pr)
		})

		// admin-only
		api.Group(func(ad chi.Router) {
			ad.Use(auth.RequireAdmin(cfg.JWTSecret, auth.NewClaims))
			adminHandler.RegisterRoutes(ad)
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
