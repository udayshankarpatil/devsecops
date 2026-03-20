# Task Manager

A task management backend built as three cooperating Python microservices in a mono-repo.

## Overview


```mermaid
flowchart LR
    Client -->|REST| api

    subgraph Persistence
        DB[(PostgreSQL)]
    end

    subgraph Gateway
        api
    end

    subgraph Services
        api -.->|Kafka\ntasks topic| ingest
        ingest -->|asyncpg| DB

        api -->|HTTP GET| fetch
        fetch -->|asyncpg| DB
    end
```

| Service | Role | Port |
|---|---|---|
| **api** | REST gateway — accepts client requests, publishes Kafka events for writes, calls `fetch` for reads | 8000 |
| **ingest** | Kafka consumer — processes task events and persists them to PostgreSQL | — |
| **fetch** | Retrieval service — serves read queries directly from PostgreSQL | 8002 (internal) |



## API

All public endpoints are on **api** at `http://localhost:8000`.

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

### Swagger UI

With the stack running, the API is self-documenting via FastAPI's built-in OpenAPI support:

| URL | Description |
|---|---|
| http://localhost:8000/docs | Swagger UI — interactive, try requests in the browser |
| http://localhost:8000/redoc | ReDoc — alternative read-only documentation view |
| http://localhost:8000/openapi.json | Raw OpenAPI schema (JSON) |

Swagger UI lets you expand any endpoint, view its request/response schema, and execute requests directly — no curl or Postman needed.

## Project Structure

```
devsecops/
├── .claude/                  # Claude Code slash commands (/docker-build, /test-all, /logs)
├── .devcontainer/            # VS Code Dev Container config and dev image Dockerfile
├── .github/
│   └── workflows/
│       └── ci.yml            # CI: tests on PR, build + push to GHCR on merge, update gitops branch
├── ansible/                  # Idempotent playbooks for local cluster management
│   ├── dev-setup.yml         # Install host-machine tools (Homebrew + Galaxy collections)
│   ├── kind-config.yaml      # Kind cluster definition (NodePort mapping)
│   ├── kind-up.yml           # Bootstrap Kind + ArgoCD + secrets
│   ├── kind-down.yml         # Tear down the Kind cluster
│   └── requirements.yml      # Ansible collection dependencies
├── argocd/
│   └── application.yaml      # ArgoCD Application — watches gitops branch
├── docs/                     # Extended documentation
│   ├── developer-guide.md    # Full developer workflows (docker-compose and Kind)
│   └── port-mappings.md      # Host port tables and network topology
├── infra/
│   └── db/
│       └── init.sql          # PostgreSQL schema (tasks table + updated_at trigger)
├── scripts/
│   ├── check-setup.sh        # Verify one-time dev setup is complete
│   └── check-running.sh      # Verify application is deployed and running
├── services/
│   ├── api/                  # Gateway: FastAPI REST API, Kafka producer, HTTP client to fetch
│   ├── ingest/               # Ingestion: Kafka consumer, asyncpg writes to PostgreSQL
│   └── fetch/                # Retrieval: FastAPI read-only API, asyncpg queries
├── helm/
│   └── task-manager/         # Helm chart for k8s deployment (api, fetch, ingest)
├── bootstrap.sh              # One-command dev environment setup (tools + Kind cluster)
├── help.sh                   # Quick reference for all developer commands
├── CLAUDE.md                 # Project conventions and context for Claude Code
├── docker-compose.yml        # Full-stack orchestration (all services + Kafka + PostgreSQL)
├── docker-compose.override.yml  # Dev overrides: live-reload targets and source volume mounts
├── pytest.toml               # Workspace-root pytest config for unified test discovery
└── README.md
```

Each service directory shares the same layout:

```
service-name/
├── src/
│   └── <service-name>/   # Python package (src layout — package name matches service name)
├── tests/                # pytest unit tests
├── Dockerfile            # Multi-stage image: base → prod / base → dev
└── pyproject.toml        # Project metadata, dependencies, and pytest configuration
```

## Tech Stack

| Component | Technology |
|---|---|
| Services | Python 3.12, FastAPI, uvicorn |
| Async DB client | asyncpg |
| Messaging | Apache Kafka (KRaft mode) |
| Database | PostgreSQL 16 |
| Containerisation | Docker, Docker Compose v2 |
| CI / image registry | GitHub Actions, GHCR |
| CD / GitOps | ArgoCD, Helm, Kind (local) |
| Cluster automation | Ansible |
| Development | VS Code Dev Containers |

## Running Locally

There are two ways to run the application locally. See [docs/port-mappings.md](docs/port-mappings.md) for host port assignments and network topology.

### Mode 1 — docker-compose (development)

Prerequisites: [Docker Desktop](https://www.docker.com/products/docker-desktop/) and [VS Code](https://code.visualstudio.com/) with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).

1. Clone the repo and open it in VS Code.
2. When prompted, click **Reopen in Container** (or run **Dev Containers: Reopen in Container** from `⇧⌘P`).
3. VS Code builds the dev container and starts Kafka and PostgreSQL automatically.
4. Run `docker compose up` to start all three services.

API available at **`http://localhost:8000`** · Swagger UI at **`http://localhost:8000/docs`**

### Mode 2 — Kind / Kubernetes (GitOps)

Prerequisites: macOS with [Homebrew](https://brew.sh) and Docker Desktop running.

```bash
bash bootstrap.sh   # installs tools, spins up Kind cluster + ArgoCD
```

API available at **`http://localhost:8080`**

Use this mode to validate the full CI/CD pipeline — images are pulled from GHCR
and ArgoCD manages the rollout exactly as it would in a real cluster.

For full setup instructions and day-to-day workflows see [docs/developer-guide.md](docs/developer-guide.md).
