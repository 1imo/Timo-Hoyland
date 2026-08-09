package bgservices

import (
	"context"
	"log"
	"time"

	ingest "timohoyland.co.uk/use-cases/broadcast-svc-ingest"
	"timohoyland.co.uk/utils"
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

	errCh := make(chan error, 1)
	go func() {
		for {
			payload, err := l.Redis.BRPopQueue(ctx, l.Project)
			if err != nil {
				errCh <- err
				return
			}
			if err := l.Ingest.HandlePayload(ctx, payload); err != nil {
				log.Printf("broadcast job: %v", err)
				continue
			}
			log.Printf("ingested article from broadcast queue project=%s", l.Project)
		}
	}()

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
			if err := l.TouchPresence(ctx); err != nil {
				log.Printf("presence refresh: %v", err)
			}
		case err := <-errCh:
			return err
		}
	}
}
