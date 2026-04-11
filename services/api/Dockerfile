FROM python:3.12-slim AS base

RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY pyproject.toml .
# Stub package directory lets pip resolve and cache all dependencies as a
# separate layer. COPY src/ below only invalidates layers after this point,
# so a source-only change never triggers a full dependency reinstall.
RUN mkdir -p src/api && pip install --no-cache-dir .

COPY src/ src/

FROM base AS prod
RUN pip install --no-cache-dir --no-deps .
CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]

FROM base AS dev
RUN pip install --no-cache-dir -e .
CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload", "--reload-delay", "3"]
