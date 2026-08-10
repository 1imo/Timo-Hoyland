package telemetry

import (
	"context"
	"fmt"
	"os"
	"strings"
	"time"

	"timohoyland.co.uk/utils"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
)

// Provider holds OTel providers for graceful shutdown.
type Provider struct {
	Tracer *sdktrace.TracerProvider
	Meter  *sdkmetric.MeterProvider
}

// Setup initialises tracing + metrics from OTEL_* in loaded config/env.
// Empty OTEL_URL → JSON logger only (safe local default).
func Setup(ctx context.Context, serviceName string) (*Provider, error) {
	otelURL := os.Getenv("OTEL_URL")
	otelHeaders := os.Getenv("OTEL_HEADERS")
	if utils.C != nil {
		if otelURL == "" {
			otelURL = utils.C.OTELURL
		}
		if otelHeaders == "" {
			otelHeaders = utils.C.OTELHeaders
		}
	}

	if strings.TrimSpace(otelURL) == "" {
		InitLogger()
		return &Provider{}, nil
	}

	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName(serviceName),
			semconv.DeploymentEnvironment(firstNonEmpty(os.Getenv("ENV"), "development")),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("otel resource: %w", err)
	}

	headers := parseHeaders(otelHeaders)
	endpoint, insecure := normalizeOTLPEndpoint(otelURL)

	tp, err := newTracerProvider(ctx, res, endpoint, insecure, headers)
	if err != nil {
		return nil, err
	}
	mp, err := newMeterProvider(ctx, res, endpoint, insecure, headers)
	if err != nil {
		_ = tp.Shutdown(ctx)
		return nil, err
	}

	otel.SetTracerProvider(tp)
	otel.SetMeterProvider(mp)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	InitLogger()

	return &Provider{Tracer: tp, Meter: mp}, nil
}

// Shutdown flushes and closes providers.
func (p *Provider) Shutdown(ctx context.Context) error {
	if p == nil {
		return nil
	}
	var first error
	if p.Meter != nil {
		if err := p.Meter.Shutdown(ctx); err != nil && first == nil {
			first = err
		}
	}
	if p.Tracer != nil {
		if err := p.Tracer.Shutdown(ctx); err != nil && first == nil {
			first = err
		}
	}
	return first
}

func newTracerProvider(ctx context.Context, res *resource.Resource, endpoint string, insecure bool, headers map[string]string) (*sdktrace.TracerProvider, error) {
	opts := []otlptracehttp.Option{
		otlptracehttp.WithEndpoint(endpoint),
		otlptracehttp.WithHeaders(headers),
	}
	if insecure {
		opts = append(opts, otlptracehttp.WithInsecure())
	}
	exp, err := otlptracehttp.New(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("otel trace exporter: %w", err)
	}
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exp),
		sdktrace.WithResource(res),
	)
	return tp, nil
}

func newMeterProvider(ctx context.Context, res *resource.Resource, endpoint string, insecure bool, headers map[string]string) (*sdkmetric.MeterProvider, error) {
	opts := []otlpmetrichttp.Option{
		otlpmetrichttp.WithEndpoint(endpoint),
		otlpmetrichttp.WithHeaders(headers),
	}
	if insecure {
		opts = append(opts, otlpmetrichttp.WithInsecure())
	}
	exp, err := otlpmetrichttp.New(ctx, opts...)
	if err != nil {
		return nil, fmt.Errorf("otel metric exporter: %w", err)
	}
	mp := sdkmetric.NewMeterProvider(
		sdkmetric.WithReader(sdkmetric.NewPeriodicReader(exp, sdkmetric.WithInterval(30*time.Second))),
		sdkmetric.WithResource(res),
	)
	return mp, nil
}

func normalizeOTLPEndpoint(raw string) (hostPort string, insecure bool) {
	raw = strings.TrimSpace(raw)
	insecure = strings.HasPrefix(raw, "http://")
	raw = strings.TrimPrefix(raw, "https://")
	raw = strings.TrimPrefix(raw, "http://")
	raw = strings.TrimSuffix(raw, "/")
	if i := strings.Index(raw, "/"); i >= 0 {
		raw = raw[:i]
	}
	return raw, insecure
}

func parseHeaders(raw string) map[string]string {
	out := map[string]string{}
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return out
	}
	for _, part := range strings.Split(raw, ",") {
		part = strings.TrimSpace(part)
		key, val, ok := strings.Cut(part, "=")
		if !ok {
			continue
		}
		out[strings.TrimSpace(key)] = strings.TrimSpace(val)
	}
	return out
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return strings.TrimSpace(v)
		}
	}
	return ""
}
