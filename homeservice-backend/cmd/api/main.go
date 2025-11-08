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

	"github.com/iMookatayou/homeservice-backend/internal/bills"
	"github.com/iMookatayou/homeservice-backend/internal/contractors"
	"github.com/iMookatayou/homeservice-backend/internal/files"
	"github.com/iMookatayou/homeservice-backend/internal/medicine"
	"github.com/iMookatayou/homeservice-backend/internal/purchases"
	"github.com/iMookatayou/homeservice-backend/internal/stocks"
	"github.com/iMookatayou/homeservice-backend/internal/storage"

	"github.com/iMookatayou/homeservice-backend/internal/media"
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

	st := storage.New(cfg)
	fRepo := files.Repo{DB: pool}
	fHandler := files.Handler{Repo: fRepo, Storage: st, JWTSecret: cfg.JWTSecret}

	pRepo := purchases.NewRepo(pool)
	pSvc := purchases.NewService(pRepo)
	pHandler := purchases.Handler{Svc: pSvc}
	pRegistrar := purchases.Registrar{H: pHandler}

	httpClient := &http.Client{Timeout: 15 * time.Second}
	ctrRepo := contractors.NewRepo(10 * time.Minute)          
	ctrSvc := contractors.NewService(httpClient, ctrRepo, "") 
	ctrH := contractors.Handler{Svc: ctrSvc}

	bRepo := bills.Repo{DB: pool}
	bSvc := bills.NewService(bRepo)
	bHandler := bills.Handler{Svc: bSvc}
	bRegistrar := bills.Registrar{H: bHandler}

	stkRepo := stocks.NewPgRepo(pool)
	stkSvc := &stocks.Service{
		Repo:       stkRepo,
		Prov:       stocks.NewMockProvider(), 
		StaleAfter: 3 * time.Minute,
	}

	mRepo := medicine.NewPGRepo(pool)
	mSvc := &medicine.Service{Repo: mRepo, Now: time.Now}

	// --- media (YouTube RSS -> media_posts) ---
	// ใช้ *pgx.Conn เดี่ยวจาก pool สำหรับ API repo (ถ้า constructor ต้องการ Conn)
	acqMedia, err := pool.Acquire(ctx)
	if err != nil {
		logger.Fatal("acquire media conn", zap.Error(err))
	}
	defer acqMedia.Release()

	// Repo สำหรับ API (implements media.Repo)
	mdRepo := media.NewPGRepo(acqMedia.Conn())
	mdSvc := media.NewService(mdRepo)
	mdH := media.NewHandler(mdSvc)

	// WorkerRepo สำหรับ RSS worker (ใช้ *pgxpool.Pool)
	wRepo := media.NewWorkerRepo(pool)

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

			// purchases
			pRegistrar.Register(pr)

			// bills
			bRegistrar.Register(pr)

			// stocks
			stocks.RegisterRoutes(pr, &stocks.Handler{SVC: stkSvc})

			// medicine
			pr.Route("/medicine", func(r chi.Router) {
				medicine.MountHTTP(r, mSvc)
			})

			// media (จะได้ /api/v1/media/...)
			mdH.Mount(pr)
		})

		// --- admin-only (reserved) ---
		api.Group(func(ad chi.Router) {
			ad.Use(auth.RequireAdmin(cfg.JWTSecret, auth.NewClaims))
		})
	})

	// (optional) debug: dump all routes at startup
	_ = chi.Walk(r, func(method, route string, _ http.Handler, _ ...func(http.Handler) http.Handler) error {
		logger.Info("route", zap.String("method", method), zap.String("path", route))
		return nil
	})

	// quotes worker (mock)
	go func() {
		_ = (&stocks.QuotesWorker{
			Repo:  stkSvc.Repo,
			Prov:  stkSvc.Prov,
			Every: 5 * time.Second,
		}).Run(context.Background())
	}()

	// Media RSS worker — ใช้ WorkerRepo ใหม่
	go func() {
		worker := media.NewRSSWorker(wRepo, 3*time.Minute, 5*time.Second, 100)
		_ = worker.Run(context.Background())
	}()

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
