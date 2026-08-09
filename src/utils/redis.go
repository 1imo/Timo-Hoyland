package utils

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

const (
	PresenceKeyPrefix = "broadcast:services:"
	PresenceTTL       = 48 * time.Hour
)

type Redis struct {
	Client *redis.Client
}

func OpenRedis(ctx context.Context, redisURL string) (*Redis, error) {
	if redisURL == "" {
		return nil, fmt.Errorf("REDIS_URL is required")
	}
	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		return nil, fmt.Errorf("parse REDIS_URL: %w", err)
	}
	client := redis.NewClient(opt)
	if err := client.Ping(ctx).Err(); err != nil {
		_ = client.Close()
		return nil, err
	}
	return &Redis{Client: client}, nil
}

func (r *Redis) Close() error {
	if r == nil || r.Client == nil {
		return nil
	}
	return r.Client.Close()
}

func PresenceKey(project string) string {
	return PresenceKeyPrefix + project
}

// QueueKey is the bare project name (LPUSH/BRPOP target from broadcast-svc).
func QueueKey(project string) string {
	return project
}

// TouchPresence refreshes broadcast:services:{project} with a 48h TTL.
func (r *Redis) TouchPresence(ctx context.Context, project string) error {
	if project == "" {
		return fmt.Errorf("project name required")
	}
	return r.Client.Set(ctx, PresenceKey(project), "1", PresenceTTL).Err()
}

// BRPopQueue blocks until a payload is available on the project list.
func (r *Redis) BRPopQueue(ctx context.Context, project string) (string, error) {
	res, err := r.Client.BRPop(ctx, 0, QueueKey(project)).Result()
	if err != nil {
		return "", err
	}
	if len(res) < 2 {
		return "", fmt.Errorf("unexpected BRPOP result for %s", project)
	}
	return res[1], nil
}
