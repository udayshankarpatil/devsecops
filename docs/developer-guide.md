# Developer Guide

## Building Docker Images

Rebuild after changing a `Dockerfile` or `pyproject.toml`:

```bash
# Rebuild all services
docker compose build

# Rebuild a single service
docker compose build api
```

## Running the Application


```bash
# Full stack
docker compose up

# Infrastructure only (run services locally during development):
docker compose up postgres kafka

# Shutdown
docker compose down
```

**Run a service locally** (from within the dev container or with deps installed):
```bash
# api
cd services/api
SERVICE_C_BASE_URL=http://localhost:8002 KAFKA_BOOTSTRAP_SERVERS=localhost:9092 \
  uvicorn api.main:app --reload --port 8000

# fetch
cd services/fetch
DATABASE_URL=postgresql://tasksuser:taskspass@localhost:5432/tasksdb \
  uvicorn fetch.main:app --reload --port 8002

# ingest
cd services/ingest
DATABASE_URL=postgresql://tasksuser:taskspass@localhost:5432/tasksdb \
KAFKA_BOOTSTRAP_SERVERS=localhost:9092 \
  python -m ingest.main
```

## Running Tests

From VS Code, all tests across all three services are discoverable and runnable via the Test Explorer panel (the beaker icon). Tests can be run individually, by service, or all at once.

From a terminal inside the dev container:

```bash
(cd services/api && pytest -v) && (cd services/ingest && pytest -v) && (cd services/fetch && pytest -v)
```

Or per service:

```bash
cd services/api && pytest
cd services/ingest && pytest
cd services/fetch && pytest
```

## curl examples

```bash
# Create a task
curl -s -X POST http://localhost:8000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "My first task", "description": "Do the thing", "status": "pending"}' | jq

# List tasks (allow a moment for ingest to write to the DB)
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

## CI Pipeline

The workflow lives in `.github/workflows/ci.yml` and has two jobs:

| Event | Jobs that run |
|---|---|
| PR opened / updated against `temp-ci` | **test** (all three services) |
| PR merged into `temp-ci` | **test** then **build** (push images to GHCR) |

### Day-to-day developer workflow

1. Branch off `temp-ci`, make your changes, open a PR back to `temp-ci`.
2. The three test jobs run automatically. All must be green before the PR can be merged (if branch protection is configured — see below).
3. On merge, production images are built and pushed to GHCR tagged with the commit SHA and a floating `dev` tag.

### One-time repo setup (owner only)

**1. Allow Actions to push packages**

Settings → Actions → General → Workflow permissions → **Read and write permissions**

**2. Protect the branch** (optional but recommended)

Settings → Branches → Add rule for `temp-ci`:
- Enable **Require status checks to pass before merging**
- Add checks: `Test api`, `Test fetch`, `Test ingest`

**3. Make GHCR images public** (after the first merge triggers a build)

Navigate to `github.com/<you>?tab=packages`, open each of the three packages, and set visibility to **Public**. This avoids needing pull credentials in Kubernetes later.

### GITHUB_TOKEN

No secret creation is needed. GitHub injects `GITHUB_TOKEN` into every workflow run automatically. The `packages: write` permission declared in the build job is sufficient for pushing to GHCR.

### Published images

After each merge into `temp-ci`:

```
ghcr.io/<owner>/task-manager/api:<commit-sha>     # immutable — use this for deployments
ghcr.io/<owner>/task-manager/api:dev              # floating — always points to latest merge
ghcr.io/<owner>/task-manager/fetch:<commit-sha>
ghcr.io/<owner>/task-manager/fetch:dev
ghcr.io/<owner>/task-manager/ingest:<commit-sha>
ghcr.io/<owner>/task-manager/ingest:dev
```

## Schema Changes

The database schema lives in `infra/db/init.sql`. PostgreSQL only runs this script when the data volume is first created.

To apply schema changes during development:

1. Edit `infra/db/init.sql`.
2. Destroy the data volume and restart:
   ```bash
   docker compose down -v && docker compose up
   ```

> **Warning:** `docker compose down -v` deletes all data. Never run this against an environment with data you need to keep.
