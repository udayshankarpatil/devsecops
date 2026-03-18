import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi.testclient import TestClient

from fetch.main import app


@pytest.fixture
def client():
    mock_pool = MagicMock()
    mock_pool.close = AsyncMock()
    with patch("fetch.main.asyncpg.create_pool", AsyncMock(return_value=mock_pool)):
        with TestClient(app) as tc:
            app.state.db = mock_pool
            yield tc, mock_pool
