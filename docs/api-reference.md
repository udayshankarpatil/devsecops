# API Reference

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

## Swagger UI

With the stack running, the API is self-documenting via FastAPI's built-in OpenAPI support:

| URL | Description |
|---|---|
| http://localhost:8000/docs | Swagger UI — interactive, try requests in the browser |
| http://localhost:8000/redoc | ReDoc — alternative read-only documentation view |
| http://localhost:8000/openapi.json | Raw OpenAPI schema (JSON) |

Swagger UI lets you expand any endpoint, view its request/response schema, and execute requests directly — no curl or Postman needed.

## curl examples

Replace `<port>` with `8000` (docker-compose) or `8080` (Kind).

```bash
# Create a task
curl -s -X POST http://localhost:<port>/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "My first task", "description": "Do the thing", "status": "pending"}' | jq

# List tasks (allow a moment for ingest to write to the DB)
curl -s http://localhost:<port>/tasks | jq

# Get a specific task
curl -s http://localhost:<port>/tasks/<task_id> | jq

# Update a task
curl -s -X PUT http://localhost:<port>/tasks/<task_id> \
  -H "Content-Type: application/json" \
  -d '{"status": "done"}' | jq

# Delete a task
curl -s -X DELETE http://localhost:<port>/tasks/<task_id> | jq
```
