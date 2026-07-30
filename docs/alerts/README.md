# Alerting

Source files in `alerts/`:

- `opensearch.json` — OpenSearch Alerting **monitors** (`_plugins/_alerting/monitors`)
- `grafana.json` — Grafana alerting rules (optional; skipped if missing)

Applied via `./cmd/apply-alerts.ps1`.

Placeholders in `opensearch.json`: `__ENV__`, `__PROJECT__`.

## Pipeline failures

CI steps emit documents to `{project}-pipeline` in OpenSearch when configured (`event: pipeline_step`, `pipeline.status: failed`). Finding steps also write to `{project}-findings` (`event: pipeline_finding`).

## Unsigned settings.cfg

`Config` throws `[!] UNSIGNED_SETTINGS_CFG: …` when the pin/digest check fails. Apply catch blocks match that message and call `Step(..., 'failed', @{ event = 'unsigned_settings_cfg'; ... })`; other failures use a normal failed step (no alert event).
