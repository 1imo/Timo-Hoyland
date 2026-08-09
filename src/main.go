package main

import (
	"context"
	"log"
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

	"github.com/redis/go-redis/v9"
)

func main() {
	cfg, err := utils.LoadConfig()
	if err != nil {
		log.Fatalf("config: %v", err)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	db, err := utils.OpenPostgres(ctx, cfg.DBURL)
	if err != nil {
		log.Fatalf("postgres: %v", err)
	}
	defer db.Close()

	var rdb *utils.Redis
	var rateClient *redis.Client
	if cfg.RedisURL != "" {
		rdb, err = utils.OpenRedis(ctx, cfg.RedisURL)
		if err != nil {
			log.Fatalf("redis: %v", err)
		}
		defer func() { _ = rdb.Close() }()
		rateClient = rdb.Client
	}

	articles := view.NewArticles(db)
	if err := articles.Reload(ctx); err != nil {
		log.Fatalf("load articles: %v", err)
	}

	if rdb != nil {
		ai := utils.NewAIClient(cfg.AIURL, cfg.APIKey, cfg.ModelName)
		keywords, err := ingest.NewKeywords(ai, cfg.AssetsDir)
		if err != nil {
			log.Fatalf("keywords: %v", err)
		}
		htmlRenderer, err := ingest.NewHTMLRenderer(ai, cfg.AssetsDir)
		if err != nil {
			log.Fatalf("html renderer: %v", err)
		}
		listener := bgservices.NewBroadcastListener(
			rdb,
			ingest.New(articles, keywords, htmlRenderer),
			cfg.Project,
		)
		go func() {
			if err := listener.Run(ctx); err != nil && ctx.Err() == nil {
				log.Printf("broadcast listener stopped: %v", err)
			}
		}()
	}

	legals, err := view.LoadLegals(filepath.Join(cfg.AssetsDir, "legals"))
	if err != nil {
		log.Fatalf("legals: %v", err)
	}

	tmpl, textTmpl, err := routes.NewTemplates(cfg.AssetsDir)
	if err != nil {
		log.Fatalf("templates: %v", err)
	}

	site := controllers.NewSiteController(articles, legals, "timohoyland.co.uk")
	views := controllers.NewViewsController(view.NewViews(db, articles))
	handler := middlewares.RateLimit(rateClient, routes.Handler(routes.Deps{
		Site:          site,
		Views:         views,
		Templates:     tmpl,
		TextTemplates: textTmpl,
		BaseURL:       cfg.BaseURL,
	}))

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

	log.Printf("serving env=%s network=%s port=%s articles=%d",
		cfg.Env, utils.Env("NETWORK"), cfg.Port, len(articles.List()))
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("listen: %v", err)
	}
}
