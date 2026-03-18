import asyncio
import json
import logging

import asyncpg
from aiokafka import AIOKafkaConsumer

from .handlers import dispatch

logger = logging.getLogger(__name__)


async def run_consumer(
    bootstrap_servers: str,
    topic: str,
    group_id: str,
    database_url: str,
    stop_event: asyncio.Event,
) -> None:
    pool = await asyncpg.create_pool(database_url)
    consumer = AIOKafkaConsumer(
        topic,
        bootstrap_servers=bootstrap_servers,
        group_id=group_id,
        auto_offset_reset="earliest",
        enable_auto_commit=False,
        value_deserializer=lambda v: json.loads(v.decode()),
    )
    await consumer.start()
    logger.info("Consumer started, listening on topic '%s'", topic)

    try:
        async for message in consumer:
            if stop_event.is_set():
                break
            try:
                await dispatch(pool, message.value)
                await consumer.commit()
            except Exception:
                logger.exception("Failed to process message: %s", message.value)
    finally:
        await consumer.stop()
        await pool.close()
        logger.info("Consumer shut down")
