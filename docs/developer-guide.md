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
  uvicorn src.main:app --reload --port 8000

# fetch
cd services/fetch
DATABASE_URL=postgresql://tasksuser:taskspass@localhost:5432/tasksdb \
  uvicorn src.main:app --reload --port 8002

# ingest
cd services/ingest
DATABASE_URL=postgresql://tasksuser:taskspass@localhost:5432/tasksdb \
KAFKA_BOOTSTRAP_SERVERS=localhost:9092 \
  python -m src.main
```

**From VS Code:** Open the Run and Debug panel (`F5`) and add a launch configuration pointing to the `uvicorn` or `python -m` commands above.

## Running Tests

Run all tests from inside the dev container:

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

## Schema Changes

The database schema lives in `infra/db/init.sql`. PostgreSQL only runs this script when the data volume is first created.

To apply schema changes during development:

1. Edit `infra/db/init.sql`.
2. Destroy the data volume and restart:
   ```bash
   docker compose down -v && docker compose up
   ```

> **Warning:** `docker compose down -v` deletes all data. Never run this against an environment with data you need to keep.
