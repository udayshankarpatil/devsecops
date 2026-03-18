from datetime import datetime, timezone
from unittest.mock import patch
from uuid import uuid4


def make_task(**kwargs):
    defaults = {
        "id": uuid4(),
        "title": "Test Task",
        "description": None,
        "status": "pending",
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc),
    }
    defaults.update(kwargs)
    return defaults


def test_health(client):
    tc, _ = client
    resp = tc.get("/health")
    assert resp.status_code == 200


def test_list_tasks(client):
    tc, _ = client
    task = make_task(title="Task 1")
    with patch("fetch.db.repository.get_all_tasks", return_value=[task]):
        resp = tc.get("/tasks")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 1
    assert data[0]["title"] == "Task 1"


def test_list_tasks_empty(client):
    tc, _ = client
    with patch("fetch.db.repository.get_all_tasks", return_value=[]):
        resp = tc.get("/tasks")
    assert resp.status_code == 200
    assert resp.json() == []


def test_get_task(client):
    tc, _ = client
    task_id = uuid4()
    task = make_task(id=task_id, title="My Task")
    with patch("fetch.db.repository.get_task_by_id", return_value=task):
        resp = tc.get(f"/tasks/{task_id}")
    assert resp.status_code == 200
    assert resp.json()["title"] == "My Task"


def test_get_task_not_found(client):
    tc, _ = client
    with patch("fetch.db.repository.get_task_by_id", return_value=None):
        resp = tc.get("/tasks/nonexistent")
    assert resp.status_code == 404
