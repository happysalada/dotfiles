# Log dashboards (Perses)

One dashboard per unit or service that writes logs here, each a full-width
`LogsTable` panel over `opentelemetry_logs`, scoped to a one-hour window that
the dashboard's own time picker drives.

| file | shows |
| --- | --- |
| `logs-fundies-server.json` | the fundies server instances (OTLP, `service.name=fundies-server`) |
| `logs-fundies-pipeline.json` | the rolling pipeline |
| `logs-fundies-frontend.json` | the frontend (bun) |
| `logs-fundies-house.json` | the house job |
| `logs-greptimedb.json` | greptimedb itself |
| `logs-otel-collector.json` | the collector, including its scraper errors |
| `logs-redis-openpanel.json` | the OpenPanel redis |
| `logs-user-session.json` | your own session: sudo, dbus, portals |

## Getting them in

The Visualization tab imports a Perses dashboard by paste or `.json` upload
(Create → Import), and it stores it through greptimedb's `/v1/dashboards`
API. Those routes are behind the `dashboard` cargo feature, which this
nixpkgs build does not enable, so import fails on save until greptimedb is
built with it.

Once it is, either import them by hand or:

```sh
nu dashboards/perses/import.nu --dry-run   # what would be sent
nu dashboards/perses/import.nu             # POST each to /v1/dashboards/<name>
```

## How a dashboard queries

`GreptimeDBLogQuery` takes one SQL string (plus the datasource kind), and the
plugin substitutes `$__from` / `$__to` with the panel's time range in epoch
milliseconds. The log panel needs the result to carry a timestamp column, and
it renders every other column as `column=value` on the entry. Hence:

```sql
SELECT timestamp, severity_text,
  coalesce(nullif(json_get_string(log_attributes, '_SYSTEMD_UNIT'), ''),
           json_get_string(resource_attributes, '$."service.name"')) AS source,
  json_get_string(log_attributes, 'SYSLOG_IDENTIFIER') AS ident,
  json_get_string(log_attributes, '_PID') AS pid,
  body
FROM opentelemetry_logs
WHERE coalesce(nullif(json_get_string(log_attributes, '_SYSTEMD_UNIT'), ''),
               json_get_string(resource_attributes, '$."service.name"')) = 'greptimedb.service'
  AND timestamp BETWEEN to_timestamp_millis($__from) AND to_timestamp_millis($__to)
ORDER BY timestamp DESC
LIMIT 1000
```

Two things that are easy to get wrong, both learned the hard way:

- **The coalesce is what makes one query cover both kinds of row.** Journald
  entries identify by `log_attributes._SYSTEMD_UNIT`; the services that export
  their own OTLP identify by `resource_attributes["service.name"]`.
- **Dotted attribute keys need a quoted JSON path.** `json_get_string(…, 'service.name')`
  is read as a nested path and silently returns empty; `'$."service.name"'` is
  the literal key.

`LIMIT 1000` matches the plugin's own example; the frontend alone emits far
more than that per hour, so shorten the window or raise the limit there.
