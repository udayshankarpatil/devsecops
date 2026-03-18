import httpx
from fastapi import HTTPException, Request


async def get_tasks(request: Request) -> list:
    try:
        resp = await request.app.state.http_client.get("/tasks")
        resp.raise_for_status()
        return resp.json()
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail=e.response.text)
    except httpx.RequestError as e:
        raise HTTPException(status_code=503, detail=f"Service C unavailable: {e}")


async def get_task(request: Request, task_id: str) -> dict:
    try:
        resp = await request.app.state.http_client.get(f"/tasks/{task_id}")
        resp.raise_for_status()
        return resp.json()
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail=e.response.text)
    except httpx.RequestError as e:
        raise HTTPException(status_code=503, detail=f"Service C unavailable: {e}")
