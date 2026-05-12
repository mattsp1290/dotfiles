# Recreating the Dart Integration Tests

## What you are building

Three Dart test files under `sdks/community/dart/test/integration/` that exercise the Dart SDK against a live dojo server (see `dockerfile-recreate.md` for how to stand one up). Together they contain **58 tests** and run in ~19s end-to-end.

| File | Tests | Purpose |
|------|-------|---------|
| `dojo_smoke_test.dart` | 7 | Live HTTP/SSE against all 6 dojo endpoints; lifecycle invariants. |
| `dojo_new_events_decode_test.dart` | 40 | Offline decoder/stream-adapter coverage for the 9 event types added on the `1018/fix-missing-event-types` branch. |
| `dojo_resilience_test.dart` | 11 | Cancellation, validation rejections, 404, timeouts. Uses an in-process slow server for timeout coverage. |

## Prerequisites

1. The Dart SDK package at `sdks/community/dart/` must have its dependencies installed: `cd sdks/community/dart && dart pub get`.
2. For `dojo_smoke_test.dart` and the dojo-gated resilience tests, a dojo container must be running. Standing up the new image:
   ```bash
   docker run --rm -d --name ag-ui-server-probe -p 18000:8000 ag-ui-protocol/ag-ui-server:dev
   ```
3. Confirm reachability before running tests: `curl -sS -m 5 http://localhost:18000/openapi.json -o /dev/null -w "HTTP %{http_code}\n"` should print `HTTP 200`.

## Steps

For each file, copy the template verbatim:

```bash
cp $HOME/.claude/skills/ag-ui-dojo-recreate/templates/dojo_smoke_test.dart \
   sdks/community/dart/test/integration/dojo_smoke_test.dart
cp $HOME/.claude/skills/ag-ui-dojo-recreate/templates/dojo_new_events_decode_test.dart \
   sdks/community/dart/test/integration/dojo_new_events_decode_test.dart
cp $HOME/.claude/skills/ag-ui-dojo-recreate/templates/dojo_resilience_test.dart \
   sdks/community/dart/test/integration/dojo_resilience_test.dart
```

Then verify:

```bash
cd sdks/community/dart
dart analyze test/integration/dojo_smoke_test.dart \
             test/integration/dojo_new_events_decode_test.dart \
             test/integration/dojo_resilience_test.dart   # expect 0 errors
AGUI_DOJO_BASE_URL=http://127.0.0.1:18000 dart test \
  test/integration/dojo_smoke_test.dart \
  test/integration/dojo_new_events_decode_test.dart \
  test/integration/dojo_resilience_test.dart --reporter expanded
```

Expected: `+58: All tests passed!` in roughly 19 seconds.

## Env vars consumed by the tests

| Var | Purpose | Default |
|-----|---------|---------|
| `AGUI_DOJO_BASE_URL` | Preferred base URL for live-dojo tests. | falls through to `AGUI_BASE_URL` |
| `AGUI_BASE_URL` | Secondary base URL (shared with other integration tests). | falls through to `http://127.0.0.1:18000` |
| `AGUI_SKIP_DOJO` | When `1`, skip all live-dojo tests. | unset |

These are read by helpers `_dojoBaseUrl()` and `_skipDojo()` defined in `dojo_smoke_test.dart` and duplicated in `dojo_resilience_test.dart`. If you regenerate from scratch on a future branch, keep the precedence order — other tooling depends on it.

## Per-file structure

### `dojo_smoke_test.dart`

Top-level helpers (verbatim in template):

- `_dojoBaseUrl()` — env-var precedence chain.
- `_skipDojo()` — opt-out flag.
- `_dojoReachable(baseUrl)` — short-circuit probe that GETs `/openapi.json` with a 2s connect + 3s read timeout. Surfaces a clear skip message instead of a buried `TransportError`.
- `_assertLifecycleInvariants(events, input)` — exactly-one RUN_STARTED, exactly-one RUN_FINISHED, RUN_FINISHED is last event, no RUN_ERROR, threadId/runId echo on both bookends.
- `_assertToolCallGrouping(events)` — for endpoints that stream TOOL_CALL events, partitions by `toolCallId`, asserts each group is `START → ARGS* → END`, and rejects cross-id interleave.

Tests:

1. `agentic_chat` — countdown text stream; asserts one TEXT_MESSAGE_{START,END} pair, all CONTENT deltas share the messageId, accumulated body contains `"counting down"`.
2. `tool_based_generative_ui` — MESSAGES_SNAPSHOT containing an AssistantMessage with a `generate_haiku` tool call.
3. `agentic_generative_ui` — STATE_SNAPSHOT → multiple STATE_DELTAs (each a non-empty list of RFC 6902 patch ops with valid `op` and non-empty `path`) → STATE_SNAPSHOT.
4. `shared_state` — STATE_SNAPSHOT with a Map payload (no deltas observed from this dojo image).
5. `predictive_state_updates` — CUSTOM(PredictState) hint + 2 TOOL_CALL groups, validated by `_assertToolCallGrouping`.
6. `human_in_the_loop` — single TOOL_CALL group named `generate_task_steps`.
7. Offline smoke — all 9 #1018 wire names round-trip through `EventType.fromString`.

**Critical:** the assertions in tests 3–6 are based on **what the dojo actually emits** (probed via curl during authoring), not what the AG-UI protocol theory says. See [`dojo-endpoint-behaviors.md`](dojo-endpoint-behaviors.md) for the observed-behavior table. Do NOT rewrite to match a spec doc — the live server is ground truth.

### `dojo_new_events_decode_test.dart`

Pure decoder/stream-adapter test. **Does not need the dojo running.** Lives in the `integration/` directory only because it tests integration-layer types (decoder + stream adapter together).

Pattern mirrors `event_decoding_integration_test.dart`:

```dart
import 'package:ag_ui/src/encoder/decoder.dart';
import 'package:ag_ui/src/encoder/stream_adapter.dart';
import 'package:ag_ui/src/events/events.dart';
import 'package:test/test.dart';
```

For each of the 9 event types it asserts:

1. **Direct decode** — `decoder.decodeJson({'type': '<WIRE_NAME>', ...})` returns the right subclass.
2. **Snake_case parity** — same payload with `message_id` instead of `messageId` decodes successfully.
3. **toJson round-trip** — decode → toJson → decode again, fields equal.
4. **Stream-adapter path** — at minimum for `REASONING_MESSAGE_*`, the START/CONTENT/END triplet sharing a messageId pumps through `EventStreamAdapter.adaptJsonToEvents` correctly.

If you regenerate this file on a future branch where new event types have been added, follow the same four-axis pattern per new event class.

### `dojo_resilience_test.dart`

Mixes dojo-gated tests (4 of 11) with offline tests (7 of 11). Each test is annotated with whether it needs the dojo.

| Test | Needs dojo? | Assertion |
|------|-------------|-----------|
| 404 on unknown endpoint | Yes | `TransportError(statusCode: 404)` |
| 422 on malformed payload | Skipped with TODO | The Dart typed API makes 422 unreachable through the public surface — see [`dart-sdk-quirks.md`](dart-sdk-quirks.md). |
| Mid-stream cancellation | Yes | `client.cancelRun(runId)` terminates the stream cleanly; `_requestTokens` is cleared. |
| Duplicate runId | No (uses hanging in-process server) | `ValidationError(constraint: 'unique-in-flight')` surfaces *through the stream*, not synchronously. See quirks doc. |
| Empty endpoint | No | `ValidationError` from `Validators.validateUrl`/`requireNonEmpty`. |
| Empty message.id | No | `ValidationError(field: 'message.id')`. |
| Duplicate message.id | No | `ValidationError(constraint: 'unique-id')`. |
| Duplicate toolCall.id | No | `ValidationError(constraint: 'unique-within-message')`. |
| Oversized runId | No | `ValidationError`. |
| `close()` idempotency | No | Second call doesn't throw. |
| Timeout via slow server | No (in-process HttpServer) | `AGUITimeoutError`, `operation` contains the URL. |

The in-process slow server is `HttpServer.bind(InternetAddress.loopbackIPv4, 0)` that accepts but never writes. Wrap usage in `try { ... } finally { await server.close(force: true); }` — leaking it leaks a Dart isolate listener.

## If the Dart SDK has shifted

Symptoms that the SDK has refactored and the templates are stale:

- `dart analyze` reports unknown types like `ReasoningMessageStartEvent` → the branch may have renamed the classes. Search: `grep -rn 'class Reasoning' lib/`.
- `client.runAgenticChat(input)` doesn't exist → convenience methods were removed; fall back to `client.runAgent('agentic_chat', input)`.
- `SimpleRunAgentInput` doesn't exist → the input wrapper was renamed. Search: `grep -rn 'class.*RunAgentInput' lib/`.

In any of these cases, read the current `lib/src/client/client.dart` and adjust the templates' API calls. Keep the assertions intact — the protocol invariants don't change with API renames.

## If the dojo has shifted

If endpoint paths change or new endpoints are added, **always re-probe with curl before adjusting assertions**:

```bash
curl -sS -m 15 -N -X POST http://localhost:18000/<endpoint> \
  -H 'Content-Type: application/json' \
  -H 'Accept: text/event-stream' \
  -d '{"threadId":"t","runId":"r","state":{},"messages":[{"id":"m1","role":"user","content":"hi"}],"tools":[],"context":[],"forwardedProps":{}}'
```

Update [`dojo-endpoint-behaviors.md`](dojo-endpoint-behaviors.md) with what you observe so the next agent doesn't have to re-discover.
