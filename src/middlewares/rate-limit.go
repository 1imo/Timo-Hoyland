package middlewares

import (
	"fmt"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"timohoyland.co.uk/utils"

	"github.com/redis/go-redis/v9"
)

// RateLimit wraps next with a per-IP requests-per-minute cap (RATE_LIMIT_RPM).
func RateLimit(rdb *redis.Client, next http.Handler) http.Handler {
	rpm := 120
	if utils.C != nil && utils.C.RateLimitRPM > 0 {
		rpm = utils.C.RateLimitRPM
	}
	mem := newMemoryLimiter(rpm)

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ip := clientIP(r)
		allowed := true
		if rdb != nil {
			key := fmt.Sprintf("ratelimit:%s:%d", ip, time.Now().UTC().Unix()/60)
			n, err := rdb.Incr(r.Context(), key).Result()
			if err == nil {
				if n == 1 {
					_ = rdb.Expire(r.Context(), key, 2*time.Minute).Err()
				}
				allowed = n <= int64(rpm)
			} else {
				allowed = mem.allow(ip)
			}
		} else {
			allowed = mem.allow(ip)
		}
		if !allowed {
			http.Error(w, "rate limit exceeded", http.StatusTooManyRequests)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func clientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		parts := strings.Split(xff, ",")
		return strings.TrimSpace(parts[0])
	}
	if xri := r.Header.Get("X-Real-IP"); xri != "" {
		return strings.TrimSpace(xri)
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

type memoryLimiter struct {
	mu      sync.Mutex
	rpm     int
	windows map[string]int
	minute  int64
}

func newMemoryLimiter(rpm int) *memoryLimiter {
	return &memoryLimiter{rpm: rpm, windows: map[string]int{}}
}

func (m *memoryLimiter) allow(ip string) bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	now := time.Now().UTC().Unix() / 60
	if now != m.minute {
		m.minute = now
		m.windows = map[string]int{}
	}
	m.windows[ip]++
	return m.windows[ip] <= m.rpm
}
