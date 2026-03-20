# Developer Guide

## Quick Reference

For a one-screen summary of all commands without reading this document:

```bash
bash help.sh
```

## Two ways to run locally

| | Mode 1: docker-compose | Mode 2: Kind (local Kubernetes) |
|---|---|---|
| **Purpose** | Active development — hot reload, easy log tailing | Test the full GitOps/CD pipeline end-to-end |
| **Services run in** | Docker containers (bridge network) | Kubernetes pods (inside a Kind cluster) |
| **API reachable at** | `http://localhost:8000` | `http://localhost:8080` |
| **Infra (postgres, kafka)** | docker-compose | docker-compose (shared — pods connect to the same containers) |
| **Started with** | `docker compose up` | `ansible-playbook ops/ansible/kind-up.yml` |

See [docs/port-mappings.md](port-mappings.md) for a full breakdown of host ports and network topology.

---

## Mode 1 — docker-compose

Use this day-to-day during development. All three services run as Docker containers
with live source mounts and hot reload.

### Building images

Rebuild after changing a `Dockerfile` or `pyproject.toml`:

```bash
docker compose build          # all services
docker compose build api      # single service
```

### Running the application

```bash
# Full stack (all services + infra)
docker compose up

# Infrastructure only — run services locally via uvicorn/python directly
docker compose up postgres kafka

# Shutdown
docker compose down

# Shutdown and wipe the database
docker compose down -v
```

**Run a service locally** (from within the dev container or with deps installed):

```bash
# api
cd services/api
SERVICE_C_BASE_URL=http://localhost:8002 KAFKA_BOOTSTRAP_SERVERS=localhost:9092 \
  uvicorn api.main:app --reload --port 8000

# fetch
cd services/fetch
DATABASE_URL=postgresql://tasksuser:taskspass@localhost:5432/tasksdb \
  uvicorn fetch.main:app --reload --port 8002

# ingest
cd services/ingest
DATABASE_URL=postgresql://tasksuser:taskspass@localhost:5432/tasksdb \
KAFKA_BOOTSTRAP_SERVERS=localhost:9092 \
  python -m ingest.main
```

### Running tests

From VS Code, all tests are discoverable via the Test Explorer panel (beaker icon).

From a terminal:

```bash
pytest                          # all services from repo root
cd services/api    && pytest    # single service
cd services/ingest && pytest
cd services/fetch  && pytest
```

### curl examples

```bash
# Create a task
curl -s -X POST http://localhost:8000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "My first task", "description": "Do the thing", "status": "pending"}' | jq

# List tasks (allow a moment for ingest to write to the DB)
curl -s http://localhost:8000/tasks | jq

# Get a specific task
curl -s http://localhost:8000/tasks/<task_id> | jq

# Update a task
curl -s -X PUT http://localhost:8000/tasks/<task_id> \
  -H "Content-Type: application/json" \
  -d '{"status": "done"}' | jq

# Delete a task
curl -s -X DELETE http://localhost:8000/tasks/<task_id> | jq
```

### Schema changes

The schema lives in `ops/infra/db/init.sql`. PostgreSQL only runs this script when the
data volume is first created.

```bash
docker compose down -v && docker compose up
```

> **Warning:** `docker compose down -v` deletes all data.

---

## Mode 2 — Kind (local Kubernetes)

Use this to validate the full GitOps pipeline — images are pulled from GHCR,
ArgoCD manages the rollout, and the app runs as it would in a real cluster.
Postgres and Kafka are shared with docker-compose.

### How GitOps works

```
merge to dev
    │
    ▼
CI: build + push images to GHCR
    │
    ▼
CI: commit updated SHA tags to gitops branch (ops/helm/task-manager/values.yaml)
    │
    ▼
ArgoCD: detects gitops change, syncs Kind cluster
    │
    ▼
Kind: rolls out new pods
```

ArgoCD watches the `gitops` branch, not `dev`. The `gitops` branch is written only
by CI and is never edited by hand.

### Prerequisites (host machine — not inside devcontainer)

- macOS with [Homebrew](https://brew.sh)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running

Everything else (Ansible, Kind, kubectl, Helm, yq, Galaxy collections) is
installed automatically by `ops/bootstrap.sh`.

### One-time setup

**1. Start docker-compose infrastructure**

```bash
docker compose up postgres kafka
```

**2. Verify `ops/argocd/application.yaml`** — `repoURL` is set to your repository URL.

**3. Verify `ops/helm/task-manager/values.yaml`** — `image.owner` is set to your GitHub username.

**4. Initialise the gitops branch** (only needed once — CI manages it after this)

```bash
git checkout --orphan gitops
git rm -rf .
mkdir -p ops/helm
cp -r ops/helm/task-manager ops/helm/
git add ops/helm/
git commit -m "init: gitops branch"
git push origin gitops
git checkout dev
```

**5. Bootstrap tools and the cluster**

```bash
bash ops/bootstrap.sh                                    # prompts for GitHub username
bash ops/bootstrap.sh -e image_owner=<github-username>  # non-interactive
```

The script installs Ansible if missing, runs `ops/ansible/dev-setup.yml` (tools +
Galaxy collections), then runs `ops/ansible/kind-up.yml` (Kind cluster + ArgoCD).
Both playbooks are idempotent — safe to re-run if anything fails midway.

### Accessing the cluster

| What | How |
|---|---|
| API | `http://localhost:8080` |
| ArgoCD UI | `kubectl port-forward svc/argocd-server -n argocd 8443:443` → `https://localhost:8443` |
| ArgoCD initial password | `kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' \| base64 -d` |

### Verifying a deployment

```bash
kubectl get pods -n task-manager     # all three pods Running
kubectl get application -n argocd    # Synced / Healthy
curl http://localhost:8080/health    # {"status":"ok"}
```

### Tearing down

```bash
ansible-playbook ops/ansible/kind-down.yml
```

docker-compose services are left running. Run `docker compose down` separately if needed.

---

## Check scripts

```bash
bash ops/scripts/check-setup.sh     # tools, Docker daemon, Galaxy collections, Kind cluster
bash ops/scripts/check-running.sh   # infra, pods, ArgoCD sync, API /health
```

`check-running.sh` targets Mode 2 (Kind). For Mode 1, use `docker compose ps` and
`curl http://localhost:8000/health`.

---

## CI Pipeline

The workflow lives in `.github/workflows/ci.yml`:

| Event | Jobs that run |
|---|---|
| PR opened / updated against `dev` | **test** (all three services) |
| PR merged into `dev` | **test** → **build** (push images to GHCR) → **update-gitops** (pin SHA in ops/helm/values.yaml) |

### Day-to-day developer workflow

1. Branch off `dev`, make your changes, open a PR back to `dev`.
2. The three test jobs run automatically. All must be green before the PR can be merged.
3. On merge, production images are built and pushed to GHCR tagged with the commit SHA and a floating `dev` tag.

### One-time repo setup (owner only)

**1. Allow Actions to push packages**

Settings → Actions → General → Workflow permissions → **Read and write permissions**

**2. Protect the branch** (optional but recommended)

Settings → Branches → Add rule for `dev`:
- Enable **Require status checks to pass before merging**
- Add checks: `Test api`, `Test fetch`, `Test ingest`

**3. Make GHCR images public** (after the first merge triggers a build)

Navigate to `github.com/<you>?tab=packages`, open each package, set visibility to
**Public**. This avoids needing pull credentials in Kubernetes.

### Published images

```
ghcr.io/<owner>/task-manager/api:<commit-sha>     # immutable — pinned by gitops branch
ghcr.io/<owner>/task-manager/api:dev              # floating — latest merged build
ghcr.io/<owner>/task-manager/fetch:<commit-sha>
ghcr.io/<owner>/task-manager/fetch:dev
ghcr.io/<owner>/task-manager/ingest:<commit-sha>
ghcr.io/<owner>/task-manager/ingest:dev
```
