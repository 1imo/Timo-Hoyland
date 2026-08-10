package middlewares

import (
	"net/http"

	"timohoyland.co.uk/utils/telemetry"

	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
)

// Tracing starts an OTel span per request and counts HTTP hits.
func Tracing(next http.Handler) http.Handler {
	tracer := telemetry.Tracer("timohoyland.co.uk/http")
	meter := telemetry.Meter("timohoyland.co.uk/http")
	requests, _ := meter.Int64Counter(
		"http.server.requests",
		metric.WithDescription("HTTP requests handled"),
	)

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx, span := tracer.Start(r.Context(), r.Method+" "+r.URL.Path)
		defer span.End()
		span.SetAttributes(
			attribute.String("http.host", r.Host),
			attribute.String("http.method", r.Method),
			attribute.String("http.route", r.URL.Path),
		)
		if requests != nil {
			requests.Add(ctx, 1,
				metric.WithAttributes(
					attribute.String("http.method", r.Method),
					attribute.String("http.route", r.URL.Path),
				),
			)
		}
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
