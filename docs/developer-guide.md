# Developer Guide

> For a one-screen command reference run `bash help.sh`.

> **Terminal context:** `[host]` = macOS terminal (iTerm etc.) · `[dev]` = VS Code terminal (runs inside the dev container). Commands are labelled throughout this guide. `docker compose` commands must always be `[host]` — running them from VS Code resolves volume mount paths incorrectly.

## Contents

- [Two ways to run locally](#two-ways-to-run-locally)
- [Mode 1 — docker-compose](#mode-1--docker-compose)
- [Mode 2 — Kind (local Kubernetes)](#mode-2--kind-local-kubernetes)
- [CI/CD Pipeline](ci-cd.md)

## Two ways to run locally

| | Mode 1: docker-compose | Mode 2: Kind (local Kubernetes) |
|---|---|---|
| **Purpose** | Active development — hot reload, easy log tailing | Test the full GitOps/CD pipeline end-to-end |
| **Services run in** | Docker containers (bridge network) | Kubernetes pods (inside a Kind cluster) |
| **API reachable at** | `http://localhost:8000` | `http://localhost:8080` |
| **Infra (postgres, kafka)** | docker-compose | docker-compose (shared — pods connect to the same containers) |
| **Started with** | `docker compose up` | `ansible-playbook ops/ansible/kind-up.yml` |

Both modes can run at the same time — the API ports don't conflict. However, they are **not isolated**: Mode 2 reuses the same Postgres and Kafka containers as Mode 1, so both modes share the same data. Tasks created via `localhost:8000` will appear at `localhost:8080` and vice versa.

See [port-mappings.md](port-mappings.md) for host port assignments and network topology.

---

## Mode 1 — docker-compose

Use this day-to-day during development. All three services run as Docker containers
with live source mounts and hot reload.

```bash
# [host]
docker compose up                           # Start full stack
docker compose up postgres kafka            # Start infra only
docker compose build [api|ingest|fetch]     # Rebuild after Dockerfile/pyproject.toml change
docker compose down                         # Shutdown
docker compose down -v                      # Shutdown + wipe database (destructive)
```

**Run a service locally** `[dev]`:

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

**Tests** `[dev]` — also discoverable via VS Code Test Explorer (beaker icon):

```bash
pytest                          # all services from repo root
cd services/api    && pytest    # single service
cd services/ingest && pytest
cd services/fetch  && pytest
```

**Schema changes** `[host]` — the schema lives in `ops/infra/db/init.sql`. PostgreSQL only
runs this script when the data volume is first created:

```bash
docker compose down -v && docker compose up   # Warning: destroys all data
```

See [api-reference.md](api-reference.md) for endpoint reference and curl examples.

Verify with `docker compose ps` and `curl http://localhost:8000/health`.

---

## Mode 2 — Kind (local Kubernetes)

Use this to validate the full GitOps pipeline — images are pulled from GHCR,
ArgoCD manages the rollout, and the app runs as it would in a real cluster.
Postgres and Kafka are shared with docker-compose. See [ci-cd.md](ci-cd.md) for
how the pipeline works.

### Prerequisites `[host]`

- macOS with [Homebrew](https://brew.sh)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running

Everything else (Ansible, Kind, kubectl, Helm, yq, Galaxy collections) is
installed automatically by `ops/bootstrap.sh`.

### One-time setup `[host]`

**1.** Start docker-compose infrastructure:

```bash
docker compose up postgres kafka
```

**2.** Verify `ops/argocd/application.yaml` — `repoURL` is set to your repository URL.

**3.** Verify `ops/helm/task-manager/values.yaml` — `image.owner` is set to your GitHub username.

**4.** Initialise the gitops branch (only needed once — CI manages it after this):

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

**5.** Bootstrap tools and the cluster:

```bash
bash ops/bootstrap.sh                                    # prompts for GitHub username
bash ops/bootstrap.sh -e image_owner=<github-username>  # non-interactive
```

Both playbooks are idempotent — safe to re-run if anything fails midway.

### Accessing the cluster

| What | How |
|---|---|
| API | `http://localhost:8080` |
| ArgoCD UI | `kubectl port-forward svc/argocd-server -n argocd 8443:443` → `https://localhost:8443` |
| ArgoCD initial password | `kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' \| base64 -d` |

### Verifying a deployment `[host]`

```bash
kubectl get pods -n task-manager     # all three pods Running
kubectl get application -n argocd    # Synced / Healthy
curl http://localhost:8080/health    # {"status":"ok"}
```

Or run `bash ops/scripts/check-running.sh` for a full automated check.

### Tearing down `[host]`

```bash
ansible-playbook ops/ansible/kind-down.yml
```

docker-compose services are left running. Run `docker compose down` separately if needed.
