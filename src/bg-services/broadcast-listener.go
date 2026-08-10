package bgservices

import (
	"context"
	"log/slog"
	"time"

	ingest "timohoyland.co.uk/use-cases/broadcast-svc-ingest"
	"timohoyland.co.uk/utils"
	"timohoyland.co.uk/utils/telemetry"

	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/metric"
)

// BroadcastListener drains the broadcast-svc Redis queue and refreshes presence.
type BroadcastListener struct {
	Redis   *utils.Redis
	Ingest  *ingest.UseCase
	Project string
}

func NewBroadcastListener(rdb *utils.Redis, ingestUC *ingest.UseCase, project string) *BroadcastListener {
	return &BroadcastListener{Redis: rdb, Ingest: ingestUC, Project: project}
}

func (l *BroadcastListener) TouchPresence(ctx context.Context) error {
	return l.Redis.TouchPresence(ctx, l.Project)
}

// Run blocks: presence on boot + every 24h, BRPOP loop for jobs.
func (l *BroadcastListener) Run(ctx context.Context) error {
	if err := l.TouchPresence(ctx); err != nil {
		return err
	}
	ticker := time.NewTicker(24 * time.Hour)
	defer ticker.Stop()

	tracer := telemetry.Tracer("timohoyland.co.uk/broadcast")
	meter := telemetry.Meter("timohoyland.co.uk/broadcast")
	ingested, _ := meter.Int64Counter("broadcast.articles_ingested")

	errCh := make(chan error, 1)
	go func() {
		for {
			payload, err := l.Redis.BRPopQueue(ctx, l.Project)
			if err != nil {
				errCh <- err
				return
			}
			jobCtx, span := tracer.Start(ctx, "broadcast.ingest")
			span.SetAttributes(attribute.String("project", l.Project))
			if err := l.Ingest.HandlePayload(jobCtx, payload); err != nil {
				span.RecordError(err)
				span.SetStatus(codes.Error, err.Error())
				span.End()
				slog.Error("broadcast job", "project", l.Project, "err", err)
				continue
			}
			if ingested != nil {
				ingested.Add(jobCtx, 1, metric.WithAttributes(attribute.String("project", l.Project)))
			}
			span.End()
			slog.Info("ingested article from broadcast queue", "project", l.Project)
		}
	}()

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
			if err := l.TouchPresence(ctx); err != nil {
				slog.Error("presence refresh", "err", err)
			}
		case err := <-errCh:
			return err
		}
	}
}
