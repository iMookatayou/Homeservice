package main

import (
	"context"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"go.uber.org/zap"

	"github.com/iMookatayou/homeservice-backend/internal/auth"
	"github.com/iMookatayou/homeservice-backend/internal/config"
	"github.com/iMookatayou/homeservice-backend/internal/db"
	"github.com/iMookatayou/homeservice-backend/internal/health"
	"github.com/iMookatayou/homeservice-backend/internal/httpx"
	"github.com/iMookatayou/homeservice-backend/internal/notes"
	"github.com/iMookatayou/homeservice-backend/internal/user"
	"github.com/iMookatayou/homeservice-backend/internal/weather"

	// new modules
	"github.com/iMookatayou/homeservice-backend/internal/bills"
	"github.com/iMookatayou/homeservice-backend/internal/contractors"
	"github.com/iMookatayou/homeservice-backend/internal/files"
	"github.com/iMookatayou/homeservice-backend/internal/purchases"
	"github.com/iMookatayou/homeservice-backend/internal/storage"
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

	// --- users/auth ---
	uRepo := user.Repo{DB: pool}
	uHandler := user.Handler{Repo: uRepo, JWTSecret: cfg.JWTSecret}

	// --- notes ---
	nRepo := notes.Repo{DB: pool}
	nHandler := notes.Handler{Repo: nRepo}

	// --- weather (stateless) ---
	wHandler := weather.Handler{}

	// --- storage/files ---
	st := storage.New(cfg)
	fRepo := files.Repo{DB: pool}
	fHandler := files.Handler{Repo: fRepo, Storage: st, JWTSecret: cfg.JWTSecret}

	// --- purchases (ใหม่: repo + service + registrar เดียว) ---
	pRepo := purchases.NewRepo(pool)
	pSvc := purchases.NewService(pRepo)
	pHandler := purchases.Handler{Svc: pSvc}
	pRegistrar := purchases.Registrar{H: pHandler}

	// --- contractors (Overpass API, no map SDK) ---
	httpClient := &http.Client{Timeout: 15 * time.Second}
	ctrRepo := contractors.NewRepo(10 * time.Minute)          // in-memory cache
	ctrSvc := contractors.NewService(httpClient, ctrRepo, "") // default Overpass endpoint
	ctrH := contractors.Handler{Svc: ctrSvc}

	// --- bills ---
	bRepo := bills.Repo{DB: pool}
	bSvc := bills.NewService(bRepo)
	bHandler := bills.Handler{Svc: bSvc}
	bRegistrar := bills.Registrar{H: bHandler}

	// --- router & middlewares ---
	r := chi.NewRouter()
	for _, m := range httpx.CommonMiddlewares(cfg.CorsOrigin) {
		r.Use(m)
	}

	// serve local uploads (dev only)
	if cfg.StorageBackend == "local" && cfg.LocalDir != "" {
		fs := http.StripPrefix("/static/", http.FileServer(http.Dir(cfg.LocalDir)))
		r.Handle("/static/*", fs)
	}

	// health
	r.Get("/healthz", health.Live)
	r.Get("/readyz", health.Ready)

	// API v1
	r.Route("/api/v1", func(api chi.Router) {
		// --- public ---
		api.Post("/auth/register", uHandler.Register)
		api.Post("/auth/login", uHandler.Login)
		api.Get("/weather/today", wHandler.Today)

		// contractors search (public)
		ctrH.RegisterRoutes(api)

		// --- auth-required ---
		api.Group(func(pr chi.Router) {
			pr.Use(auth.RequireAuth(cfg.JWTSecret, auth.NewClaims))
			pr.Get("/me", uHandler.Me)

			nHandler.RegisterRoutes(pr)
			fHandler.RegisterRoutes(pr)

			// purchases (ทั้งหมดอยู่ใน handler เดียว)
			pRegistrar.Register(pr)

			// bills
			bRegistrar.Register(pr)
		})

		// --- admin-only (ถ้ามี endpoint เฉพาะ admin ในอนาคต คุมด้วย middleware นี้) ---
		api.Group(func(ad chi.Router) {
			ad.Use(auth.RequireAdmin(cfg.JWTSecret, auth.NewClaims))
			// ปัจจุบัน purchases ไม่มี admin handler แยกแล้ว
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
