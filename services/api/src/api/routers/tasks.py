import uuid

from fastapi import APIRouter, HTTPException, Request, status

from ..clients import fetch
from ..models.task import TaskCreate, TaskResponse, TaskUpdate

router = APIRouter(prefix="/tasks", tags=["tasks"])


@router.post("", status_code=status.HTTP_202_ACCEPTED)
async def create_task(body: TaskCreate, request: Request):
    task_id = str(uuid.uuid4())
    await request.app.state.producer.publish("created", task_id, body.model_dump())
    return {"task_id": task_id}


@router.get("", response_model=list[TaskResponse])
async def list_tasks(request: Request):
    return await fetch.get_tasks(request)


@router.get("/{task_id}", response_model=TaskResponse)
async def get_task(task_id: str, request: Request):
    return await fetch.get_task(request, task_id)


@router.put("/{task_id}", status_code=status.HTTP_202_ACCEPTED)
async def update_task(task_id: str, body: TaskUpdate, request: Request):
    await fetch.get_task(request, task_id)  # verify exists
    payload = body.model_dump(exclude_unset=True)
    if not payload:
        raise HTTPException(status_code=400, detail="No fields to update")
    await request.app.state.producer.publish("updated", task_id, payload)
    return {"task_id": task_id}


@router.delete("/{task_id}", status_code=status.HTTP_202_ACCEPTED)
async def delete_task(task_id: str, request: Request):
    await fetch.get_task(request, task_id)  # verify exists
    await request.app.state.producer.publish("deleted", task_id, {})
    return {"task_id": task_id}
