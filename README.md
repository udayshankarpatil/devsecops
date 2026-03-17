# Task Manager

A task management backend built as three cooperating Python microservices in a mono-repo.

## Overview

| Service | Role | Port |
|---|---|---|
| **api** | REST gateway — accepts client requests, publishes Kafka events for writes, calls `fetch` for reads | 8000 |
| **ingest** | Kafka consumer — processes task events and persists them to PostgreSQL | — |
| **fetch** | Retrieval service — serves read queries directly from PostgreSQL | 8002 (internal) |

**Write flow:** Client → api → Kafka → ingest → PostgreSQL
**Read flow:** Client → api → fetch → PostgreSQL

## API

All public endpoints are on **Service A** at `http://localhost:8000`.

| Method | Path | Description | Response |
|---|---|---|---|
| `POST` | `/tasks` | Create a task | `202 Accepted` · `{"task_id": "<uuid>"}` |
| `GET` | `/tasks` | List all tasks | `200 OK` · array of task objects |
| `GET` | `/tasks/{id}` | Get a task by ID | `200 OK` · task object · `404` if not found |
| `PUT` | `/tasks/{id}` | Partial update (any field) | `202 Accepted` · `{"task_id": "<uuid>"}` |
| `DELETE` | `/tasks/{id}` | Delete a task | `202 Accepted` · `{"task_id": "<uuid>"}` |

**Task object:**
```json
{
  "id": "uuid",
  "title": "string",
  "description": "string | null",
  "status": "pending | in_progress | done",
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:00:00Z"
}
```

> Write endpoints return `202 Accepted` because the database write is asynchronous (via Kafka). Allow a brief moment before a newly created or updated task appears in read responses.

## Project Structure

```
devsecops/
├── .claude/                  # Claude Code slash commands (/docker-build, /test-all, /logs)
├── .devcontainer/            # VS Code Dev Container config and dev image Dockerfile
├── infra/
│   └── db/
│       └── init.sql          # PostgreSQL schema (tasks table + updated_at trigger)
├── services/
│   ├── api/                  # Gateway: FastAPI REST API, Kafka producer, HTTP client to fetch
│   ├── ingest/               # Ingestion: Kafka consumer, asyncpg writes to PostgreSQL
│   └── fetch/                # Retrieval: FastAPI read-only API, asyncpg queries
├── CLAUDE.md                 # Project conventions and context for Claude Code
├── docker-compose.yml        # Full-stack orchestration (all services + Kafka + PostgreSQL)
└── README.md
```

Each service directory shares the same layout:

```
service-x/
├── src/              # Python package (application source)
├── tests/            # pytest unit tests
├── Dockerfile        # Container image definition
└── pyproject.toml    # Project metadata, dependencies, and pytest configuration
```

## Tech Stack

| Component | Technology |
|---|---|
| Services | Python 3.12, FastAPI, uvicorn |
| Async DB client | asyncpg |
| Messaging | Apache Kafka (KRaft mode, Bitnami image) |
| Database | PostgreSQL 16 |
| Containerisation | Docker, Docker Compose v2 |
| Development | VS Code Dev Containers |

## Developer Guide

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Docker Engine + Compose v2)
- [VS Code](https://code.visualstudio.com/) with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

### Local Dev Setup

1. Clone the repo and open it in VS Code.
2. When prompted, click **Reopen in Container** — or run **Dev Containers: Reopen in Container** from the command palette (`⇧⌘P`).
3. VS Code builds the dev container and starts all infrastructure (Kafka, PostgreSQL) automatically. The `postCreateCommand` installs all Python dependencies system-wide — no virtual environment is used.
4. Ports `8000`, `8002`, `5432`, and `9092` are forwarded to your host.

### Building Docker Images

Rebuild after changing a `Dockerfile` or `pyproject.toml`:

```bash
# Rebuild all services
docker compose build

# Rebuild a single service
docker compose build api
```

### Running the Application

**Full stack:**
```bash
docker compose up
```

**Infrastructure only** (run services locally during development):
```bash
docker compose up postgres kafka
```

**Run a service locally** (from within the dev container or with deps installed):
```bash
# api
cd services/api
SERVICE_C_BASE_URL=http://localhost:8002 KAFKA_BOOTSTRAP_SERVERS=localhost:9092 \
  uvicorn app.main:app --reload --port 8000

# fetch
cd services/fetch
DATABASE_URL=postgresql://tasksuser:taskspass@localhost:5432/tasksdb \
  uvicorn app.main:app --reload --port 8002

# ingest
cd services/ingest
DATABASE_URL=postgresql://tasksuser:taskspass@localhost:5432/tasksdb \
KAFKA_BOOTSTRAP_SERVERS=localhost:9092 \
  python -m app.main
```

**From VS Code:** Open the Run and Debug panel (`F5`) and add a launch configuration pointing to the `uvicorn` or `python -m` commands above.

### Running Tests

```bash
# From the dev container (repo root)
cd services/api && pytest
cd services/ingest && pytest
cd services/fetch && pytest
```

### Calling the API from the Browser

With the stack running, open **http://localhost:8000/docs** for the interactive Swagger UI.

**curl examples:**
```bash
# Create a task
curl -s -X POST http://localhost:8000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "My first task", "description": "Do the thing", "status": "pending"}' | jq

# List tasks (allow a moment for Service B to write to the DB)
curl -s http://localhost:8000/tasks | jq

# Get a specific task
curl -s http://localhost:8000/tasks/<task_id> | jq

# Update a task
curl -s -X PUT http://localhost:8000/tasks/<task_id> \
  -H "Content-Type: application/json" \
  -d '{"status": "done"}' | jq

# Delete a task
curl -s -X DELETE http://localhost:8000/tasks/<task_id> | jq
```

### Schema Changes

The database schema lives in `infra/db/init.sql`. PostgreSQL only runs this script when the data volume is first created.

To apply schema changes during development:

1. Edit `infra/db/init.sql`.
2. Destroy the data volume and restart:
   ```bash
   docker compose down -v && docker compose up
   ```

> **Warning:** `docker compose down -v` deletes all data. Never run this against an environment with data you need to keep.
