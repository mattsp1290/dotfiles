# Dart SDK Quirks That Affect Test Authoring

This is a catalog of non-obvious behaviors of `sdks/community/dart/` that drove decisions in the resilience and new-events tests. Read this before adjusting `dojo_resilience_test.dart` or `dojo_new_events_decode_test.dart`.

## Client quirks (`lib/src/client/client.dart`)

### Duplicate-runId rejection surfaces through the stream

`_runAgentInternal` is declared `async*`. The `putIfAbsent` check that enforces unique in-flight runIds runs **inside** the generator body — it does not run when `runAgent()` is called; it runs when the returned stream is first listened to. Consequences for tests:

- `client.runAgenticChat(input)` does NOT throw synchronously on duplicate runId.
- The `ValidationError(constraint: 'unique-in-flight')` arrives as an **error event on the stream** of the second call.
- A test that uses `expect(() => client.runAgenticChat(...), throwsA(...))` will silently pass without exercising anything. Use `expectLater(stream, emitsError(...))` or `await for ... on ValidationError catch (e)`.
- To reproduce reliably: keep the first stream "in-flight" by pointing it at a hanging in-process `HttpServer` (one that accepts but never writes). A `await Future.delayed(Duration(milliseconds: 200))` between the two `listen()` calls lets the first generator register itself in `_requestTokens` before the second probes.

### `CancelToken.cancel()` alone does NOT abort an in-flight SSE stream

The documented "known limitation" in `_sendWithCancellation`: cancellation only drops the response at the Dart `Completer` level. Once the `http.Client.send()` future has resolved (i.e. response headers have arrived and we're streaming the body), `cancelToken.cancel()` is a no-op on the underlying socket.

To actually terminate an in-flight stream, call `client.cancelRun(runId)` — that path additionally closes the `SseClient`, which closes the body subscription.

This means a test that wants to assert mid-stream cancellation should:
1. Subscribe to the stream and wait for the first event (so we know we're past the headers phase).
2. Call `client.cancelRun(runId)`, NOT just `cancelToken.cancel()`.
3. Assert the stream terminates (cleanly or with `CancellationError` depending on timing).
4. Verify cleanup by attempting a second run with the same `runId` — should succeed (no `unique-in-flight` rejection, since the `finally` block in `_runAgentInternal` removes the entry).

### 422 is unreachable through `SimpleRunAgentInput`

`SimpleRunAgentInput.toJson()` always emits all required fields (with empty defaults for `messages`, `tools`, `context`, `forwardedProps`) regardless of what the caller passed. Message subclasses hardcode their `role` value. The dojo's pydantic schema is permissive about tool parameter shapes — `{"parameters": "not-a-schema"}` is accepted, not rejected.

We could not find a payload that goes through the public client API and triggers a 422 from the live dojo. The resilience test marks this case `skip` with a TODO comment rather than contorting around the typed API.

If a future server tightens its schema, the cheapest trigger to try is sending an unknown `role` value — which requires bypassing the typed Message hierarchy (e.g. construct the request via raw HTTP).

### `AGUITimeoutError.operation` is the full URL

Not just the path. Tests should match with `contains` rather than `equals`:

```dart
expect(error.operation, contains('/agentic_chat'));
```

`error.timeout` matches `config.requestTimeout` exactly.

### `client.close()` is documented idempotent

But the second call still iterates `_requestTokens.values` (which is empty after the first close) and calls `_httpClient.close()` again — `http.Client.close()` is itself idempotent. No assertion-worthy behavior beyond "doesn't throw."

### `_requestTokens` is cleared in `finally`

So a `runId` that completed (normally or via error) can be reused immediately. Tests that need to verify cleanup can re-submit with the same `runId` and assert success.

## Event quirks (`lib/src/events/events.dart`)

### `ActivitySnapshotEvent.toJson()` omits `replace: true`

When `replace` is `true` (the default for snapshots), the field is dropped from `toJson` output. The factory restores it from absence-means-true logic. Round-trip is still clean — `decode(encode(decode(json))) == decode(json)` — but `decoded.toJson() != originalJson` if the original had `"replace": true` explicit.

If you assert raw-JSON equality somewhere, this will trip you up. Use field-by-field assertions instead.

### `ReasoningEncryptedValueEvent.rawEvent` is always null

Cipher-safety guard: the `fromJson` factory drops any incoming `rawEvent` field on this event class. Tests that assert round-trip stability must not include `rawEvent` in the expected output.

### Unknown reasoning subtype throws `DecodingError`

The Reasoning encrypted value's `subtype` is enum-like. An unknown subtype value triggers `DecodingError` rather than falling back to a generic decode. Reasonable, but means the resilience test's "unknown event type" coverage should target the *event type* (`EventType.fromString`) rather than this internal sub-enum.

### `ReasoningMessageChunkEvent` makes all fields optional

`messageId`, `role`, `delta`, `parentReasoningId` — every field is optional. `toJson` omits nulls. This was intentional to match the canonical TS SDK's permissive chunk shape. Tests should construct chunk events with at least `messageId` to be meaningful but should not assert any field is non-null.

## SSE parser quirks (`lib/src/sse/sse_parser.dart`)

### Keep-alive sentinels are filtered twice

Both the SSE parser AND `EventStreamAdapter.fromSseStream` filter `data: :` keep-alive lines. The duplication is intentional defense-in-depth: some servers emit the keep-alive as a comment (`: keep-alive\n`), some as a data line containing only `:`. The adapter's filter is the safety net.

This means tests that probe SSE framing edge cases should test BOTH paths: feeding `SseMessage(data: ':')` directly to the adapter, and feeding the raw `data: :\n\n` bytes through the parser.

### Multi-line `data:` framing

Per the SSE spec, multiple `data:` lines in a single event are joined with `\n` between them. The Dart parser handles this. No test currently asserts it against a live stream because the dojo doesn't emit multi-line data, but synthetic tests in `event_decoding_integration_test.dart` cover it.

## Validation quirks (`lib/src/client/validators.dart`)

### `validateThreadId` and `validateRunId` both cap at 100 characters

Same constraint, two functions, because they used to differ. Tests for oversized-id rejection should use exactly 101 chars to trigger the boundary cleanly.

### `validateUrl` rejects `http://` (no host)

Empty-host URLs are caught alongside scheme checks. Tests can use this for a quick "malformed URL" rejection without dealing with DNS.

### `requireNonEmpty` rejects null AND empty string

A single check for both, on `message.id`. The `Message.id` field is declared nullable at the type level (to accommodate inbound MESSAGES_SNAPSHOT payloads where the server may omit it), but outbound messages must carry a non-empty id.

## Stream-adapter quirks (`lib/src/encoder/stream_adapter.dart`)

### `pendingPreStartChunks` covers a real wire pattern

When a `TOOL_CALL_CHUNK` arrives before its `TOOL_CALL_START`, the adapter buffers it. The dojo doesn't emit chunk events (it uses START/ARGS/END), so the buffering path is exercised only by synthetic tests. Worth knowing exists.

### `activeGroups` keying by event-class + id

Concurrent text streams (multiple `messageId`s active at once) and concurrent tool calls (multiple `toolCallId`s) are tracked in `activeGroups` keyed by a `(class, id)` tuple. None of the dojo endpoints currently produces concurrent groups, so this code path is also test-only territory.

### `skipInvalidEvents` recovery path

When `skipInvalidEvents` is `true` (default), a single bad event in the stream is logged and dropped; the stream continues. When `false`, the stream errors out. The new-events decode test exercises both.

## Behavior summary table for resilience tests

| What you're testing | Throws? | Surface |
|---------------------|---------|---------|
| Empty/malformed endpoint URL | Synchronously | `ValidationError` from `Validators.validateUrl` (called at top of `runAgent`) |
| Empty message.id | Synchronously | `ValidationError` from `_validateRunAgentInput` (called before generator setup) |
| Duplicate message.id | Synchronously | `ValidationError(constraint: 'unique-id')` |
| Duplicate toolCall.id (within one AssistantMessage) | Synchronously | `ValidationError(constraint: 'unique-within-message')` |
| Oversized runId | Synchronously | `ValidationError(constraint: 'max-length-100')` |
| Duplicate runId (across in-flight calls) | **Through the stream** | `ValidationError(constraint: 'unique-in-flight')` |
| Server 4xx | Through the stream | `TransportError(statusCode: 4xx)` |
| Request timeout | Through the stream | `AGUITimeoutError` |
| Cancellation via `cancelRun` | Stream terminates | possibly `CancellationError` or clean close |

"Synchronously" here means: thrown by the act of calling `runAgent()` itself, before any `.listen()` on the returned stream. "Through the stream" means: thrown only once subscription begins.
