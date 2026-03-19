# Developer Guide

## Building Docker Images

Rebuild after changing a `Dockerfile` or `pyproject.toml`:

```bash
# Rebuild all services
docker compose build

# Rebuild a single service
docker compose build api
```

## Running the Application


```bash
# Full stack
docker compose up

# Infrastructure only (run services locally during development):
docker compose up postgres kafka

# Shutdown
docker compose down
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

## Running Tests

From VS Code, all tests across all three services are discoverable and runnable via the Test Explorer panel (the beaker icon). Tests can be run individually, by service, or all at once.

From a terminal inside the dev container:

```bash
(cd services/api && pytest -v) && (cd services/ingest && pytest -v) && (cd services/fetch && pytest -v)
```

Or per service:

```bash
cd services/api && pytest
cd services/ingest && pytest
cd services/fetch && pytest
```

## curl examples

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

## CI Pipeline

The workflow lives in `.github/workflows/ci.yml` and has two jobs:

| Event | Jobs that run |
|---|---|
| PR opened / updated against `dev` | **test** (all three services) |
| PR merged into `dev` | **test** → **build** (push images to GHCR) → **update-gitops** (pin SHA in helm/values.yaml) |

### Day-to-day developer workflow

1. Branch off `dev`, make your changes, open a PR back to `dev`.
2. The three test jobs run automatically. All must be green before the PR can be merged (if branch protection is configured — see below).
3. On merge, production images are built and pushed to GHCR tagged with the commit SHA and a floating `dev` tag.

### One-time repo setup (owner only)

**1. Allow Actions to push packages**

Settings → Actions → General → Workflow permissions → **Read and write permissions**

**2. Protect the branch** (optional but recommended)

Settings → Branches → Add rule for `dev`:
- Enable **Require status checks to pass before merging**
- Add checks: `Test api`, `Test fetch`, `Test ingest`

**3. Make GHCR images public** (after the first merge triggers a build)

Navigate to `github.com/<you>?tab=packages`, open each of the three packages, and set visibility to **Public**. This avoids needing pull credentials in Kubernetes later.

### GITHUB_TOKEN

No secret creation is needed. GitHub injects `GITHUB_TOKEN` into every workflow run automatically. The `packages: write` permission declared in the build job is sufficient for pushing to GHCR.

### Published images

After each merge into `dev`:

```sh
ghcr.io/<owner>/task-manager/api:<commit-sha>     # immutable — use this for deployments
ghcr.io/<owner>/task-manager/api:dev              # floating — always points to latest merge
ghcr.io/<owner>/task-manager/fetch:<commit-sha>
ghcr.io/<owner>/task-manager/fetch:dev
ghcr.io/<owner>/task-manager/ingest:<commit-sha>
ghcr.io/<owner>/task-manager/ingest:dev
```

## CD — Local Kubernetes with Kind and ArgoCD

The CD setup runs the three app services in a local [Kind](https://kind.sigs.k8s.io/) (Kubernetes-in-Docker) cluster. Postgres and Kafka remain in docker-compose; the Kind node is connected to the same Docker network so pods can reach them by name without any config changes.

### How GitOps works

```
merge to dev
    │
    ▼
CI: build + push images to GHCR
    │
    ▼
CI: commit updated SHA tags to gitops branch (helm/task-manager/values.yaml)
    │
    ▼
ArgoCD: detects gitops change, syncs Kind cluster
    │
    ▼
Kind: rolls out new pods
```

ArgoCD watches the `gitops` branch, not `dev`. The `gitops` branch is written only by CI and is never edited by hand.

### Prerequisites (host machine — not inside devcontainer)

```bash
brew install ansible kind kubectl helm yq
ansible-galaxy collection install -r ansible/requirements.yml
```

### One-time setup

**1. Start docker-compose infrastructure**

```bash
docker compose up postgres kafka
```

**2. Verify `argocd/application.yaml`** — `repoURL` is set to `https://github.com/udayshankarpatil/devsecops.git`.

**3. Verify `helm/task-manager/values.yaml`** — `image.owner` is set to `udayshankarpatil`.

**4. Initialise the gitops branch** (only needed once — CI manages it after this)

```bash
git checkout --orphan gitops
git rm -rf .
mkdir -p helm
cp -r helm/task-manager helm/   # copy chart from dev branch first
git add helm/
git commit -m "init: gitops branch"
git push origin gitops
git checkout dev
```

**5. Bootstrap the cluster**

```bash
ansible-playbook ansible/kind-up.yml -e image_owner=<your-github-username>
```

This is idempotent — safe to run again if anything fails midway.

### Accessing the cluster

| What | How |
|---|---|
| API (via Kind NodePort) | `http://localhost:8080` |
| ArgoCD UI | `kubectl port-forward svc/argocd-server -n argocd 8443:443` → `https://localhost:8443` |
| ArgoCD initial password | `kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' \| base64 -d` |

### Tearing down

```bash
ansible-playbook ansible/kind-down.yml
```

docker-compose services are left running. Run `docker compose down` separately if needed.

### Verifying a deployment

After a merge triggers CI and ArgoCD syncs:

```bash
kubectl get pods -n task-manager          # all three pods Running
kubectl get application -n argocd         # Synced / Healthy
curl http://localhost:8080/health         # {"status":"ok"} from api pod
```

## Schema Changes

The database schema lives in `infra/db/init.sql`. PostgreSQL only runs this script when the data volume is first created.

To apply schema changes during development:

1. Edit `infra/db/init.sql`.
2. Destroy the data volume and restart:
   ```bash
   docker compose down -v && docker compose up
   ```

> **Warning:** `docker compose down -v` deletes all data. Never run this against an environment with data you need to keep.
