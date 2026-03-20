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

## Quick Reference

```bash
bash help.sh   # one-screen summary of all developer commands
```

## Local Deployment Modes

There are two ways to run the application locally. They can coexist without port
conflicts. See `docs/port-mappings.md` for full host port and network topology details.

| | Mode 1: docker-compose | Mode 2: Kind (local Kubernetes) |
|---|---|---|
| **Use for** | Active development, hot reload | Validating the GitOps/CD pipeline |
| **API port** | `http://localhost:8000` | `http://localhost:8080` |
| **Started with** | `docker compose up` | `ansible-playbook ansible/kind-up.yml` |

Postgres and Kafka always run in docker-compose. In Mode 2 the Kind node is
connected to the same Docker network so pods reach them by service name.

## Key Commands

### Mode 1 — docker-compose

```bash
# Start everything
docker compose up

# Infra only (run services locally)
docker compose up postgres kafka

# Build images
docker compose build [api|ingest|fetch]

# Reset database (destroys all data)
docker compose down -v

# Tail logs
docker compose logs -f [api|ingest|fetch|kafka|postgres]
```

### Mode 2 — Kind

```bash
# Bootstrap everything from scratch (host machine, not devcontainer)
bash bootstrap.sh                                   # prompts for GitHub username
bash bootstrap.sh -e image_owner=<github-username>  # non-interactive

# Tear down cluster
ansible-playbook ansible/kind-down.yml

# Verify setup / verify app is running
bash scripts/check-setup.sh
bash scripts/check-running.sh
```

### Tests

```bash
# Run all tests from repo root
pytest

# Per service
cd services/api && pytest
cd services/ingest && pytest
cd services/fetch && pytest
```

## Dev Container

- Python 3.12 installed system-wide (no venv)
- `postCreateCommand` installs all three services' deps in one pass with `-e` (editable install)
- Dev container joins the same Docker network as infra services
- `docker-compose.override.yml` is auto-loaded, selecting the `dev` build target and mounting live source trees for hot reload
- Ports forwarded to host: `8000` (api), `8002` (fetch), `5432` (postgres), `9092` (kafka)

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

1. Create `services/<name>/` with its own `Dockerfile`, `pyproject.toml`, `src/<name>/`, and `tests/`.
2. Add the service to `docker-compose.yml` using existing services as a template.
3. Wire `depends_on` for Kafka and/or Postgres as needed.
4. Update the Architecture section in this file and in `README.md`.

## CI/CD

The CI pipeline runs on GitHub Actions (`.github/workflows/ci.yml`):

- **PRs targeting `dev`** — runs the test matrix (all three services); must pass before merge
- **Merge into `dev`** — tests → build + push prod images to GHCR → commit updated image SHA to the `gitops` branch

Published image names:
```
ghcr.io/<owner>/task-manager/<service>:<commit-sha>   # immutable — pinned in gitops branch
ghcr.io/<owner>/task-manager/<service>:dev            # floating — latest merged build
```

`GITHUB_TOKEN` is injected automatically; no secrets need to be created.

The CD layer uses ArgoCD watching the `gitops` branch + a Kind cluster for local k8s (Mode 2 above). Playbooks are idempotent — safe to re-run. See `docs/developer-guide.md` for full setup instructions.

## Known Limitations (future work)

- `ingest` has log-and-skip error handling — no dead-letter queue
- No Alembic migrations — schema changes require `docker compose down -v`
- `ingest` healthcheck uses `pgrep` (crude) — a future iteration should write a heartbeat file
- No authentication on the API
