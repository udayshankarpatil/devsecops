#!/usr/bin/env bash
# scan-dev.sh — run Python security scans (SAST and SCA).
#
# Covers: Bandit (SAST), pip-audit (SCA) for all three services.
# For host-side scans (Hadolint, Gitleaks, Trivy), run scan-host.sh from the host.
#
# Exit code 0 = all scans passed; 1 = one or more failed.
#
# Usage (from inside the dev container):
#   bash ops/scripts/scan-dev.sh

set -uo pipefail

if [ ! -f /.dockerenv ]; then
    echo "Error: scan-dev.sh must be run from the dev container (VS Code terminal)." >&2
    exit 1
fi

cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

PASS=0
FAIL=0

run_scan() {
    local label="$1"
    shift
    if "$@"; then
        printf "  ✓  %s\n" "$label"
        PASS=$((PASS + 1))
    else
        printf "  ✗  %s\n" "$label"
        FAIL=$((FAIL + 1))
    fi
}

# ── Bandit — SAST ─────────────────────────────────────────────────────────────
echo "── Bandit (SAST) ────────────────────────────────────────────────────────"
for svc in api fetch ingest; do
    run_scan "bandit · $svc" bash -c "cd services/$svc && bandit -r src/ -ll -q"
done

# ── pip-audit — SCA ───────────────────────────────────────────────────────────
echo ""
echo "── pip-audit (SCA) ──────────────────────────────────────────────────────"
for svc in api fetch ingest; do
    run_scan "pip-audit · $svc" pip-audit -r <(python ops/scripts/pyproject_deps.py "services/$svc/pyproject.toml")
done

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
TOTAL=$((PASS + FAIL))
if [ "$FAIL" -eq 0 ]; then
    printf "All %d scans passed.\n" "$TOTAL"
    exit 0
else
    printf "%d of %d scans failed.\n" "$FAIL" "$TOTAL"
    exit 1
fi
