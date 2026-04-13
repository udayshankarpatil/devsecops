#!/usr/bin/env bash
# bootstrap.sh — provision the local Kind cluster for GitOps validation (Mode 2).
#
# Installs Ansible if missing, then runs:
#   ops/ansible/kind-up.yml  — Kind cluster + ArgoCD (idempotent — re-run to recreate)
#
# Prerequisites:
#   - macOS with Homebrew (https://brew.sh) and Docker Desktop running
#   - Host tools installed: bash ops/setup.sh
#
# Usage (run from repo root):
#   bash ops/bootstrap.sh                                    # prompts for GitHub username
#   bash ops/bootstrap.sh -e image_owner=<github-username>  # non-interactive

set -euo pipefail

if [ -f /.dockerenv ]; then
    echo "Error: bootstrap.sh must be run from the host machine, not the dev container." >&2
    exit 1
fi

# Resolve repo root so the script works when called from any directory.
# The script lives in ops/, so go one level up to reach the repo root.
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# ── Step 1: Ensure Ansible is present ─────────────────────────────────────────

if ! command -v ansible-playbook &>/dev/null; then
    echo "==> Ansible not found — installing via Homebrew..."
    brew install ansible
fi

echo "==> Ansible: $(ansible --version | head -1)"

# ── Step 2: Bootstrap the Kind cluster ────────────────────────────────────────

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
ansible-playbook ops/ansible/kind-up.yml $OWNER_ARG "$@"

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "Setup complete."
echo "  API:       http://localhost:8080"
echo "  ArgoCD UI: bash dev.sh argo"
echo ""
echo "Verify with: bash ops/scripts/check-setup.sh"
