import httpx
from unittest.mock import MagicMock

TASK_ID = "00000000-0000-0000-0000-000000000001"
TASK_STUB = {
    "id": TASK_ID,
    "title": "T1",
    "status": "pending",
    "description": None,
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z",
}


def make_response(status_code: int, body=None):
    mock = MagicMock()
    mock.status_code = status_code
    mock.json.return_value = body or {}
    if status_code >= 400:
        error = MagicMock()
        error.status_code = status_code
        error.text = "error"
        mock.raise_for_status.side_effect = httpx.HTTPStatusError(
            "error", request=MagicMock(), response=error
        )
    else:
        mock.raise_for_status = MagicMock()
    return mock


def test_health(client):
    tc, _, _ = client
    resp = tc.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


def test_create_task(client):
    tc, producer, _ = client
    resp = tc.post("/tasks", json={"title": "My task", "description": "Do it"})
    assert resp.status_code == 202
    assert "task_id" in resp.json()
    producer.publish.assert_called_once()
    event, task_id, payload = producer.publish.call_args[0]
    assert event == "created"
    assert payload["title"] == "My task"


def test_create_task_missing_title(client):
    tc, _, _ = client
    resp = tc.post("/tasks", json={"description": "no title"})
    assert resp.status_code == 422


def test_list_tasks(client):
    tc, _, http_client = client
    http_client.get.return_value = make_response(200, [TASK_STUB])
    resp = tc.get("/tasks")
    assert resp.status_code == 200
    assert len(resp.json()) == 1
    assert resp.json()[0]["title"] == "T1"


def test_get_task(client):
    tc, _, http_client = client
    http_client.get.return_value = make_response(200, TASK_STUB)
    resp = tc.get(f"/tasks/{TASK_ID}")
    assert resp.status_code == 200
    assert resp.json()["id"] == TASK_ID


def test_get_task_not_found(client):
    tc, _, http_client = client
    http_client.get.return_value = make_response(404)
    resp = tc.get("/tasks/missing")
    assert resp.status_code == 404


def test_update_task(client):
    tc, producer, http_client = client
    http_client.get.return_value = make_response(200, {"id": "abc", "title": "T1"})
    resp = tc.put("/tasks/abc", json={"status": "done"})
    assert resp.status_code == 202
    event, task_id, payload = producer.publish.call_args[0]
    assert event == "updated"
    assert payload == {"status": "done"}
    assert task_id == "abc"


def test_update_task_not_found(client):
    tc, _, http_client = client
    http_client.get.return_value = make_response(404)
    resp = tc.put("/tasks/missing", json={"status": "done"})
    assert resp.status_code == 404


def test_update_task_empty_body(client):
    tc, _, http_client = client
    http_client.get.return_value = make_response(200, {"id": "abc"})
    resp = tc.put("/tasks/abc", json={})
    assert resp.status_code == 400


def test_delete_task(client):
    tc, producer, http_client = client
    http_client.get.return_value = make_response(200, {"id": "abc"})
    resp = tc.delete("/tasks/abc")
    assert resp.status_code == 202
    assert producer.publish.call_args[0][0] == "deleted"


def test_delete_task_not_found(client):
    tc, _, http_client = client
    http_client.get.return_value = make_response(404)
    resp = tc.delete("/tasks/missing")
    assert resp.status_code == 404
