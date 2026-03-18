import pytest
from unittest.mock import AsyncMock, patch
from fastapi.testclient import TestClient

from api.main import app


@pytest.fixture
def client():
    with patch("api.kafka.producer.AIOKafkaProducer") as mock_cls:
        mock_cls.return_value = AsyncMock()
        with TestClient(app) as tc:
            app.state.producer = AsyncMock()
            app.state.http_client = AsyncMock()
            yield tc, app.state.producer, app.state.http_client
