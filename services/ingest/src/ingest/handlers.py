import logging

import asyncpg

from .db.repository import delete_task, update_task, upsert_task

logger = logging.getLogger(__name__)


async def dispatch(pool: asyncpg.Pool, message: dict) -> None:
    event = message.get("event")
    task_id = message.get("task_id")
    payload = message.get("payload", {})

    if event == "created":
        async with pool.acquire() as conn:
            await upsert_task(conn, task_id, payload)
    elif event == "updated":
        async with pool.acquire() as conn:
            await update_task(conn, task_id, payload)
    elif event == "deleted":
        async with pool.acquire() as conn:
            await delete_task(conn, task_id)
    else:
        logger.warning("Unknown event type: %s", event)
