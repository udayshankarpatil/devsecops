import asyncio
import logging
import os
import signal

from .consumer import run_consumer

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger(__name__)

KAFKA_BOOTSTRAP_SERVERS = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
KAFKA_TOPIC = os.getenv("KAFKA_TOPIC", "tasks")
KAFKA_GROUP_ID = os.getenv("KAFKA_GROUP_ID", "ingest-group")
DATABASE_URL = os.getenv(
    "DATABASE_URL", "postgresql://tasksuser:taskspass@localhost:5432/tasksdb"
)


async def main() -> None:
    stop_event = asyncio.Event()
    loop = asyncio.get_running_loop()

    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, stop_event.set)

    logger.info("ingest starting")
    await run_consumer(
        bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
        topic=KAFKA_TOPIC,
        group_id=KAFKA_GROUP_ID,
        database_url=DATABASE_URL,
        stop_event=stop_event,
    )
    logger.info("ingest stopped")


if __name__ == "__main__":
    asyncio.run(main())
