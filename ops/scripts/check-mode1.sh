#!/usr/bin/env bash
# check-mode1.sh — verify the Mode 1 (Docker Compose) stack is running.
#
# Checks postgres, kafka, and all three application services via Docker Compose,
# then hits the API /health endpoint on port 8000.
# Exit code 0 = all checks passed; 1 = one or more failed.
#
# Usage:
#   bash ops/scripts/check-mode1.sh

set -uo pipefail

if [ -f /.dockerenv ]; then
    echo "Error: check-mode1.sh must be run from the host machine, not the dev container." >&2
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

# ── Application services (Docker Compose) ─────────────────────────────────────
echo "── Application services (Docker Compose) ────────────────────────────────"
check "api running"    "docker compose ps --status running 2>/dev/null | grep -q api"
check "fetch running"  "docker compose ps --status running 2>/dev/null | grep -q fetch"
check "ingest running" "docker compose ps --status running 2>/dev/null | grep -q ingest"

# ── API endpoint ───────────────────────────────────────────────────────────────
echo "── API endpoint ─────────────────────────────────────────────────────────"
check "GET /health → 200" "curl -sf http://localhost:8000/health"

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
TOTAL=$((PASS + FAIL))
if [ "$FAIL" -eq 0 ]; then
    printf "All %d checks passed. Mode 1 is running.\n" "$TOTAL"
    exit 0
else
    printf "%d of %d checks failed.\n" "$FAIL" "$TOTAL"
    printf "Tips:\n"
    printf "  Stack not running?            -> docker compose up\n"
    printf "  Infrastructure only?          -> docker compose up postgres kafka\n"
    printf "  Service not ready yet?        -> docker compose logs -f api\n"
    exit 1
fi
