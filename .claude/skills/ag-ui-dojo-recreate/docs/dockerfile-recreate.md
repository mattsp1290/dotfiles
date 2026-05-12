# Recreating the AG-UI Dojo Dockerfile

## What you are building

A Docker image named `ag-ui-protocol/ag-ui-server:dev` that runs the Python `server-starter-all-features` FastAPI/Uvicorn server on port 8000. The server exposes seven endpoints used by the AG-UI dojo:

- `/agentic_chat`
- `/human_in_the_loop`
- `/agentic_generative_ui`
- `/tool_based_generative_ui`
- `/shared_state`
- `/predictive_state_updates`
- `/backend_tool_rendering`

The legacy `ag-ui-protocol/ag-ui-server:latest` image in many users' local caches was built ~8 months before this skill (Docker history shows `COPY typescript-sdk/integrations/server-starter ... /app` and `CMD ["poetry", "run", "dev"]`). **Neither that path nor poetry is correct anymore.** The current server uses `uv` and lives at a different path.

## Current source-of-truth paths (verified 2026-05)

| Component | Path |
|-----------|------|
| Python all-features server | `integrations/server-starter-all-features/python/examples/` |
| AG-UI Python SDK (local dep) | `sdks/python/` |
| Entry script | `[project.scripts] dev = "example_server:main"` |
| Package manager | `uv` (not poetry); has `uv.lock` |
| `requires-python` | `>=3.12` |
| CI invocation (reference) | `apps/dojo/scripts/run-dojo-everything.js` — calls `uv run dev` with `cwd: integrations/server-starter-all-features/python/examples` |

The `pyproject.toml` at `integrations/server-starter-all-features/python/examples/pyproject.toml` references the Python SDK via `[tool.uv.sources]` as `directory = "../../../../sdks/python"` — i.e. four levels up. **The Dockerfile must preserve this exact relative layout inside the image** or `uv sync --frozen` will fail.

## Build-context assumption

The Dockerfile is invoked with **the repo root as the build context** so both `sdks/python` and `integrations/server-starter-all-features/python/examples` are reachable:

```bash
docker build \
  -f integrations/server-starter-all-features/python/examples/Dockerfile \
  -t ag-ui-protocol/ag-ui-server:dev \
  .
```

This is documented in a header comment in the Dockerfile itself.

## Build strategy

Two-stage build:

1. **Stage 1**: `ghcr.io/astral-sh/uv:latest` — used purely to source the `uv` binary.
2. **Stage 2**: `python:3.12-slim` — runtime base. The `uv` binary is copied from stage 1 into `/usr/local/bin/uv`.

Both source trees are copied preserving the exact relative directory structure the lockfile expects:

```
/repo/sdks/python/...
/repo/integrations/server-starter-all-features/python/examples/...
```

Then `WORKDIR` is set to the examples dir and `uv sync --frozen` installs all 17 packages from the lockfile in ~1.3s.

## Steps

1. **Write the Dockerfile** to `integrations/server-starter-all-features/python/examples/Dockerfile`. Use [`templates/Dockerfile`](../templates/Dockerfile) as the verbatim source — copy it directly. The header comment in the template documents the repo-root build-context assumption.

2. **Write the `.dockerignore`** to `integrations/server-starter-all-features/python/examples/.dockerignore`. Use [`templates/dockerignore`](../templates/dockerignore) (rename the leading dot during copy). Contents: excludes `.venv`, `__pycache__`, `*.pyc`, `.pytest_cache`, `node_modules`. Note: this `.dockerignore` only takes effect when the build context is narrowed to this directory — it doesn't apply when the context is the repo root. It's included for hygiene if someone narrows the context later.

3. **Build it** from the repo root:
   ```bash
   docker build \
     -f integrations/server-starter-all-features/python/examples/Dockerfile \
     -t ag-ui-protocol/ag-ui-server:dev \
     .
   ```

4. **Verification block** — run this and confirm every expected endpoint appears:
   ```bash
   docker run --rm -d --name ag-ui-server-verify -p 18002:8000 ag-ui-protocol/ag-ui-server:dev
   sleep 5
   curl -sS -m 5 http://localhost:18002/openapi.json \
     | python3 -c "import sys, json; print(sorted(json.load(sys.stdin)['paths'].keys()))"
   docker rm -f ag-ui-server-verify
   ```
   Expected output (sorted):
   ```
   ['/agentic_chat', '/agentic_generative_ui', '/backend_tool_rendering', '/human_in_the_loop', '/predictive_state_updates', '/shared_state', '/tool_based_generative_ui']
   ```
   If any endpoint is missing, the upstream Python server may have been refactored — read its `example_server/__init__.py` (or `main.py`) and verify the FastAPI route registrations.

## If the build fails

Most-likely failure modes and remedies:

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `uv sync --frozen` fails with "lockfile out of date" | `pyproject.toml` was updated without regenerating `uv.lock` upstream | Fall back to `uv sync` (no `--frozen`). Document this in a comment. |
| `ag-ui-protocol` not found | The `[tool.uv.sources]` directory path no longer resolves to `../../../../sdks/python` | Read the current `pyproject.toml` source spec and adjust the in-image directory layout to match. |
| `COPY sdks/python` fails | Repo layout changed (e.g. Python SDK moved out of `sdks/python`) | Search: `rg -l 'name = "ag-ui-protocol"' --type toml`. Update both `COPY` lines and the `[tool.uv.sources]` directory math. |
| `python:3.12-slim` errors on `requires-python = ">=3.13"` upstream bump | The base tag is too old | Bump base to `python:3.13-slim`. |
| Build is slow / re-pulls every time | No `.dockerignore` and a `.venv` is leaking in | Confirm a `.venv` is excluded; check `du -sh integrations/server-starter-all-features/python/examples/.venv` doesn't exist. |

## If the layout has changed entirely

If the Python server has been moved out of `integrations/server-starter-all-features/` or no longer uses `uv`, **stop and read the current state first**:

```bash
rg -l 'agentic_chat.*endpoint' --type py
rg -l '\[project.scripts\]' --type toml | xargs grep -l 'dev ='
```

The signal that you've found the right project: a Python project whose `pyproject.toml` has a `dev` script entry AND whose source registers FastAPI routes for the 6+ endpoint paths above.

Once located, mirror the Dockerfile strategy above but with the new paths. Keep the two-stage uv pattern unless the project has migrated to a different package manager.

## Reference: verbatim Dockerfile template

The current template ships at [`../templates/Dockerfile`](../templates/Dockerfile). Read it directly with the `Read` tool — do not paraphrase. Copy with:

```bash
cp $HOME/.claude/skills/ag-ui-dojo-recreate/templates/Dockerfile \
   integrations/server-starter-all-features/python/examples/Dockerfile
cp $HOME/.claude/skills/ag-ui-dojo-recreate/templates/dockerignore \
   integrations/server-starter-all-features/python/examples/.dockerignore
```

(The dot prefix is stripped in the template name to keep the templates dir from looking like a build context itself.)
