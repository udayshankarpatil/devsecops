from typing import Optional

import asyncpg


async def get_all_tasks(pool: asyncpg.Pool) -> list:
    async with pool.acquire() as conn:
        return await conn.fetch("SELECT * FROM tasks ORDER BY created_at DESC")


async def get_task_by_id(pool: asyncpg.Pool, task_id: str) -> Optional[asyncpg.Record]:
    async with pool.acquire() as conn:
        return await conn.fetchrow("SELECT * FROM tasks WHERE id = $1", task_id)
