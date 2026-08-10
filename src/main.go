package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	bgservices "timohoyland.co.uk/bg-services"
	"timohoyland.co.uk/controllers"
	"timohoyland.co.uk/middlewares"
	"timohoyland.co.uk/routes"
	ingest "timohoyland.co.uk/use-cases/broadcast-svc-ingest"
	"timohoyland.co.uk/use-cases/view"
	"timohoyland.co.uk/utils"
	"timohoyland.co.uk/utils/telemetry"

	"github.com/redis/go-redis/v9"
)

func main() {
	cfg, err := utils.LoadConfig()
	if err != nil {
		slog.Error("config", "err", err)
		os.Exit(1)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	tel, err := telemetry.Setup(ctx, "timo-hoyland")
	if err != nil {
		slog.Error("telemetry", "err", err)
		os.Exit(1)
	}
	defer func() {
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = tel.Shutdown(shutdownCtx)
	}()

	db, err := utils.OpenPostgres(ctx, cfg.DBURL)
	if err != nil {
		slog.Error("postgres", "err", err)
		os.Exit(1)
	}
	defer db.Close()

	var rdb *utils.Redis
	var rateClient *redis.Client
	if cfg.RedisURL != "" {
		rdb, err = utils.OpenRedis(ctx, cfg.RedisURL)
		if err != nil {
			slog.Error("redis", "err", err)
			os.Exit(1)
		}
		defer func() { _ = rdb.Close() }()
		rateClient = rdb.Client
	}

	articles := view.NewArticles(db)
	if err := articles.Reload(ctx); err != nil {
		slog.Error("load articles", "err", err)
		os.Exit(1)
	}

	if rdb != nil {
		ai := utils.NewAIClient(cfg.AIURL, cfg.APIKey, cfg.ModelName)
		keywords, err := ingest.NewKeywords(ai, cfg.AssetsDir)
		if err != nil {
			slog.Error("keywords", "err", err)
			os.Exit(1)
		}
		htmlRenderer, err := ingest.NewHTMLRenderer(ai, cfg.AssetsDir)
		if err != nil {
			slog.Error("html renderer", "err", err)
			os.Exit(1)
		}
		listener := bgservices.NewBroadcastListener(
			rdb,
			ingest.New(articles, keywords, htmlRenderer),
			cfg.Project,
		)
		go func() {
			if err := listener.Run(ctx); err != nil && ctx.Err() == nil {
				slog.Error("broadcast listener stopped", "err", err)
			}
		}()
	}

	legals, err := view.LoadLegals(filepath.Join(cfg.AssetsDir, "legals"))
	if err != nil {
		slog.Error("legals", "err", err)
		os.Exit(1)
	}

	tmpl, textTmpl, err := routes.NewTemplates(cfg.AssetsDir)
	if err != nil {
		slog.Error("templates", "err", err)
		os.Exit(1)
	}

	site := controllers.NewSiteController(articles, legals, "timohoyland.co.uk")
	views := controllers.NewViewsController(view.NewViews(db, articles))
	handler := middlewares.Tracing(middlewares.RateLimit(rateClient, routes.Handler(routes.Deps{
		Site:          site,
		Views:         views,
		Templates:     tmpl,
		TextTemplates: textTmpl,
		BaseURL:       cfg.BaseURL,
	})))

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           handler,
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		<-ctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		_ = srv.Shutdown(shutdownCtx)
	}()

	slog.Info("serving",
		"env", cfg.Env,
		"network", utils.Env("NETWORK"),
		"port", cfg.Port,
		"articles", len(articles.List()),
	)
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		slog.Error("listen", "err", err)
		os.Exit(1)
	}
}
