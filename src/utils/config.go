package utils

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// C is the process-wide config set by LoadConfig.
var C *Config

// Config is the runtime application configuration.
type Config struct {
	Env                     string
	Port                    string
	BaseURL                 string
	DBURL                   string
	RedisURL                string
	Project                 string
	MatomoURL               string
	MatomoSiteID            string
	GA4MeasurementID        string
	OpenReplayIngestURL     string
	OpenReplayProjectKey    string
	OpenReplayScriptURL     string
	AIURL                   string
	APIKey                  string
	ModelName               string
	OTELURL                 string
	OTELHeaders             string
	AssetsDir               string
	RateLimitRPM            int
	ProjectRoot             string
	OpenReplayDisableSecure bool
}

// LoadConfig loads dotenv + ENDPOINTS, then fills C.
func LoadConfig() (*Config, error) {
	root, err := LoadDotEnv()
	if err != nil {
		return nil, err
	}
	if err := resolveEndpointEnv(root, "MATOMO"); err != nil {
		return nil, err
	}
	if err := resolveEndpointEnv(root, "OPENREPLAY"); err != nil {
		return nil, err
	}
	if err := resolveEndpointEnv(root, "OTEL"); err != nil {
		return nil, err
	}

	cfg := &Config{
		Env:      firstNonEmpty(Env("ENV"), "development"),
		Port:     firstNonEmpty(Env("PORT"), "8080"),
		BaseURL:  strings.TrimRight(firstNonEmpty(Env("BASE_URL"), "https://timohoyland.co.uk"), "/"),
		DBURL:    Env("DB_URL"),
		RedisURL: Env("REDIS_URL"),
		Project:  ProjectName(),
		MatomoURL: browserFacingURL(firstNonEmpty(
			Env("MATOMO_URL_PUBLIC"),
			Env("MATOMO_URL"),
		)),
		MatomoSiteID: Env("MATOMO_SITE_ID"),
		GA4MeasurementID: firstNonEmpty(
			Env("GA4_MEASUREMENT_ID"),
			Env("GTAG_ID"),
		),
		OpenReplayIngestURL: normalizeOpenReplayIngest(browserFacingURL(firstNonEmpty(
			Env("OPENREPLAY_URL_PUBLIC"),
			Env("OPENREPLAY_INGEST_URL_PUBLIC"),
			Env("OPENREPLAY_URL"),
			Env("OPENREPLAY_INGEST_URL"),
		))),
		OpenReplayProjectKey: Env("OPENREPLAY_PROJECT_KEY"),
		OpenReplayScriptURL: firstNonEmpty(
			Env("OPENREPLAY_SCRIPT_URL"),
			"https://static.openreplay.com/18.0.17/openreplay.js",
		),
		AIURL:     strings.TrimRight(Env("AI_URL"), "/"),
		APIKey:    Env("API_KEY"),
		ModelName: firstNonEmpty(Env("MODEL_NAME"), "gpt-4.1-mini"),
		OTELURL: firstNonEmpty(
			Env("OTEL_URL"),
			Env("OTEL_URL_PUBLIC"),
		),
		OTELHeaders:             Env("OTEL_HEADERS"),
		AssetsDir:               AssetsDir(),
		RateLimitRPM:            parseIntDefault(Env("RATE_LIMIT_RPM"), 120),
		ProjectRoot:             root,
		OpenReplayDisableSecure: strings.EqualFold(firstNonEmpty(Env("ENV"), "development"), "development"),
	}
	if !filepath.IsAbs(cfg.AssetsDir) {
		cfg.AssetsDir = filepath.Clean(filepath.Join(root, cfg.AssetsDir))
	}
	if cfg.DBURL == "" {
		return nil, fmt.Errorf("DB_URL is required")
	}
	if cfg.Project == "" {
		return nil, fmt.Errorf("PROJECT / project.cfg name is required")
	}
	C = cfg
	return cfg, nil
}

func resolveEndpointEnv(root, service string) error {
	envKey := strings.ToUpper(service) + "_URL"
	if Env(envKey) != "" {
		return nil
	}
	network := strings.ToLower(firstNonEmpty(Env("NETWORK"), "public"))
	endpoint, err := readEndpoint(filepath.Join(root, "settings.cfg"), service, network)
	if err != nil {
		// Optional for local boot without settings.cfg
		if os.IsNotExist(err) || strings.Contains(err.Error(), "missing") {
			return nil
		}
		return err
	}
	_ = os.Setenv(envKey, endpoint)
	return nil
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return strings.TrimSpace(v)
		}
	}
	return ""
}

func browserFacingURL(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}
	if strings.Contains(strings.ToLower(raw), ".svc.cluster.local") {
		return ""
	}
	return raw
}

func normalizeOpenReplayIngest(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}
	raw = strings.TrimRight(raw, "/")
	if strings.HasSuffix(raw, "/ingest") {
		return raw
	}
	return raw + "/ingest"
}

func parseIntDefault(raw string, fallback int) int {
	if raw == "" {
		return fallback
	}
	n, err := strconv.Atoi(raw)
	if err != nil || n <= 0 {
		return fallback
	}
	return n
}
