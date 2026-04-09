[← README](../README.md)

# Project Structure

## Repository Layout

```
devsecops/
├── .claude/                  # Claude Code slash commands (/docker-build, /test-all, /logs)
├── .devcontainer/            # VS Code Dev Container config and dev image Dockerfile
├── .github/
│   └── workflows/
│       └── ci.yml            # CI: tests on PR, build + push to GHCR on merge, update gitops branch
├── docs/                     # Extended documentation
│   ├── api-reference.md      # Endpoint reference and Swagger UI links
│   ├── ci-cd.md              # CI/CD pipeline and GitOps workflow
│   ├── developer-guide.md    # Full developer workflows (Docker Compose and Kind)
│   ├── port-mappings.md      # Host port tables and network topology
│   └── project-structure.md  # Repository layout and tech stack (this file)
├── ops/                      # All operational infrastructure (non-application code)
│   ├── ansible/              # Idempotent playbooks for local environment management
│   │   ├── dev-setup.yml     # Install host-machine tools (Homebrew + Galaxy collections)
│   │   ├── kind-config.yaml  # Kind cluster definition (NodePort mapping)
│   │   ├── kind-up.yml       # Bootstrap Kind + ArgoCD + secrets
│   │   ├── kind-down.yml     # Tear down the Kind cluster
│   │   └── requirements.yml  # Ansible collection dependencies
│   ├── argocd/
│   │   └── application.yaml  # ArgoCD Application — watches gitops branch
│   ├── helm/
│   │   └── task-manager/     # Helm chart for k8s deployment (api, fetch, ingest)
│   ├── infra/
│   │   └── db/
│   │       └── init.sql      # PostgreSQL schema (tasks table + updated_at trigger)
│   ├── scripts/
│   │   ├── check-setup.sh    # Verify one-time dev setup is complete
│   │   └── check-running.sh  # Verify application is deployed and running
│   ├── setup.sh              # Host machine setup: install tools + activate pre-commit hook (once per clone)
│   └── bootstrap.sh          # Provision the local Kind cluster + ArgoCD for GitOps validation (idempotent)
├── services/
│   ├── api/                  # Gateway: FastAPI REST API, Kafka producer, HTTP client to fetch
│   ├── ingest/               # Ingestion: Kafka consumer, asyncpg writes to PostgreSQL
│   └── fetch/                # Retrieval: FastAPI read-only API, asyncpg queries
├── help.sh                   # Quick reference for all developer commands
├── CLAUDE.md                 # Project conventions and context for Claude Code
├── docker-compose.yml        # Full-stack orchestration (all services + Kafka + PostgreSQL)
├── docker-compose.override.yml  # Dev overrides: live-reload targets and source volume mounts
├── pytest.toml               # Workspace-root pytest config for unified test discovery
└── README.md
```

Each service directory shares the same layout:

```
service-name/
├── src/
│   └── <service-name>/   # Python package (src layout — package name matches service name)
├── tests/                # pytest unit tests
├── Dockerfile            # Multi-stage image: base → prod / base → dev
└── pyproject.toml        # Project metadata, dependencies, and pytest configuration
```
