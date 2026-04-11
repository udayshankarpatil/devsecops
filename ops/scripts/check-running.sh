#!/usr/bin/env bash
# check-running.sh — verify the application is deployed and running locally.
#
# Checks Docker Compose infrastructure, the Kind cluster, pod health, ArgoCD
# sync status, and the API /health endpoint.
# Exit code 0 = all checks passed; 1 = one or more failed.
#
# Usage:
#   bash ops/scripts/check-running.sh

set -uo pipefail

if [ -f /.dockerenv ]; then
    echo "Error: check-running.sh must be run from the host machine, not the dev container." >&2
    exit 1
fi

cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

PASS=0
FAIL=0

check() {
    local label="$1"
    local cmd="$2"
    if eval "$cmd" >/dev/null 2>&1; then
        printf "  ✓  %s\n" "$label"
        PASS=$((PASS + 1))
    else
        printf "  ✗  %s\n" "$label"
        FAIL=$((FAIL + 1))
    fi
}

# ── Infrastructure (Docker Compose) ───────────────────────────────────────────
echo "── Infrastructure (Docker Compose) ──────────────────────────────────────"
check "postgres running" "docker compose ps --status running 2>/dev/null | grep -q postgres"
check "kafka running"    "docker compose ps --status running 2>/dev/null | grep -q kafka"

# ── Kind cluster ───────────────────────────────────────────────────────────────
echo "── Kind cluster ─────────────────────────────────────────────────────────"
check "cluster reachable" "kubectl cluster-info --context kind-task-manager"

# ── Pods (namespace: task-manager) ────────────────────────────────────────────
echo "── Pods (namespace: task-manager) ───────────────────────────────────────"
check "api pod Running"    "kubectl get pods -n task-manager -l app=api    -o jsonpath='{.items[*].status.phase}' | grep -q Running"
check "fetch pod Running"  "kubectl get pods -n task-manager -l app=fetch  -o jsonpath='{.items[*].status.phase}' | grep -q Running"
check "ingest pod Running" "kubectl get pods -n task-manager -l app=ingest -o jsonpath='{.items[*].status.phase}' | grep -q Running"

# ── ArgoCD ─────────────────────────────────────────────────────────────────────
echo "── ArgoCD ───────────────────────────────────────────────────────────────"
check "application Synced"  "kubectl get application task-manager -n argocd -o jsonpath='{.status.sync.status}'   2>/dev/null | grep -q Synced"
check "application Healthy" "kubectl get application task-manager -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null | grep -q Healthy"

# ── API endpoint ───────────────────────────────────────────────────────────────
echo "── API endpoint ─────────────────────────────────────────────────────────"
check "GET /health → 200"  "curl -sf http://localhost:8080/health"

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
TOTAL=$((PASS + FAIL))
if [ "$FAIL" -eq 0 ]; then
    printf "All %d checks passed. Application is running.\n" "$TOTAL"
    exit 0
else
    printf "%d of %d checks failed.\n" "$FAIL" "$TOTAL"
    printf "Tips:\n"
    printf "  Infrastructure not running? -> docker compose up postgres kafka\n"
    printf "  Cluster not running?        -> ansible-playbook ops/ansible/kind-up.yml\n"
    printf "  Pods not ready yet?         -> kubectl get pods -n task-manager -w\n"
    printf "  ArgoCD not synced?          -> kubectl get application task-manager -n argocd\n"
    exit 1
fi
