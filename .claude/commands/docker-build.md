Build Docker images for the task manager services.

If $ARGUMENTS specifies a service name (api, ingest, or fetch), build only that service. Otherwise build all services.

Running from the repo root builds the **dev** target (hot-reload, editable install) because
`docker-compose.override.yml` is loaded automatically by Docker Compose:
```bash
docker compose build $ARGUMENTS
```

To build the **production** target (as CI does), suppress the override file:
```bash
docker compose -f docker-compose.yml build --target prod $ARGUMENTS
```

Report any build errors. If a build fails due to a missing dependency or changed pyproject.toml, suggest the fix.
