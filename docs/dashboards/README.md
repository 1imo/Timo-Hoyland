# Dashboards

Source files under `dashboards/` — one file per dashboard, grouped by platform:

```
dashboards/
  grafana/
    metrics.json
    synthetic-monitoring.json
  opensearch/
    logging.ndjson
```

Applied via `./cmd/apply-dashboards.ps1`.

Each dashboard is scoped to the project from `project.cfg`:

| Platform | Naming |
|----------|--------|
| Grafana | folder `{project}/{slug}`, dashboard `{project} / {slug} ({ENV})` |
| OpenSearch Dashboards | title `{project} / {slug}` |
