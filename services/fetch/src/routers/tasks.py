from fastapi import APIRouter, HTTPException, Request

from ..db import repository
from ..models.task import TaskResponse

router = APIRouter(prefix="/tasks", tags=["tasks"])


@router.get("", response_model=list[TaskResponse])
async def list_tasks(request: Request):
    rows = await repository.get_all_tasks(request.app.state.db)
    return [dict(row) for row in rows]


@router.get("/{task_id}", response_model=TaskResponse)
async def get_task(task_id: str, request: Request):
    row = await repository.get_task_by_id(request.app.state.db, task_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return dict(row)
