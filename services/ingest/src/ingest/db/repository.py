import asyncpg


async def upsert_task(conn: asyncpg.Connection, task_id: str, payload: dict) -> None:
    """Insert a new task or replace it if the ID already exists (idempotent)."""
    await conn.execute(
        """
        INSERT INTO tasks (id, title, description, status)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (id) DO UPDATE
            SET title       = EXCLUDED.title,
                description = EXCLUDED.description,
                status      = EXCLUDED.status
        """,
        task_id,
        payload.get("title"),
        payload.get("description"),
        payload.get("status", "pending"),
    )


async def update_task(conn: asyncpg.Connection, task_id: str, payload: dict) -> None:
    """Apply a partial update — only fields present in payload are changed."""
    if not payload:
        return

    allowed = {"title", "description", "status"}
    set_clauses = []
    values = [task_id]

    for field in allowed:
        if field in payload:
            values.append(payload[field])
            set_clauses.append(f"{field} = ${len(values)}")

    if not set_clauses:
        return

    query = f"UPDATE tasks SET {', '.join(set_clauses)} WHERE id = $1"  # nosec B608 # fields are allowlist-validated above
    await conn.execute(query, *values)


async def delete_task(conn: asyncpg.Connection, task_id: str) -> None:
    await conn.execute("DELETE FROM tasks WHERE id = $1", task_id)
