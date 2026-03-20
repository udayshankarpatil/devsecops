#!/usr/bin/env bash
# Quick reference for task-manager developer tools.
# For full details see docs/developer-guide.md

cat <<'EOF'
┌─────────────────────────────────────────────────────────────────────────────┐
│  task-manager — developer quick reference                                   │
└─────────────────────────────────────────────────────────────────────────────┘

ONE-TIME SETUP  (host machine, Docker Desktop must be running)
  bash bootstrap.sh                          Install tools, bootstrap cluster
  bash bootstrap.sh -e image_owner=<user>   Non-interactive (skip prompt)

HEALTH CHECKS
  bash scripts/check-setup.sh               All dev tools installed & cluster ready?
  bash scripts/check-running.sh             Infra up, pods Running, API responding?

INFRASTRUCTURE  (docker-compose — postgres + kafka)
  docker compose up postgres kafka           Start infra
  docker compose down                        Stop infra
  docker compose down -v                     Stop + wipe database (destructive)
  docker compose logs -f [postgres|kafka]    Tail logs

CLUSTER
  ansible-playbook ansible/kind-up.yml       Start Kind cluster + ArgoCD
  ansible-playbook ansible/kind-down.yml     Tear down cluster
  kubectl get pods -n task-manager           Pod status
  kubectl get application task-manager \
    -n argocd                                ArgoCD sync status
  kubectl port-forward svc/argocd-server \
    -n argocd 8443:443                       Expose ArgoCD UI → https://localhost:8443

FULL STACK  (docker-compose — all services, no k8s)
  docker compose up                          Start everything
  docker compose build [api|ingest|fetch]    Rebuild images
  docker compose logs -f [api|ingest|fetch]  Tail service logs

TESTS
  pytest                                     All services (from repo root)
  cd services/api     && pytest              Single service
  cd services/ingest  && pytest
  cd services/fetch   && pytest

API  (port 8000 local / 8080 via Kind NodePort)
  curl -s http://localhost:8000/health | jq
  curl -s http://localhost:8000/tasks  | jq
  curl -s -X POST http://localhost:8000/tasks \
    -H 'Content-Type: application/json' \
    -d '{"title":"t","description":"d","status":"pending"}' | jq
  curl -s -X PUT  http://localhost:8000/tasks/<id> \
    -H 'Content-Type: application/json' \
    -d '{"status":"done"}' | jq
  curl -s -X DELETE http://localhost:8000/tasks/<id> | jq

EOF
