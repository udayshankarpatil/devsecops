Build Docker images for the task manager services.

If $ARGUMENTS specifies a service name (api, ingest, or fetch), build only that service. Otherwise build all services.

Run from the repo root:
```bash
docker compose build $ARGUMENTS
```

Report any build errors. If a build fails due to a missing dependency or changed pyproject.toml, suggest the fix.
