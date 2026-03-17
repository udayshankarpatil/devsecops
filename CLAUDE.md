# CLAUDE.md

## Project Overview

Task Manager — a Python microservices mono-repo. Three services cooperate to provide async-write, sync-read task management over a REST API.

## Architecture

```
Client → api (REST, :8000) ──[Kafka: tasks]──► ingest (consumer) ──► PostgreSQL
                └──────────[HTTP GET]──────────► fetch (REST, :8002) ◄── PostgreSQL
```

| Directory | Description |
|---|---|
| `services/api/` | FastAPI REST API. Publishes Kafka events for writes; calls `fetch` for reads. Stateless. |
| `services/ingest/` | aiokafka consumer. Writes to PostgreSQL. No HTTP server. |
| `services/fetch/` | FastAPI read-only API. asyncpg queries against PostgreSQL. |

Infrastructure lives in `docker-compose.yml`. Schema is in `infra/db/init.sql`.

## Kafka Message Format

```json
{
  "event": "created" | "updated" | "deleted",
  "task_id": "<uuid-string>",
  "payload": { "title": "...", "description": "...", "status": "..." }
}
```

- Topic: `tasks`
- Message key: `task_id` (byte-encoded) — ensures ordering per task across partitions
- `payload` is the full task body for `created`; only changed fields for `updated`; empty `{}` for `deleted`

## Database

- Schema: `infra/db/init.sql` (mounted into Postgres at first boot)
- No ORM — raw `asyncpg` throughout
- No migrations yet — schema changes require `docker compose down -v`
- `updated_at` is maintained automatically by a `BEFORE UPDATE` trigger in `init.sql`

## Write Response Convention

Mutation endpoints return `202 Accepted` with `{"task_id": "..."}`. The DB write is asynchronous (Kafka-mediated), so a task may not be immediately visible in read responses.

UUIDs are generated in `api` before publishing, so callers get an ID in the `202` response without polling.

## Key Commands

```bash
# Start everything
docker compose up

# Infra only (run services locally)
docker compose up postgres kafka

# Build images
docker compose build [api|ingest|fetch]

# Run tests per service
cd services/api && pytest
cd services/ingest && pytest
cd services/fetch && pytest

# Reset database (destroys all data)
docker compose down -v

# Tail logs
docker compose logs -f [api|ingest|fetch|kafka|postgres]
```

## Dev Container

- Python 3.11+ installed system-wide (no venv)
- `postCreateCommand` installs all three services' deps in one pass
- Dev container joins the same Docker network as infra services
- Ports forwarded: `8000`, `8002`, `5432`, `9092`

## Testing Approach

- Unit tests mock external dependencies (Kafka, DB, `fetch` HTTP) using `unittest.mock`
- `TestClient` (sync) for `api` and `fetch` — no real infrastructure needed
- `pytest-asyncio` with `asyncio_mode = auto` for `ingest`'s async handler tests
- Integration tests (marked `@pytest.mark.integration`, not yet written) require real infra

## Conventions

- All I/O is async — no blocking `asyncpg` or `requests` calls
- Black formatting, Ruff linting
- One `Dockerfile` per service
- `pyproject.toml` per service for metadata, dependencies, and pytest config
- Tests in `tests/` subdirectory per service

## Adding a New Service

1. Create `services/<name>/` with its own `Dockerfile`, `pyproject.toml`, `app/`, and `tests/`.
2. Add the service to `docker-compose.yml` using existing services as a template.
3. Wire `depends_on` for Kafka and/or Postgres as needed.
4. Update the Architecture section in this file and in `README.md`.

## Known Limitations (future work)

- `ingest` has log-and-skip error handling — no dead-letter queue
- No Alembic migrations — schema changes require `docker compose down -v`
- `ingest` healthcheck uses `pgrep` (crude) — a future iteration should write a heartbeat file
- No authentication on the API
