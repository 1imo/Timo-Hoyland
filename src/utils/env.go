package utils

import (
	"bufio"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"strings"
)

func Env(key string) string {
	return strings.TrimSpace(os.Getenv(key))
}

func RequireEnv(key string) string {
	v := Env(key)
	if v == "" {
		panic(key + " is required")
	}
	return v
}

// LoadDotEnv loads env in order (existing process env wins):
//  1. Vault Agent Injector file (VAULT_AGENT_ENV_FILE or /vault/secrets/app)
//  2. .env.shared + .env.{ENV|development} from the repo root (local)
//
// then builds DB_URL like cmd/lib/PostgreSql.ps1 when unset.
func LoadDotEnv() (root string, err error) {
	root, err = findRepoRoot()
	if err != nil {
		return "", err
	}

	agent := Env("VAULT_AGENT_ENV_FILE")
	if agent == "" {
		agent = "/vault/secrets/app"
	}
	if err := loadEnvFile(agent, false); err != nil && !os.IsNotExist(err) {
		return root, fmt.Errorf("load %s: %w", agent, err)
	}

	shared := filepath.Join(root, ".env.shared")
	if err := loadEnvFile(shared, false); err != nil && !os.IsNotExist(err) {
		return root, fmt.Errorf("load %s: %w", shared, err)
	}

	name := Env("ENV")
	if name == "" {
		name = "development"
		_ = os.Setenv("ENV", name)
	}
	envFile := filepath.Join(root, ".env."+name)
	if err := loadEnvFile(envFile, false); err != nil && !os.IsNotExist(err) {
		return root, fmt.Errorf("load %s: %w", envFile, err)
	}

	if _, err := resolveDBURL(root); err != nil {
		return root, err
	}
	// Redis is optional for HTTP-only boots; broadcast + distributed rate limit need it.
	_, _ = resolveRedisURL(root)
	if Env("PROJECT") == "" {
		if name, err := readProjectName(filepath.Join(root, "project.cfg")); err == nil {
			_ = os.Setenv("PROJECT", name)
		}
	}
	return root, nil
}

// ProjectName is project.cfg → project (also used as broadcast-svc queue / presence suffix).
func ProjectName() string {
	if v := Env("PROJECT"); v != "" {
		return v
	}
	return ""
}

// resolveDBURL: ENDPOINTS.DB.{CLUSTER|PUBLIC} + DB_USER/DB_PASSWORD + {project}-{ENV}.
func resolveDBURL(root string) (string, error) {
	if v := Env("DB_URL"); v != "" {
		return v, nil
	}

	user := Env("DB_USER")
	pass := Env("DB_PASSWORD")
	if user == "" || pass == "" {
		return "", fmt.Errorf("DB_USER and DB_PASSWORD required to build DB_URL")
	}

	envName := Env("ENV")
	if envName == "" || envName == "shared" {
		return "", fmt.Errorf("ENV required to build DB_URL (development, test, or live)")
	}

	network := strings.ToLower(Env("NETWORK"))
	if network == "" {
		network = "public"
		_ = os.Setenv("NETWORK", network)
	}
	if network != "cluster" && network != "public" {
		return "", fmt.Errorf("NETWORK must be cluster or public (got %s)", network)
	}

	project, err := readProjectName(filepath.Join(root, "project.cfg"))
	if err != nil {
		return "", err
	}
	endpoint, err := readEndpoint(filepath.Join(root, "settings.cfg"), "DB", network)
	if err != nil {
		return "", err
	}

	u, err := url.Parse(endpoint)
	if err != nil {
		return "", fmt.Errorf("invalid DB endpoint: %w", err)
	}
	if u.Scheme != "postgresql" && u.Scheme != "postgres" {
		return "", fmt.Errorf("invalid DB endpoint (expected postgresql://host[:port]): %s", endpoint)
	}
	if strings.Trim(u.Path, "/") != "" {
		return "", fmt.Errorf("DB endpoint must be host-only (no database path): %s", endpoint)
	}
	u.User = url.UserPassword(user, pass)
	u.Path = "/" + project + "-" + envName
	built := u.String()
	_ = os.Setenv("DB_URL", built)
	return built, nil
}

func readProjectName(path string) (string, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("read project.cfg: %w", err)
	}
	for _, line := range strings.Split(string(b), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, val, ok := strings.Cut(line, ":")
		if !ok || strings.TrimSpace(key) != "project" {
			continue
		}
		name := strings.Trim(strings.TrimSpace(val), `"'`)
		if name == "" {
			return "", fmt.Errorf("project name missing in project.cfg")
		}
		return name, nil
	}
	return "", fmt.Errorf("project name missing in project.cfg")
}

func resolveRedisURL(root string) (string, error) {
	if v := Env("REDIS_URL"); v != "" {
		return v, nil
	}
	network := strings.ToLower(Env("NETWORK"))
	if network == "" {
		network = "public"
	}
	endpoint, err := readEndpoint(filepath.Join(root, "settings.cfg"), "REDIS", network)
	if err != nil {
		return "", err
	}
	_ = os.Setenv("REDIS_URL", endpoint)
	return endpoint, nil
}

func readEndpoint(path, service, network string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", fmt.Errorf("read settings.cfg: %w", err)
	}
	defer f.Close()

	kind := "PUBLIC"
	if network == "cluster" {
		kind = "CLUSTER"
	}
	serviceKey := strings.ToUpper(service) + ":"

	inEndpoints, inService := false, false
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		raw := sc.Text()
		line := strings.TrimSpace(raw)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		indent := len(raw) - len(strings.TrimLeft(raw, " \t"))

		if indent == 0 && strings.HasPrefix(line, "ENDPOINTS:") {
			inEndpoints, inService = true, false
			continue
		}
		if indent == 0 {
			inEndpoints, inService = false, false
			continue
		}
		if !inEndpoints {
			continue
		}
		if indent == 2 && strings.HasPrefix(line, serviceKey) {
			inService = true
			continue
		}
		if indent == 2 {
			inService = false
			continue
		}
		if !inService || indent < 4 {
			continue
		}
		key, val, ok := strings.Cut(line, ":")
		if !ok || strings.TrimSpace(key) != kind {
			continue
		}
		endpoint := strings.Trim(strings.TrimSpace(val), `"'`)
		if endpoint == "" {
			return "", fmt.Errorf("ENDPOINTS.%s.%s missing in settings.cfg", strings.ToUpper(service), kind)
		}
		return endpoint, nil
	}
	if err := sc.Err(); err != nil {
		return "", err
	}
	return "", fmt.Errorf("ENDPOINTS.%s.%s missing in settings.cfg", strings.ToUpper(service), kind)
}

func AssetsDir() string {
	if v := Env("ASSETS_DIR"); v != "" {
		return v
	}
	if root, err := findRepoRoot(); err == nil {
		candidate := filepath.Join(root, "assets")
		if st, err := os.Stat(candidate); err == nil && st.IsDir() {
			return candidate
		}
	}
	for _, candidate := range []string{"assets", "../assets"} {
		if st, err := os.Stat(candidate); err == nil && st.IsDir() {
			return candidate
		}
	}
	return "assets"
}

func findRepoRoot() (string, error) {
	wd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	dir := wd
	for {
		if fileExists(filepath.Join(dir, "project.cfg")) && fileExists(filepath.Join(dir, ".env.shared")) {
			return dir, nil
		}
		if fileExists(filepath.Join(dir, "project.cfg")) && (fileExists(filepath.Join(dir, ".env.development")) || fileExists(filepath.Join(dir, "assets"))) {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return wd, nil
}

func loadEnvFile(path string, override bool) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()

	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, val, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		key = strings.TrimSpace(key)
		val = strings.TrimSpace(val)
		if len(val) >= 2 {
			if (val[0] == '"' && val[len(val)-1] == '"') || (val[0] == '\'' && val[len(val)-1] == '\'') {
				val = val[1 : len(val)-1]
			}
		}
		if key == "" {
			continue
		}
		if !override && os.Getenv(key) != "" {
			continue
		}
		if err := os.Setenv(key, val); err != nil {
			return err
		}
	}
	return sc.Err()
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
