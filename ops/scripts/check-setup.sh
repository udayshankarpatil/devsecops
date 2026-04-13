#!/usr/bin/env bash
# check-setup.sh — verify the one-time developer environment setup is complete.
#
# Checks tools, Docker runtime, Ansible Galaxy collections, and the Kind cluster.
# Exit code 0 = all checks passed; 1 = one or more failed.
#
# Usage:
#   bash ops/scripts/check-setup.sh

set -uo pipefail

if [ -f /.dockerenv ]; then
    echo "Error: check-setup.sh must be run from the host machine, not the dev container." >&2
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

# ── Tools ──────────────────────────────────────────────────────────────────────
echo "── Tools ────────────────────────────────────────────────────────────────"
check "docker"          "command -v docker"
check "ansible"         "command -v ansible-playbook"
check "kind"            "command -v kind"
check "kubectl"         "command -v kubectl"
check "helm"            "command -v helm"
check "yq"              "command -v yq"

# ── Docker runtime ─────────────────────────────────────────────────────────────
echo "── Docker runtime ───────────────────────────────────────────────────────"
check "Docker daemon running" "docker info"

# ── Ansible Galaxy collections ─────────────────────────────────────────────────
echo "── Ansible Galaxy collections ───────────────────────────────────────────"
check "kubernetes.core"   "ansible-galaxy collection list | grep -q 'kubernetes\.core'"
check "community.general" "ansible-galaxy collection list | grep -q 'community\.general'"
check "community.docker"  "ansible-galaxy collection list | grep -q 'community\.docker'"

# ── Kind cluster ───────────────────────────────────────────────────────────────
echo "── Kind cluster ─────────────────────────────────────────────────────────"
check "cluster 'task-manager' exists"      "kind get clusters 2>/dev/null | grep -q '^task-manager$'"
check "kubectl context 'kind-task-manager'" "kubectl config get-contexts kind-task-manager"
check "cluster reachable"                  "kubectl cluster-info --context kind-task-manager"

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
TOTAL=$((PASS + FAIL))
if [ "$FAIL" -eq 0 ]; then
    printf "All %d checks passed. Dev setup is complete.\n" "$TOTAL"
    exit 0
else
    printf "%d of %d checks failed.\n" "$FAIL" "$TOTAL"
    printf "Run 'bash ops/bootstrap.sh' to complete setup.\n"
    exit 1
fi
