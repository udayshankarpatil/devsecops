[← README](../README.md)

# Developer Guide


This project uses a dev container for all Python work, but some commands must run on the host machine. Throughout this guide:

- **[host]** — your macOS terminal (iTerm, Terminal, etc.)
- **[dev]** — a VS Code terminal, which runs inside the dev container

> `docker compose` commands must always be run [host]. When run from a VS Code terminal, volume mount paths resolve incorrectly.

For a one-screen command reference, run `bash dev.sh help`.

## Contents

1. [Prerequisites](#prerequisites)
2. [One-time setup](#one-time-setup)
3. [Day-to-day: development (Mode 1)](#day-to-day-development-mode-1)
4. [GitOps validation (Mode 2 — Kind)](#gitops-validation-mode-2--kind)

---

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) — must be installed and running

- [VS Code](https://code.visualstudio.com/) with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

- macOS with [Homebrew](https://brew.sh) — all other tools are installed by `bash ops/setup.sh`

---

## Setup

Performed once per machine, or once per fresh clone.

**1. Clone the repository** and `cd` into it [host].

**2. Install host tools** [host]:

```bash
bash ops/setup.sh
```

This installs CLI tools (Kind, kubectl, Helm, yq, pre-commit) and activates a git hook that scans every commit for hardcoded secrets.

**3. Open the repository** in VS Code. When prompted, click Reopen in Container (or run `Dev Containers: Reopen in Container` from `⇧⌘P`).

VS Code builds the dev container image on the first open — this takes a few minutes. Subsequent opens reuse the cached image and are fast. All six containers start automatically on a shared Docker network:

| Container | Role |
|---|---|
| `devcontainer` | Your VS Code shell — where your terminal and editor run |
| `api` | REST gateway · `http://localhost:8000` · live source mount + hot reload |
| `fetch` | Read service · live source mount + hot reload |
| `ingest` | Kafka consumer · live source mount + hot reload |
| `postgres` | Database |
| `kafka` | Message broker |

**4. Verify the stack** is running [host OR dev]:

```bash
curl http://localhost:8000/health
# → {"status":"ok"}
```

---

## Development (Mode 1)

### Making code changes

Hot reload is active for all three services. Save a `.py` file and the affected service restarts automatically. **No docker commands are needed for routine code changes.**

> **Note:** each save triggers a full service restart. If VS Code autosave is enabled, frequent saves — including mid-edit saves with syntax errors — will cause repeated restarts and unnecessary CPU load.

### Running tests [dev]

```bash
pytest                          # all services, from repo root
cd services/api    && pytest    # single service
cd services/ingest && pytest
cd services/fetch  && pytest
```

Tests use mocks for all external dependencies (Kafka, PostgreSQL, HTTP). No running infrastructure is required.

### Running security scans locally

These mirror the CI security gates. Two scripts cover all gates — run both before pushing:

```bash
bash ops/scripts/scan-host.sh   # Hadolint, Gitleaks, Trivy  [host]
bash ops/scripts/scan-dev.sh    # Bandit, pip-audit           [dev]
```

Each script detects the wrong environment and aborts with a clear message if invoked in the wrong context.

### Managing the stack [host]

```bash
docker compose logs -f [api|fetch|ingest]     # tail service logs
docker compose build [api|fetch|ingest]       # rebuild after Dockerfile or pyproject.toml change
docker compose down                           # stop all containers
docker compose up                             # restart stopped containers
docker compose down -v && docker compose up   # reset database — destroys all data
```

> VS Code's **Rebuild Container** only rebuilds the `devcontainer` image. The application services are unaffected. Closing VS Code leaves all containers running — they must be stopped explicitly with `docker compose down`.

### Schema changes

The schema lives in `ops/infra/db/init.sql`. PostgreSQL only executes this file when the data volume is first created, so schema changes require a full reset:

```bash
# [host] — destroys all data
docker compose down -v && docker compose up
```

---

## GitOps validation (Mode 2)

Use this mode to validate the full CI/CD pipeline end-to-end: images are pulled from GHCR, ArgoCD manages the rollout, and the application runs in Kubernetes exactly as it would in production. **This is not needed for day-to-day development.**

> Mode 2 shares the same Postgres and Kafka instances as Mode 1. Both modes can run simultaneously but they share data — tasks created via `localhost:8000` are visible at `localhost:8080` and vice versa.

### Setup [host]

```bash
bash ops/bootstrap.sh                                    # prompts for GitHub username
bash ops/bootstrap.sh -e image_owner=<github-username>  # non-interactive
```

This installs Kind, kubectl, Helm, yq, and Ansible Galaxy collections, starts Postgres and Kafka if they are not already running, then creates the Kind cluster and deploys ArgoCD. The script is idempotent — safe to re-run if anything fails midway, or to recreate the cluster after `kind-down`.

### Accessing services [host]

| What | How |
|---|---|
| API | `http://localhost:8080` · Swagger at `http://localhost:8080/docs` |
| ArgoCD UI | `kubectl port-forward svc/argocd-server -n argocd 8443:443` → `https://localhost:8443` |
| ArgoCD initial password | `kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' \| base64 -d` |

### Verifying a deployment [host]

```bash
kubectl get pods -n task-manager    # all three pods Running
kubectl get application -n argocd   # Synced / Healthy
curl http://localhost:8080/health   # {"status":"ok"}
```

Or run `bash ops/scripts/check-running.sh` for a full automated check.

### Tearing down [host]

```bash
ansible-playbook ops/ansible/kind-down.yml
# Docker Compose services remain running; stop them separately if needed:
docker compose down
```

