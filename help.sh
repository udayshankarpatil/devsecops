#!/usr/bin/env bash
# Quick reference for task-manager developer tools.
# For full details see docs/developer-guide.md

cat <<'EOF'
┌─────────────────────────────────────────────────────────────────────────────┐
│  task-manager — developer quick reference                                   │
│  docs/developer-guide.md  ·  docs/port-mappings.md                          │
└─────────────────────────────────────────────────────────────────────────────┘

ONE-TIME SETUP  (host machine, Docker Desktop must be running)
  bash bootstrap.sh                          Install tools, bootstrap Kind cluster
  bash bootstrap.sh -e image_owner=<user>    Non-interactive (skip prompt)

HEALTH CHECKS
  bash scripts/check-setup.sh                Tools installed & Kind cluster ready?
  bash scripts/check-running.sh              Infra up, pods Running, API responding?

── MODE 1: docker-compose  (development) ────────────────────────────────────
  API: http://localhost:8000  ·  Swagger: http://localhost:8000/docs

  docker compose up                          Start all services + infra
  docker compose up postgres kafka           Start infra only
  docker compose down                        Stop
  docker compose down -v                     Stop + wipe database (destructive)
  docker compose build [api|ingest|fetch]    Rebuild images
  docker compose logs -f [api|ingest|fetch]  Tail service logs

── MODE 2: Kind / Kubernetes  (GitOps) ──────────────────────────────────────
  API: http://localhost:8080  ·  ArgoCD: https://localhost:8443 (see below)

  ansible-playbook ansible/kind-up.yml       Start Kind cluster + ArgoCD
  ansible-playbook ansible/kind-down.yml     Tear down cluster
  kubectl get pods -n task-manager           Pod status
  kubectl get application task-manager \
    -n argocd                                ArgoCD sync status
  kubectl port-forward svc/argocd-server \
    -n argocd 8443:443                       Expose ArgoCD UI

─────────────────────────────────────────────────────────────────────────────

TESTS  (run inside devcontainer or with deps installed)
  pytest                                     All services (from repo root)
  cd services/api     && pytest              Single service
  cd services/ingest  && pytest
  cd services/fetch   && pytest

API EXAMPLES  (replace <port> with 8000 for Mode 1, 8080 for Mode 2)
  curl -s http://localhost:<port>/health | jq
  curl -s http://localhost:<port>/tasks  | jq
  curl -s -X POST http://localhost:<port>/tasks \
    -H 'Content-Type: application/json' \
    -d '{"title":"t","description":"d","status":"pending"}' | jq
  curl -s -X PUT  http://localhost:<port>/tasks/<id> \
    -H 'Content-Type: application/json' \
    -d '{"status":"done"}' | jq
  curl -s -X DELETE http://localhost:<port>/tasks/<id> | jq

EOF
