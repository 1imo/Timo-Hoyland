package telemetry

import (
	"log/slog"
	"os"
)

// InitLogger configures structured JSON logging to stdout.
func InitLogger() {
	handler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo})
	slog.SetDefault(slog.New(handler))
}
