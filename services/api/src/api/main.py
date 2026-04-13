import os
from contextlib import asynccontextmanager
from importlib.metadata import version
import httpx
from fastapi import FastAPI
from .kafka.producer import KafkaProducer
from .routers import tasks as tasks_router

VERSION = version("api")

KAFKA_BOOTSTRAP_SERVERS = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
KAFKA_TOPIC = os.getenv("KAFKA_TOPIC", "tasks")
SERVICE_C_BASE_URL = os.getenv("SERVICE_C_BASE_URL", "http://localhost:8002")


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.producer = KafkaProducer(KAFKA_BOOTSTRAP_SERVERS, KAFKA_TOPIC)
    await app.state.producer.start()
    app.state.http_client = httpx.AsyncClient(base_url=SERVICE_C_BASE_URL, timeout=10.0)
    yield
    await app.state.producer.stop()
    await app.state.http_client.aclose()


app = FastAPI(
    title="Task Manager API",
    version=VERSION,
    lifespan=lifespan,
)

app.include_router(tasks_router.router)


@app.get("/health")
async def health():
    return {"status": "ok", "version": VERSION}
