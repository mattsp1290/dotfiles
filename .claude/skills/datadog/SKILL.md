---
name: datadog
description: Query Datadog metrics, logs, traces, monitors, and infrastructure using the pup CLI
user-invocable: true
allowed-tools: Bash
---

# Datadog / pup Skill

You are an expert at querying Datadog using the `pup` CLI. Understand what the user wants to investigate, pick the right pup subcommand, construct the query, run it, and interpret the results.

## Running pup

**Always** use the org flag with pup. Our options are prod or staging.

```
$HOME/git/pup/target/release/pup --org 'prod'
```

Agent mode is auto-detected inside Claude Code — confirmations are auto-approved and output defaults to JSON.

## Subcommand reference

| Domain | Subcommands |
|--------|-------------|
| Metrics | `metrics query`, `metrics list`, `metrics metadata get` |
| Logs | `logs search`, `logs query`, `logs list`, `logs aggregate` |
| Traces | `traces search`, `traces list` |
| Monitors | `monitors list`, `monitors get`, `monitors search` |
| Dashboards | `dashboards list`, `dashboards get` |
| Infrastructure | `infrastructure` |
| Events | `events list`, `events search` |
| APM services | `apm services list` |
| SLOs | `slos list`, `slos get`, `slos history` |
| Incidents | `incidents list`, `incidents get`, `incidents timeline` |
| RUM | `rum apps list`, `rum events search`, `rum aggregate` |
| Security | `security rules list`, `security signals list` |

## Query syntax

### Metrics

```
<aggregation>:<metric_name>{<filter>} by {<group>}
```

Aggregations: `avg`, `sum`, `min`, `max`, `count`.

Examples:
```
avg:system.cpu.user{*}                          # All hosts
avg:system.cpu.user{env:prod} by {host}         # By host, prod only
sum:trace.servlet.request.hits{service:web}     # Request count
max:system.mem.used{*} by {host}                # Max memory by host
avg:system.cpu.user{host:spark-fabe}            # Specific host
```

Always include `{...}` filter — use `{*}` for "all".

### Logs

```
status:error                    # By status
service:web-app                 # By service
@user.id:12345                  # Custom attribute
host:i-*                        # Wildcard
"exact error message"           # Exact phrase
status:error AND service:web    # Boolean AND
status:error OR status:warn     # Boolean OR
NOT status:info                 # Negation
-status:info                    # Shorthand negation
```

Storage tiers: `indexes` (default), `online-archives`, `flex`. Use `--storage=flex` for older data (>30d).

### Traces / APM

```
service:<name>                  # By service
resource_name:<path>            # By endpoint
@duration:>5000000000           # Duration > 5s
status:error                    # Errors only
operation_name:rack.request     # By operation
env:production                  # By environment
```

**CRITICAL: APM durations are in NANOSECONDS.**
- 1 ms = 1,000,000 ns
- 1 s = 1,000,000,000 ns
- 5 s = 5,000,000,000 ns

## Defaults and output

- Always use `--from=1h` unless the user specifies a different time range.
- Use `--output=json` when you need to parse or filter results programmatically.
- Use `--output=table` when displaying results directly to the user.
- Default to `--output=table` for user-facing queries.

## Time range formats

| Format | Example |
|--------|---------|
| Relative short | `1h`, `30m`, `7d`, `5s` |
| Relative long | `5min`, `2hours`, `3days` |
| RFC3339 | `2024-01-01T00:00:00Z` |
| Keyword | `now` |

## Best practices

1. **Use aggregate for counting** — use `logs aggregate` with `--compute` and `--group-by` instead of searching and counting locally.
2. **Be specific with time ranges** — always pass `--from`. Smaller windows are faster and cheaper.
3. **Filter at the API level** — use query filters and `--tags` rather than fetching everything and filtering locally.
4. **Use `--limit`** — default is 50; increase up to 1000 when needed, but don't over-fetch.
5. **Supported compute functions** for aggregation: `count`, `avg`, `sum`, `min`, `max`, `cardinality`, `percentile`.

## Anti-patterns

- **Don't** search all logs and count locally — use `logs aggregate`.
- **Don't** omit `--from` — queries without time bounds are slow and may time out.
- **Don't** forget nanoseconds for APM duration filters.
- **Don't** use `--output=json` for direct display — use `--output=table`.

## Error handling

| Status | Meaning | Action |
|--------|---------|--------|
| 401 | Auth failed | Run `$/git/pup/target/release/pup auth login --org 'prod'` |
| 403 | Insufficient permissions | Check API/App key permissions |
| 404 | Not found | Verify the resource ID or name |
| 429 | Rate limited | Wait and retry |
