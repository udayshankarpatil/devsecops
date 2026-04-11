#!/usr/bin/env bash
# setup.sh — host machine setup for task-manager development.
#
# Installs Ansible if missing, then runs:
#   ops/ansible/dev-setup.yml  — CLI tools + Galaxy collections + pre-commit hook
#
# Run once per machine and once per fresh clone.
#
# Prerequisites: macOS with Homebrew (https://brew.sh)
#
# Usage (run from repo root):
#   bash ops/setup.sh

set -euo pipefail

if [ -f /.dockerenv ]; then
    echo "Error: setup.sh must be run from the host machine, not the dev container." >&2
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

# ── Step 2: Run dev-setup playbook ────────────────────────────────────────────

echo ""
echo "==> Running dev-setup playbook..."
ansible-playbook ops/ansible/dev-setup.yml

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "Setup complete. Pre-commit hook is active — Gitleaks will scan every commit."
echo ""
echo "To use GitOps validation (Mode 2), run: bash ops/bootstrap.sh"
