---
name: ag-ui-dojo-recreate
description: Recreate the AG-UI dojo Dockerfile and/or the Dart-SDK integration tests that exercise it. Use when the user wants the dojo server image rebuilt from current paths, or wants the dojo-targeted Dart integration tests regenerated in a fresh checkout.
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# AG-UI Dojo Recreate

Regenerates two artifacts that are intentionally kept out of the `ag-ui` repo's main branch but are useful for local development against the dojo server:

1. **Dockerfile** for `ag-ui-protocol/ag-ui-server` built from the *current* repo layout (the legacy image was built from paths that no longer exist).
2. **Three Dart integration test files** that exercise the Dart SDK at `sdks/community/dart/` against a running dojo container.

Verbatim template copies of every file produced live in `templates/`. The supporting `.md` docs explain *why* each piece is shaped the way it is so the agent can adapt them if the upstream code has moved.

## Arguments

Parse `$ARGUMENTS`:

- `dockerfile` — recreate only the Dockerfile + `.dockerignore`.
- `tests` — recreate only the three Dart integration test files.
- `all` (default if no argument) — both.

Example invocations: `/ag-ui-dojo-recreate dockerfile`, `/ag-ui-dojo-recreate tests`, `/ag-ui-dojo-recreate`.

## Prerequisites — always run first

1. **Verify repo root.** Run `pwd && git remote -v`. The user must be inside a clone of `https://github.com/ag-ui-protocol/ag-ui` (or a fork). If not, stop and ask.
2. **Verify target paths exist.** Run, in parallel:
   - `test -d integrations/server-starter-all-features/python/examples && echo OK || echo MISSING-PYTHON-SERVER`
   - `test -d sdks/community/dart && echo OK || echo MISSING-DART-SDK`
   - `test -d sdks/python && echo OK || echo MISSING-PYTHON-SDK`
3. If any path is missing, **stop** and tell the user the repo layout has changed since this skill was written (2026-05). Read [`docs/dockerfile-recreate.md`](docs/dockerfile-recreate.md) and [`docs/tests-recreate.md`](docs/tests-recreate.md) "If the layout has changed" sections before improvising.

## Routing

After prerequisites pass:

| Argument | Action |
|----------|--------|
| `dockerfile` | Follow [`docs/dockerfile-recreate.md`](docs/dockerfile-recreate.md). |
| `tests` | Follow [`docs/tests-recreate.md`](docs/tests-recreate.md). |
| `all` / empty | Run both, dockerfile first (so tests can be verified against the fresh image at the end). |

Each `docs/*-recreate.md` ends with a **verification block** the agent must run before declaring done. Do not skip verification.

## Important context for any branch

Before writing assertions in the test files, **read [`docs/dojo-endpoint-behaviors.md`](docs/dojo-endpoint-behaviors.md)**. It documents what each of the 6 dojo endpoints actually emits — which is *not* what the AG-UI protocol theory would predict for every endpoint. The original tests were written based on live curl probing, not spec reading. If you skip this doc you will write assertions that fail because they assert events the server doesn't emit.

Also read [`docs/dart-sdk-quirks.md`](docs/dart-sdk-quirks.md) before writing the resilience test — several client behaviors diverge from naive expectations (e.g. duplicate-runId rejection surfaces *through* the stream, not as a synchronous throw).

## What this skill does NOT do

- It does **not** commit the recreated files. They are intentionally local-only artifacts. If the user later wants them committed, that is a separate decision.
- It does **not** push the rebuilt Docker image to any registry. The image is tagged `ag-ui-protocol/ag-ui-server:dev` locally and stays in the local cache.
- It does **not** modify any file outside the two scopes (`integrations/server-starter-all-features/python/examples/` for the Dockerfile, `sdks/community/dart/test/integration/` for the tests).

## File layout produced

```
integrations/server-starter-all-features/python/examples/
  ├── Dockerfile                                  (1.7K)
  └── .dockerignore                               (~75 bytes)

sdks/community/dart/test/integration/
  ├── dojo_smoke_test.dart                        (~26K, 7 tests)
  ├── dojo_new_events_decode_test.dart            (~26K, 40 tests)
  └── dojo_resilience_test.dart                   (~24K, 11 tests)
```

Total: 58 tests, all expected to pass against a running dojo on port 18000 (or 18002 if avoiding a pre-existing `:latest` container).
