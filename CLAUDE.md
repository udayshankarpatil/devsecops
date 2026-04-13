# CLAUDE.md

## Working with Claude

- **Git is managed by the developer.** Never stage, commit, push, or run any other git write operation unless explicitly asked. This includes `git add`, `git commit`, `git push`, `git restore`, and similar commands.
- **Commit messages** should capture the essence of the change — not list the steps taken to implement it. Omit trivial details such as documentation updates.

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

Infrastructure lives in `docker-compose.yml`. Schema is in `ops/infra/db/init.sql`.

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

- Schema: `ops/infra/db/init.sql` (mounted into Postgres at first boot)
- No ORM — raw `asyncpg` throughout
- No migrations yet — schema changes require `bash dev.sh down -v`
- `updated_at` is maintained automatically by a `BEFORE UPDATE` trigger in `init.sql`

## Write Response Convention

Mutation endpoints return `202 Accepted` with `{"task_id": "..."}`. The DB write is asynchronous (Kafka-mediated), so a task may not be immediately visible in read responses.

UUIDs are generated in `api` before publishing, so callers get an ID in the `202` response without polling.

## Quick Reference

```bash
bash dev.sh help   # one-screen summary of all developer commands
```

## Local Deployment Modes

There are two ways to run the application locally. They can run in parallel without
port conflicts, but they are **not isolated** — Mode 2 reuses the same Postgres and
Kafka containers as Mode 1, so both modes share the same data. See `docs/port-mappings.md`
for full host port and network topology details.

| | Mode 1: Docker Compose | Mode 2: Kind (local Kubernetes) |
|---|---|---|
| **Use for** | Active development, hot reload | Validating the GitOps/CD pipeline |
| **API port** | `http://localhost:8000` | `http://localhost:8080` |
| **Started with** | `bash dev.sh up` | `bash dev.sh up-kind` |

Postgres and Kafka always run via Docker Compose. In Mode 2 the Kind node is
connected to the same Docker network so pods reach them by service name.

## Key Commands

### Host setup (once per machine / once per clone)

```bash
bash dev.sh setup
```

### Mode 1 — Docker Compose

```bash
# Start everything (foreground — logs stream to terminal, Ctrl+C stops all containers)
bash dev.sh up

# Start detached (terminal returns immediately; use 'docker compose logs -f' to follow logs)
bash dev.sh up -d

# Infra only (run services locally)
bash dev.sh up postgres kafka

# Build images
bash dev.sh build [api|ingest|fetch]

# Reset database (destroys all data)
bash dev.sh down -v

# Tail logs
docker compose logs -f [api|ingest|fetch|kafka|postgres]
```

### Mode 2 — Kind

```bash
# Provision Kind cluster + ArgoCD — idempotent, re-run to recreate after down kind
bash dev.sh up-kind                              # prompts for GitHub username
bash dev.sh up-kind -e image_owner=<username>   # non-interactive

# Tear down cluster (stops postgres/kafka only if Mode 1 is not running)
bash dev.sh down-kind

# Verify setup / verify app is running
bash ops/scripts/check-setup.sh
bash dev.sh check       # Mode 1: infra + services + API at :8000
bash dev.sh check-kind  # Mode 2: infra + cluster + pods + API at :8080
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

- **PRs targeting `dev`** — runs tests + all security gates in parallel; all must pass before merge
- **Merge into `dev`** — tests + security → build (scan then push images to GHCR) → SBOM generation → commit updated image SHA to the `gitops` branch

### Security gates (run on every PR and push)

| Job | Tool | Checks |
|---|---|---|
| `sast` | Bandit | Python security anti-patterns |
| `sca` | pip-audit | CVEs in Python dependencies |
| `lint-dockerfiles` | Hadolint | Dockerfile violations |
| `secrets-scan` | Gitleaks | Hardcoded secrets in git history |
| `scan-configs` | Trivy (misconfig) | Helm / Compose misconfigurations |

Images are scanned with Trivy **before** being pushed to GHCR — a vulnerable image never reaches the registry.

### Key security config files

| File | Purpose |
|---|---|
| `ops/config/hadolint.yaml` | Hadolint rules and ignored warnings |
| `ops/config/.trivyignore` | Accepted CVEs / misconfig rules with justifications |
| `.pre-commit-config.yaml` | Gitleaks pre-commit hook (run `pre-commit install` once per clone) |
| `services/*/pyproject.toml` | `[tool.bandit]` config per service |

Published image names:
```
ghcr.io/<owner>/task-manager/<service>:<commit-sha>   # immutable — pinned in gitops branch
ghcr.io/<owner>/task-manager/<service>:dev            # floating — latest merged build
```

`GITHUB_TOKEN` is injected automatically; no secrets need to be created.

The CD layer uses ArgoCD watching the `gitops` branch + a Kind cluster for local k8s (Mode 2 above). Playbooks are idempotent — safe to re-run. See `docs/ci-cd.md` for the full pipeline reference and `docs/developer-guide.md` for one-time setup and day-to-day workflows.

## Known Limitations (future work)

- `ingest` has log-and-skip error handling — no dead-letter queue
- No Alembic migrations — schema changes require `docker compose down -v`
- `ingest` healthcheck uses `pgrep` (crude) — a future iteration should write a heartbeat file
- No authentication on the API
