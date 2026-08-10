package telemetry

import (
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/metric"
)

// Meter returns a named meter from the global provider.
func Meter(name string) metric.Meter {
	return otel.Meter(name)
}
