# Observed Dojo Endpoint Behaviors

**This document is the single most important thing to read before writing assertions against the dojo.** Theoretical predictions of what each endpoint emits (based on the AG-UI protocol spec or reviewer intuition) were wrong on every endpoint we probed except `agentic_chat` and `tool_based_generative_ui`. The assertions in the test templates reflect *observed* behavior from live curl probes against `ag-ui-protocol/ag-ui-server:dev` (built from the current Python source at `integrations/server-starter-all-features/python/examples/`) as of 2026-05.

## How this was probed

For each endpoint:

```bash
curl -sS -m 15 -N -X POST http://localhost:18000/<endpoint> \
  -H 'Content-Type: application/json' \
  -H 'Accept: text/event-stream' \
  -d '<minimal valid RunAgentInput payload>'
```

A minimal payload that all endpoints accept:

```json
{
  "threadId": "probe",
  "runId": "probe-1",
  "state": {},
  "messages": [{"id": "m1", "role": "user", "content": "hi"}],
  "tools": [],
  "context": [],
  "forwardedProps": {}
}
```

The `tool_based_generative_ui` endpoint additionally needs a `generate_haiku`-shaped tool in `tools[]`.

## Endpoint behavior matrix

### `/agentic_chat`

**Predicted**: text message stream. **Observed**: ✅ matches.

```
RUN_STARTED
TEXT_MESSAGE_START (messageId=M)
TEXT_MESSAGE_CONTENT (messageId=M, delta="counting down: ")
TEXT_MESSAGE_CONTENT (messageId=M, delta="10  ")
TEXT_MESSAGE_CONTENT (messageId=M, delta="9  ")
... (down to "1  ", then "✓")
TEXT_MESSAGE_END (messageId=M)
RUN_FINISHED
```

All CONTENT deltas share the same `messageId` as the START/END. Total duration ~3s (one delta per ~250ms).

### `/tool_based_generative_ui`

**Predicted**: streaming TOOL_CALL_START → ARGS → END. **Observed**: ❌ uses MESSAGES_SNAPSHOT only.

```
RUN_STARTED
MESSAGES_SNAPSHOT (with [user message, assistant message carrying toolCalls=[{name: "generate_haiku", arguments: "{...}"}]])
RUN_FINISHED
```

The assistant's tool call is delivered via the snapshot's `AssistantMessage.toolCalls`, not via streaming TOOL_CALL_* events. Assert against the snapshot's last message's `toolCalls.first.function.name`.

### `/agentic_generative_ui`

**Predicted**: STEP_STARTED / STEP_FINISHED pairing. **Observed**: ❌ no STEP events at all — emits state events.

```
RUN_STARTED
STATE_SNAPSHOT (initial state)
STATE_DELTA (1 patch op)
STATE_DELTA (1 patch op)
... (~10 deltas total, one per step in the long-running task)
STATE_SNAPSHOT (final state)
RUN_FINISHED
```

Each STATE_DELTA carries a list of RFC 6902 JSON Patch ops. Each op has:
- `op` ∈ `{add, replace, remove, move, copy, test}`
- `path` (non-empty string starting with `/`)
- `value` (for add/replace/test)
- `from` (for move/copy)

**Assertion to use**: any delta is a non-empty `List`, every op has a valid `op` and non-empty `path`. Do NOT assert STEP_STARTED/STEP_FINISHED — they don't exist on this endpoint.

### `/shared_state`

**Predicted**: STATE_SNAPSHOT + STATE_DELTA stream. **Observed**: ❌ STATE_SNAPSHOT only — zero deltas.

```
RUN_STARTED
STATE_SNAPSHOT (Map payload, e.g. {recipe: {...}})
RUN_FINISHED
```

Either the snapshot already contains the final state and no incremental updates are needed, or the long-running update behavior isn't triggered by a single "hi" message. Either way, **do not assert STATE_DELTA presence** on this endpoint — it'll flake. Assert only that STATE_SNAPSHOT exists and `snapshot.snapshot is Map<String, dynamic>`.

### `/predictive_state_updates`

**Predicted**: same as shared_state. **Observed**: ❌ no state events at all — emits a CUSTOM event + tool calls.

```
RUN_STARTED
CUSTOM (name="PredictState", value={...hint about which state path is about to change...})
TOOL_CALL_START (toolCallId=A, name="write_document_local")
TOOL_CALL_ARGS (toolCallId=A, delta="...")
TOOL_CALL_ARGS (toolCallId=A, delta="...")
TOOL_CALL_END (toolCallId=A)
TOOL_CALL_START (toolCallId=B, name="write_document_local")
TOOL_CALL_ARGS (toolCallId=B, delta="...")
TOOL_CALL_END (toolCallId=B)
RUN_FINISHED
```

Two non-interleaved TOOL_CALL groups + a CustomEvent. Assert:
- At least one `CustomEvent` exists (the PredictState hint).
- `_assertToolCallGrouping(events)` passes (groups are clean, no cross-id interleave).

### `/human_in_the_loop`

**Predicted**: MESSAGES_SNAPSHOT with AssistantMessage.toolCalls. **Observed**: ❌ streaming TOOL_CALL group, no snapshot.

```
RUN_STARTED
TOOL_CALL_START (toolCallId=C, name="generate_task_steps")
TOOL_CALL_ARGS (toolCallId=C, delta="...")
TOOL_CALL_ARGS (toolCallId=C, delta="...")
... (several ARGS deltas accumulating a JSON arguments string)
TOOL_CALL_END (toolCallId=C)
RUN_FINISHED
```

Single TOOL_CALL group named `generate_task_steps`. No MESSAGES_SNAPSHOT. Assert:
- At least one `ToolCallStartEvent` with `toolName == 'generate_task_steps'`.
- `_assertToolCallGrouping(events)` passes.

The test template also has a defensive branch that handles `MessagesSnapshotEvent` in case a future image starts emitting it.

### `/backend_tool_rendering`

The seventh endpoint (present in the new `:dev` image build). Not exercised by current tests. If you want to extend coverage, probe with curl first.

## Common payload patterns to remember

- Every endpoint accepts the minimal `{threadId, runId, state, messages, tools, context, forwardedProps}` shape.
- `state: {}` is sufficient even when the server's runtime state schema is more elaborate.
- `forwardedProps: {}` is required — `pydantic` rejects payloads that omit it on at least some endpoints.
- The server returns `text/event-stream` and frames each event as `data: <JSON>\n\n`.

## Wire-format quirks

- Keys are mostly **snake_case** on the wire (`thread_id`, `run_id`, `tool_calls`). The Dart decoder canonicalizes to camelCase. The `dojo_new_events_decode_test.dart` snake_case parity tests guard this surface.
- Empty deltas are valid: `{"type":"TEXT_MESSAGE_CONTENT","messageId":"M","delta":""}` decodes successfully and is canonical per the TS SDK.
- A `data: :` keep-alive sentinel may appear from some servers — both `SseClient` and `EventStreamAdapter.fromSseStream` filter it before JSON-decoding.

## If endpoint behavior changes

When the Python server is updated and starts emitting different events:

1. Re-probe with curl using the payload above.
2. Update the relevant row in this matrix.
3. Update assertions in `dojo_smoke_test.dart`. Keep the lifecycle-invariant helper (`_assertLifecycleInvariants`) untouched — those rules are protocol-level and stable across endpoints.
4. If a previously-absent event type now appears (e.g. `shared_state` starts emitting deltas), tighten the assertion from "exists if present" to "must exist."
