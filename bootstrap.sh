#!/usr/bin/env bash
# bootstrap.sh — one-command developer environment setup.
#
# Installs Ansible if missing, then runs:
#   1. ansible/dev-setup.yml  — CLI tools + Galaxy collections (one-time)
#   2. ansible/kind-up.yml    — Kind cluster + ArgoCD (idempotent)
#
# Usage:
#   bash bootstrap.sh                                    # prompts for GitHub username
#   bash bootstrap.sh -e image_owner=<github-username>  # non-interactive
#
# Prerequisites: macOS with Homebrew (https://brew.sh) and Docker Desktop running.

set -euo pipefail

# Resolve repo root so the script works when called from any directory.
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_ROOT"

# ── Step 1: Ensure Ansible is present ─────────────────────────────────────────

if ! command -v ansible-playbook &>/dev/null; then
    echo "==> Ansible not found — installing via Homebrew..."
    brew install ansible
fi

echo "==> Ansible: $(ansible --version | head -1)"

# ── Step 2: Install dev tools + Galaxy collections ────────────────────────────

echo ""
echo "==> Running dev-setup playbook..."
ansible-playbook ansible/dev-setup.yml

# ── Step 3: Bootstrap the Kind cluster ────────────────────────────────────────

# If the caller didn't supply image_owner on the command line, prompt for it.
if [[ "$*" != *"image_owner"* ]]; then
    echo ""
    read -rp "GitHub username (used for GHCR image pulls): " IMAGE_OWNER
    OWNER_ARG="-e image_owner=${IMAGE_OWNER}"
else
    OWNER_ARG=""
fi

echo ""
echo "==> Bootstrapping Kind cluster..."
# shellcheck disable=SC2086  # OWNER_ARG is intentionally unquoted (may be empty)
ansible-playbook ansible/kind-up.yml $OWNER_ARG "$@"

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "Setup complete."
echo "  API:       http://localhost:8080"
echo "  ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8443:443"
echo ""
echo "Verify with: bash scripts/check-setup.sh"
