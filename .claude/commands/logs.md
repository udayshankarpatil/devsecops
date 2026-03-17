Show recent logs from the running task manager stack.

If $ARGUMENTS specifies a service name (api, ingest, fetch, postgres, or kafka), show logs for that service only. Otherwise show logs for all services.

```bash
docker compose logs --tail=100 $ARGUMENTS
```

Highlight any ERROR or WARN lines and explain what they mean if they look like a known issue.
