#!/usr/bin/env bash
# Quick reference for task-manager developer tools.
# Invoked via: bash dev.sh help
# For full details see docs/developer-guide.md

cat <<'EOF'
┌─────────────────────────────────────────────────────────────────────────────┐
│  task-manager — developer quick reference                                   │
│  docs/developer-guide.md  ·  docs/port-mappings.md                          │
└─────────────────────────────────────────────────────────────────────────────┘

  [host] = macOS terminal (iTerm etc.)    [dev] = VS Code terminal (dev container)

SETUP  [host]  (once per machine / once per clone)
  bash dev.sh setup                                   Install host tools + activate pre-commit hook

LOCAL DEV STACK  Mode 1  [host]
  API: http://localhost:8000  ·  Swagger: http://localhost:8000/docs

  bash dev.sh up                                      Start all services + infra (foreground; Ctrl+C stops all)
  bash dev.sh up -d                                   Start detached (terminal returns; containers keep running)
  bash dev.sh up postgres kafka                       Start infra only
  bash dev.sh down                                    Stop
  bash dev.sh down -v                                 Stop + wipe database (destructive)
  bash dev.sh build [api|ingest|fetch]                Rebuild images
  docker compose logs -f [api|ingest|fetch]           Tail service logs

LOCAL CD STACK  Mode 2  [host]
  API: http://localhost:8080  ·  ArgoCD: https://localhost:8443 (see below)

  bash dev.sh up-kind                                 Provision Kind cluster + ArgoCD (idempotent)
  bash dev.sh up-kind -e image_owner=<user>           Non-interactive (skip prompt)
  bash dev.sh down-kind                               Tear down cluster (protects Mode 1 infra)
  kubectl get pods -n task-manager                    Pod status
  kubectl get application task-manager -n argocd      ArgoCD sync status
  bash dev.sh argo                                    Open ArgoCD UI (prints credentials + port-forwards)

HEALTH CHECKS  [host]
  bash ops/scripts/check-setup.sh                     Kind cluster + tools ready?
  bash dev.sh check                                   Mode 1: infra + services + API at :8000
  bash dev.sh check-kind                              Mode 2: infra + cluster + pods + API at :8080

TESTS  [dev]
  bash dev.sh test                                    All services (from repo root)
  bash dev.sh test services/api                       Single service
  bash dev.sh test services/ingest
  bash dev.sh test services/fetch

SECURITY SCANNING  (mirrors CI — run before pushing)
  bash dev.sh scan                                    Hadolint, Gitleaks, Trivy  [host]
  bash dev.sh scan                                    Bandit, pip-audit  [dev]

  # Pre-commit hook — Gitleaks on every commit  [host]
  pre-commit run --all-files                          Run manually on all files

API EXAMPLES  [host] or [dev]  (replace <port> with 8000 for Mode 1, 8080 for Mode 2)
  curl -s http://localhost:<port>/health
  curl -s http://localhost:<port>/tasks
  curl -s -X POST http://localhost:<port>/tasks -H 'Content-Type: application/json' -d '{"title":"t","description":"d","status":"pending"}'
  curl -s -X PUT  http://localhost:<port>/tasks/<id> -H 'Content-Type: application/json' -d '{"status":"done"}'
  curl -s -X DELETE http://localhost:<port>/tasks/<id>

EOF
