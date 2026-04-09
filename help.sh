#!/usr/bin/env bash
# Quick reference for task-manager developer tools.
# For full details see docs/developer-guide.md

cat <<'EOF'
┌─────────────────────────────────────────────────────────────────────────────┐
│  task-manager — developer quick reference                                   │
│  docs/developer-guide.md  ·  docs/port-mappings.md                          │
└─────────────────────────────────────────────────────────────────────────────┘

  [host] = macOS terminal (iTerm etc.)    [dev] = VS Code terminal (dev container)

SETUP  [host]  (once per machine / once per clone)
  bash ops/setup.sh                                   Install host tools + activate pre-commit hook

LOCAL DEV STACK [host]
  API: http://localhost:8000  ·  Swagger: http://localhost:8000/docs

  docker compose up                                   Start all services + infra
  docker compose up postgres kafka                    Start infra only
  docker compose down                                 Stop
  docker compose down -v                              Stop + wipe database (destructive)
  docker compose build [api|ingest|fetch]             Rebuild images
  docker compose logs -f [api|ingest|fetch]           Tail service logs

LOCAL CD STACK [host]
  API: http://localhost:8080  ·  ArgoCD: https://localhost:8443 (see below)

  bash ops/bootstrap.sh                               Provision Kind cluster + ArgoCD (idempotent)
  bash ops/bootstrap.sh -e image_owner=<user>         Non-interactive (skip prompt)
  ansible-playbook ops/ansible/kind-down.yml          Tear down cluster
  kubectl get pods -n task-manager                    Pod status
  kubectl get application task-manager -n argocd      ArgoCD sync status
  kubectl port-forward svc/argocd-server -n argocd 8443:443  Expose ArgoCD UI

HEALTH CHECKS  [host]
  bash ops/scripts/check-setup.sh                     Kind cluster + tools ready?
  bash ops/scripts/check-running.sh                   Infra up, pods Running, API responding?

TESTS  [dev]
  pytest                                              All services (from repo root)
  cd services/api     && pytest                       Single service
  cd services/ingest  && pytest
  cd services/fetch   && pytest

SECURITY SCANNING  (mirrors CI — run before pushing)
  # SAST — Bandit  [dev]
  cd services/api     && bandit -r src/ -ll -q
  cd services/fetch   && bandit -r src/ -ll -q
  cd services/ingest  && bandit -r src/ -ll -q

  # SCA — pip-audit  [dev]
  cd services/api     && pip-audit
  cd services/fetch   && pip-audit
  cd services/ingest  && pip-audit

  # Dockerfile linting — Hadolint  [host]
  hadolint --config ops/config/hadolint.yaml services/api/Dockerfile
  hadolint --config ops/config/hadolint.yaml services/fetch/Dockerfile
  hadolint --config ops/config/hadolint.yaml services/ingest/Dockerfile

  # Secret scanning — Gitleaks  [host]
  gitleaks detect --source . -v

  # IaC / misconfig scanning — Trivy  [host]
  trivy config --ignorefile ops/config/.trivyignore ops/
  trivy config --ignorefile ops/config/.trivyignore docker-compose.yml

  # Image scanning — Trivy  [host]  (run after docker build)
  trivy image --ignore-unfixed --severity CRITICAL,HIGH --ignorefile ops/config/.trivyignore <image>

  # Pre-commit hook — Gitleaks on every commit  [host]
  pre-commit run --all-files                          Run manually on all files

API EXAMPLES  [host] or [dev]  (replace <port> with 8000 for Mode 1, 8080 for Mode 2)
  curl -s http://localhost:<port>/health
  curl -s http://localhost:<port>/tasks
  curl -s -X POST http://localhost:<port>/tasks -H 'Content-Type: application/json' -d '{"title":"t","description":"d","status":"pending"}'
  curl -s -X PUT  http://localhost:<port>/tasks/<id> -H 'Content-Type: application/json' -d '{"status":"done"}'
  curl -s -X DELETE http://localhost:<port>/tasks/<id>

EOF
