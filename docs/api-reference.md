[← README](../README.md)

# API Reference

The Task Manager exposes a REST API through the **api** service.

| Mode | Base URL | Interactive docs |
|---|---|---|
| Docker Compose (Mode 1) | `http://localhost:8000` | `http://localhost:8000/docs` |
| Kind / Kubernetes (Mode 2) | `http://localhost:8080` | `http://localhost:8080/docs` |

> **Write behaviour:** `POST`, `PUT`, and `DELETE` return `202 Accepted` immediately — the database write is asynchronous (via Kafka). The response includes a `task_id` you can use straight away, but allow a brief moment before the change appears in read responses.

## Endpoints

| Method | Path | Description | Success response |
|---|---|---|---|
| `GET` | `/health` | Service health check | `200` · `{"status":"ok"}` |
| `POST` | `/tasks` | Create a task | `202` · `{"task_id": "<uuid>"}` |
| `GET` | `/tasks` | List all tasks | `200` · array of task objects |
| `GET` | `/tasks/{id}` | Get a task by ID | `200` · task object · `404` if not found |
| `PUT` | `/tasks/{id}` | Partial update (any field) | `202` · `{"task_id": "<uuid>"}` |
| `DELETE` | `/tasks/{id}` | Delete a task | `202` · `{"task_id": "<uuid>"}` |

## Task object

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "string",
  "description": "string | null",
  "status": "pending | in_progress | done",
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:00:00Z"
}
```

## Swagger UI

With the stack running, the API is self-documenting via FastAPI's built-in OpenAPI support. Swagger UI lets you explore endpoints, view schemas, and execute requests directly in the browser — no curl or Postman required.

| URL | |
|---|---|
| `http://localhost:<port>/docs` | Swagger UI — interactive |
| `http://localhost:<port>/redoc` | ReDoc — read-only |
| `http://localhost:<port>/openapi.json` | Raw OpenAPI schema (JSON) |

## curl examples

```bash
# Replace <port> with 8000 (Mode 1) or 8080 (Mode 2)

# Create a task
curl -s -X POST http://localhost:<port>/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "My first task", "description": "Do the thing", "status": "pending"}'
# List all tasks (allow a moment after creating for the async write to complete)
curl -s http://localhost:<port>/tasks
# Get a specific task
curl -s http://localhost:<port>/tasks/<task_id>
# Update a task (any subset of fields)
curl -s -X PUT http://localhost:<port>/tasks/<task_id> \
  -H "Content-Type: application/json" \
  -d '{"status": "done"}'
# Delete a task
curl -s -X DELETE http://localhost:<port>/tasks/<task_id>```
