import os
from contextlib import asynccontextmanager

import asyncpg
from fastapi import FastAPI

from .routers import tasks as tasks_router

DATABASE_URL = os.getenv(
    "DATABASE_URL", "postgresql://tasksuser:taskspass@localhost:5432/tasksdb"
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.db = await asyncpg.create_pool(DATABASE_URL, min_size=2, max_size=10)
    yield
    await app.state.db.close()


app = FastAPI(
    title="Task Manager – Service C (Retrieval)",
    version="0.1.0",
    lifespan=lifespan,
)

app.include_router(tasks_router.router)


@app.get("/health")
async def health():
    return {"status": "ok"}
