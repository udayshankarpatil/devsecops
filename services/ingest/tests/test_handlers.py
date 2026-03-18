import logging
import pytest
from unittest.mock import AsyncMock, patch

from ingest.handlers import dispatch


async def test_dispatch_created(mock_pool):
    pool, conn = mock_pool
    with patch("ingest.handlers.upsert_task", new_callable=AsyncMock) as mock_upsert:
        await dispatch(pool, {
            "event": "created",
            "task_id": "abc",
            "payload": {"title": "T1", "status": "pending"},
        })
        mock_upsert.assert_awaited_once_with(
            conn, "abc", {"title": "T1", "status": "pending"}
        )


async def test_dispatch_updated(mock_pool):
    pool, conn = mock_pool
    with patch("ingest.handlers.update_task", new_callable=AsyncMock) as mock_update:
        await dispatch(pool, {
            "event": "updated",
            "task_id": "abc",
            "payload": {"status": "done"},
        })
        mock_update.assert_awaited_once_with(conn, "abc", {"status": "done"})


async def test_dispatch_deleted(mock_pool):
    pool, conn = mock_pool
    with patch("ingest.handlers.delete_task", new_callable=AsyncMock) as mock_delete:
        await dispatch(pool, {"event": "deleted", "task_id": "abc", "payload": {}})
        mock_delete.assert_awaited_once_with(conn, "abc")


async def test_dispatch_unknown_event_logs_warning(mock_pool, caplog):
    pool, _ = mock_pool
    with caplog.at_level(logging.WARNING, logger="ingest.handlers"):
        await dispatch(pool, {"event": "unknown", "task_id": "abc", "payload": {}})
    assert "Unknown event type" in caplog.text
