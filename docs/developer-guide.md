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
3. [Two modes](#two-modes)
4. [Day-to-day: development (Mode 1)](#day-to-day-development-mode-1)
5. [GitOps validation (Mode 2 — Kind)](#gitops-validation-mode-2--kind)

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
bash dev.sh setup
```

This installs CLI tools (Kind, kubectl, Helm, yq, pre-commit) and activates a git hook that scans every commit for hardcoded secrets.

**3. Open the repository** in VS Code. When prompted, click Reopen in Container (or run `Dev Containers: Reopen in Container` from `⇧⌘P`).

VS Code builds the dev container image on the first open — this takes a few minutes. Subsequent opens reuse the cached image and are fast. All six containers start automatically on a shared Docker network — this is equivalent to running `bash dev.sh up`:

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

## Two modes

The application can run locally in two ways. They differ in *where* the application services run, but they always share the same Postgres and Kafka — both of which run via Docker Compose regardless of mode.

```
┌── Mode 1 (Docker Compose) ──────┐   ┌── Mode 2 (Kind cluster) ────────┐
│  api (:8000) · fetch · ingest   │   │  api (:8080) · fetch · ingest   │
└────────────────┬────────────────┘   └────────────────┬────────────────┘
                 │                                     │
                 └──────────────────┬──────────────────┘
                                    ↓
                   ┌── Shared (Docker Compose) ──────┐
                   │        postgres · kafka         │
                   └─────────────────────────────────┘
```

| | Mode 1 | Mode 2 |
|---|---|---|
| **Purpose** | Active development | GitOps / CD pipeline validation |
| **Application runs as** | Docker Compose containers | Kubernetes pods (Kind cluster) |
| **API port** | `:8000` | `:8080` |
| **Kafka topic** | `tasks` | `tasks-kind` |
| **Start** | `bash dev.sh up` | `bash dev.sh up-kind` |
| **Stop** | `bash dev.sh down` | `bash dev.sh down-kind` |

Both modes can run simultaneously and share the same data — a task written via `:8000` is visible at `:8080`.

> **Mode 2 is not protected against Mode 1 shutdown.** Running `bash dev.sh down` while Mode 2 is active will cut the Kind pods off from postgres and kafka. If you need Mode 2 to remain functional, do not stop Mode 1 first.
>
> The reverse is protected: `bash dev.sh down-kind` checks whether Mode 1 is running before stopping postgres and kafka, and leaves them up if it is.

---

## Development (Mode 1)

### Making code changes

Hot reload is active for all three services. Save a `.py` file and the affected service restarts automatically. **No docker commands are needed for routine code changes.**

> **Note:** each save triggers a full service restart. If VS Code autosave is enabled, frequent saves — including mid-edit saves with syntax errors — will cause repeated restarts and unnecessary CPU load.

### Running tests [dev]

```bash
bash dev.sh test                        # all services, from repo root
bash dev.sh test services/api           # single service
bash dev.sh test services/ingest
bash dev.sh test services/fetch
```

Tests use mocks for all external dependencies (Kafka, PostgreSQL, HTTP). No running infrastructure is required.

### Running security scans locally

These mirror the CI security gates. Run before pushing — from both environments to cover all gates:

```bash
bash dev.sh scan   # Hadolint, Gitleaks, Trivy  [host]
bash dev.sh scan   # Bandit, pip-audit           [dev]
```

The command auto-detects the environment and runs the appropriate scans.

### Managing the stack [host]

```bash
bash dev.sh up                                      # start stack — runs in foreground, logs stream to terminal; Ctrl+C stops all containers
bash dev.sh up -d                                   # start stack detached — terminal returns immediately, containers keep running
docker compose logs -f [api|fetch|ingest]           # tail service logs (useful when running detached)
bash dev.sh build [api|fetch|ingest]                # rebuild after Dockerfile or pyproject.toml change
bash dev.sh down                                    # stop all containers
bash dev.sh down -v && bash dev.sh up               # reset database — destroys all data
```

> VS Code's **Rebuild Container** only rebuilds the `devcontainer` image. The application services are unaffected. Closing VS Code or detaching from the dev container stops all containers — equivalent to `bash dev.sh down`.

### Schema changes

The schema lives in `ops/infra/db/init.sql`. PostgreSQL only executes this file when the data volume is first created, so schema changes require a full reset:

```bash
# [host] — destroys all data
bash dev.sh down -v && bash dev.sh up
```

---

## GitOps validation (Mode 2)

Use this mode to validate the full CI/CD pipeline end-to-end: images are pulled from GHCR, ArgoCD manages the rollout, and the application runs in Kubernetes exactly as it would in production. **This is not needed for day-to-day development.**

> Mode 2 shares the same Postgres and Kafka instances as Mode 1. Both modes can run simultaneously but they share data — tasks created via `localhost:8000` are visible at `localhost:8080` and vice versa.

### Setup [host]

```bash
bash dev.sh up-kind                              # prompts for GitHub username
bash dev.sh up-kind -e image_owner=<username>    # non-interactive
```

This installs Kind, kubectl, Helm, yq, and Ansible Galaxy collections, starts postgres and kafka if they are not already running, then creates the Kind cluster and deploys ArgoCD. The command is idempotent — safe to re-run if anything fails midway, or to recreate the cluster after `down kind`.

### Accessing services [host]

| What | How |
|---|---|
| API | `http://localhost:8080` · Swagger at `http://localhost:8080/docs` |
| ArgoCD UI | `bash dev.sh argo` — prints credentials, opens `https://localhost:8443`, starts port-forward |

### Verifying a deployment [host]

```bash
kubectl get pods -n task-manager    # all three pods Running
kubectl get application -n argocd   # Synced / Healthy
curl http://localhost:8080/health   # {"status":"ok"}
```

Or run `bash dev.sh check-kind` for a full automated check.

### Tearing down [host]

```bash
bash dev.sh down-kind
```

This tears down the Kind cluster. If Mode 1 is not running, postgres and kafka are stopped as well. If Mode 1 is running, they are left up.

To stop Mode 1 afterwards:

```bash
bash dev.sh down
```

