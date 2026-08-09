# Operations

`/cmd` and `/release` are separate — each dotsources only its own `lib/*.ps1` (no cross-imports).

Env template: [`.env.example`](../../.env.example) → `.env.development` / `.env.test` / `.env.live`, plus [`.env.shared.example`](../../.env.shared.example) → `.env.shared` (always loaded by `cmd/lib/Env.ps1`).

Service hosts live in [`settings.cfg`](../../settings.cfg) under `ENDPOINTS.<SERVICE>.<CLUSTER|PUBLIC>`. After env is chosen, cmd asks for `NETWORK` (`cluster`|`public`) and injects the matching URLs into process env (`OPENSEARCH_URL`, `REDIS_URL`, …). `DB_URL` is built by `PostgreSql` from `ENDPOINTS.DB` + `DB_USER` / `DB_PASSWORD` + `{project}-{ENV}`. `apply-env` merges the selected network’s URLs into Vault.

## Apply scripts (`/cmd`)

| Script | Purpose |
|--------|---------|
| `apply-alerts.ps1` | OpenSearch Dashboards + Grafana alert rules |
| `apply-dashboards.ps1` | OpenSearch `{project}-logging` + `{project}-cmd` streams + dashboards |
| `apply-db.ps1` | `assets/db.sql` (creates DB if missing) |
| `apply-articles.ps1` | Seed `assets/articles/*.md` → `article` table (AI keywords via `AI_URL` / `API_KEY` / `MODEL_NAME` in `.env.shared`) |
| `apply-env.ps1` | Push env files → Vault |
| `apply-commit.ps1` | Commit + push to live/test remotes |
| `apply-dns.ps1` | Apply `public.dns.*` A (+ per-site TXT) via Spaceship |
| `apply-google-observability.ps1` | GA4 account/properties + Search Console DNS verify |
| `apply-synth-monitoring.ps1` | Push HTTPS probe targets → `NottInfra/blackbox-targets` (`https/<project>.json`) |
| `refresh-boilerplate.ps1` | Soft-pull boilerplate updates |

Orchestrators construct `$Env` / `$Project` / `$Settings`, then `$Env.BindConfig($Settings, $Project)` so endpoint URLs are in process env. Libs keep using `$Env.Require('…_URL')`.

## Release pipeline (`/release`)

`build` → `unit-test` → `gitleaks` → `semgrep` → `syft` → `grype` → `trivy` → `sonar` → `push` (live only). Deploy is Watchtower on the IaC host via `compose.yml`.

Finding-producing steps import reports to Defect Dojo and emit summaries to Elasticsearch (`{project}-findings`).

| Lib | Purpose |
|-----|---------|
| `Project.ps1` | `project.yml` parser, `Get('remotes.live')`, pipeline context |
| `Elastic.ps1` | Pipeline step + finding telemetry |
| `DefectDojo.ps1` | Scan import (CI) |
| `Registry.ps1` | Docker build / tag / push |
| `Gitleaks.ps1` | Secrets scan |
| `Semgrep.ps1` | SAST |
| `Syft.ps1` | SBOM (CycloneDX) |
| `Grype.ps1` | SBOM vulnerability scan (after syft) |
| `Trivy.ps1` | Container image scan |
| `Sonar.ps1` | SonarQube |

Scanner images are pinned in each lib class. Scan reports go to `$TMP/release-scan`. Sonar runs via `sonar-scanner` on the runner. Bootstrap Defect Dojo IDs via `./cmd/apply-dashboards.ps1`.
