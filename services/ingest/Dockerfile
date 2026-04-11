FROM python:3.12-slim AS base

WORKDIR /app
COPY pyproject.toml .
# Stub package directory lets pip resolve and cache all dependencies as a
# separate layer. COPY src/ below only invalidates layers after this point,
# so a source-only change never triggers a full dependency reinstall.
RUN mkdir -p src/ingest && pip install --no-cache-dir .

COPY src/ src/

FROM base AS prod
RUN pip install --no-cache-dir --no-deps .
CMD ["python", "-m", "ingest.main"]

FROM base AS dev
RUN pip install --no-cache-dir -e . "watchdog[watchmedo]"
CMD ["watchmedo", "auto-restart", "--directory=/app/src", "--pattern=*.py", "--recursive", "--debounce-interval=3", "--", "python", "-m", "ingest.main"]
