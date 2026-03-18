FROM python:3.12-slim AS base

RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY pyproject.toml .
COPY src/ src/

FROM base AS prod
RUN pip install --no-cache-dir .
CMD ["uvicorn", "fetch.main:app", "--host", "0.0.0.0", "--port", "8002"]

FROM base AS dev
RUN pip install --no-cache-dir -e .
CMD ["uvicorn", "fetch.main:app", "--host", "0.0.0.0", "--port", "8002", "--reload"]
