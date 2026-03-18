FROM python:3.12-slim AS base

WORKDIR /app
COPY pyproject.toml .
COPY src/ src/

FROM base AS prod
RUN pip install --no-cache-dir .
CMD ["python", "-m", "ingest.main"]

FROM base AS dev
RUN pip install --no-cache-dir -e . "watchdog[watchmedo]"
CMD ["watchmedo", "auto-restart", "--directory=/app/src", "--pattern=*.py", "--recursive", "--", "python", "-m", "ingest.main"]
