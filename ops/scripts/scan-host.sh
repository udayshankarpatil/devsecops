#!/usr/bin/env bash
# scan-host.sh — run host-side security scans (mirrors CI security gates).
#
# Covers: Hadolint, Gitleaks, Trivy config, Trivy image.
# For SAST (Bandit) and SCA (pip-audit), run scan-dev.sh from the dev container.
#
# Exit code 0 = all scans passed; 1 = one or more failed.
#
# Usage:
#   bash ops/scripts/scan-host.sh

set -uo pipefail

if [ -f /.dockerenv ]; then
    echo "Error: scan-host.sh must be run from the host machine, not the dev container." >&2
    exit 1
fi

cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

PASS=0
FAIL=0
SKIP=0

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

# ── Hadolint — Dockerfile linting ─────────────────────────────────────────────
echo "── Hadolint (Dockerfile linting) ────────────────────────────────────────"
for svc in api fetch ingest; do
    run_scan "hadolint · $svc" hadolint --config ops/config/hadolint.yaml "services/$svc/Dockerfile"
done

# ── Gitleaks — secret scanning ────────────────────────────────────────────────
echo ""
echo "── Gitleaks (secret scanning) ───────────────────────────────────────────"
run_scan "gitleaks" gitleaks detect --source . -v

# ── Trivy — IaC / misconfig scanning ─────────────────────────────────────────
echo ""
echo "── Trivy (IaC / misconfig) ──────────────────────────────────────────────"
run_scan "trivy config · ops/"               trivy config --ignorefile ops/config/.trivyignore ops/
run_scan "trivy config · docker-compose.yml" trivy config --ignorefile ops/config/.trivyignore docker-compose.yml

# ── Trivy — image scanning ────────────────────────────────────────────────────
echo ""
echo "── Trivy (image scanning) ───────────────────────────────────────────────"
for svc in api fetch ingest; do
    image="devsecops-${svc}:latest"
    if ! docker image inspect "$image" >/dev/null 2>&1; then
        printf "  ⚠   trivy image · %s — image not found, run 'docker compose build %s' first\n" "$svc" "$svc"
        SKIP=$((SKIP + 1))
    else
        run_scan "trivy image · $svc" \
            trivy image --ignore-unfixed --severity CRITICAL,HIGH \
                --ignorefile ops/config/.trivyignore "$image"
    fi
done

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
TOTAL=$((PASS + FAIL))
[ "$SKIP" -gt 0 ] && printf "%d image scan(s) skipped — image not built.\n" "$SKIP"
if [ "$FAIL" -eq 0 ]; then
    printf "All %d scans passed.\n" "$TOTAL"
    exit 0
else
    printf "%d of %d scans failed.\n" "$FAIL" "$TOTAL"
    exit 1
fi
