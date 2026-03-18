Run the unit test suite for all three services and report results.

Run from the repo root (subshells keep each service's test context isolated):
```bash
(cd services/api && pytest -v) && (cd services/ingest && pytest -v) && (cd services/fetch && pytest -v)
```

Summarise which tests passed and which failed. For any failures, show the error details and suggest a fix.
