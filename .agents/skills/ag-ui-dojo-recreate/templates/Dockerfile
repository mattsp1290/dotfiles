# Build context: invoke from the repo root so both the SDK and this app are accessible.
# Example:
#   docker build \
#     -f integrations/server-starter-all-features/python/examples/Dockerfile \
#     -t ag-ui-protocol/ag-ui-server:dev \
#     .

# ---------------------------------------------------------------------------
# Stage 1: obtain the uv binary
# ---------------------------------------------------------------------------
FROM ghcr.io/astral-sh/uv:latest AS uv-bin

# ---------------------------------------------------------------------------
# Stage 2: runtime image
# ---------------------------------------------------------------------------
FROM python:3.12-slim

# Copy uv binary from the builder stage
COPY --from=uv-bin /uv /uvx /usr/local/bin/

# Preserve the same relative directory structure as the repo so that the
# uv.lock entry  source = { directory = "../../../../sdks/python" }
# resolves correctly from /repo/integrations/server-starter-all-features/python/examples.
WORKDIR /repo

# Copy the ag-ui Python SDK (local path dependency referenced by uv.lock)
COPY sdks/python /repo/sdks/python

# Copy the example server application
COPY integrations/server-starter-all-features/python/examples /repo/integrations/server-starter-all-features/python/examples

WORKDIR /repo/integrations/server-starter-all-features/python/examples

# Install dependencies using the lockfile for a reproducible build.
# UV_SYSTEM_PYTHON is not set; uv will create a project-local .venv.
# --frozen ensures the lockfile is not updated during the build.
RUN uv sync --frozen

# PORT is read at runtime by the main() entrypoint (default: 8000)
ENV PORT=8000

EXPOSE 8000

CMD ["uv", "run", "dev"]
