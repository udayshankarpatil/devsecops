#!/usr/bin/env bash
# dev.sh — developer task runner for task-manager.
#
# Usage:
#   bash dev.sh <command> [args]
#   bash dev.sh -h                  general help
#   bash dev.sh -h <command>        command-specific help
#   bash dev.sh <command> -h        command-specific help

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_ROOT"

# ── Helpers ───────────────────────────────────────────────────────────────────

# Returns true if any Mode 1 service (api, fetch, ingest, devcontainer) is running.
mode1_active() {
    docker compose ps --status running --services 2>/dev/null \
        | grep -vE "^(postgres|kafka)$" \
        | grep -q .
}

# ── Context guards ────────────────────────────────────────────────────────────

require_host() {
    if [ -f /.dockerenv ]; then
        echo "Error: '$COMMAND' must be run from the host machine, not the dev container." >&2
        exit 1
    fi
}

require_dev() {
    if [ ! -f /.dockerenv ]; then
        echo "Error: '$COMMAND' must be run from the dev container (VS Code terminal)." >&2
        exit 1
    fi
}

# ── Help ──────────────────────────────────────────────────────────────────────

usage_general() {
    cat <<'EOF'
Usage: bash dev.sh <command> [args]

Commands:
  setup       Install host tools and activate pre-commit hook           [host]
  test        Run pytest for all services                                [dev]
  scan        Run security scans (auto-detects host vs dev)
  build       Build Docker images                                       [host]
  up          Start Mode 1 — Docker Compose                             [host]
  up-kind     Start Mode 2 — Kind cluster                               [host]
  down        Stop Mode 1 — Docker Compose                              [host]
  down-kind   Stop Mode 2 — Kind cluster                                [host]
  check       Verify Mode 1 is running                                  [host]
  check-kind  Verify Mode 2 is running                                  [host]
  argo        Open the ArgoCD UI (prints credentials, port-forwards)    [host]
  help        Show the developer quick reference

Run 'bash dev.sh -h <command>' for command-specific help.
EOF
}

usage_cmd() {
    case "$1" in
        setup)  cat <<'EOF'
setup  [host]
  Installs host tools (Kind, kubectl, Helm, yq, pre-commit, Hadolint, Gitleaks,
  Trivy) and activates the Gitleaks pre-commit hook. Run once per machine and
  once per fresh clone.

  bash dev.sh setup
EOF
            ;;
        test)   cat <<'EOF'
test  [dev]
  Runs pytest for all three services. Optionally pass a path for a single service.

  bash dev.sh test
  bash dev.sh test services/api
EOF
            ;;
        scan)   cat <<'EOF'
scan
  Runs security scans. Automatically selects the right script based on context:
    [host]  Hadolint, Gitleaks, Trivy config, Trivy image
    [dev]   Bandit, pip-audit

  bash dev.sh scan
EOF
            ;;
        build)  cat <<'EOF'
build  [host]
  Builds Docker images via docker compose. Optionally pass service names.

  bash dev.sh build              # all services
  bash dev.sh build api          # single service
  bash dev.sh build api fetch    # multiple services
EOF
            ;;
        up)     cat <<'EOF'
up  [host]
  Starts Mode 1 — all services via Docker Compose. Runs in the foreground
  by default; logs stream to the terminal and Ctrl+C stops all containers.

  bash dev.sh up                       # foreground — all services + infra
  bash dev.sh up -d                    # detached — terminal returns immediately
  bash dev.sh up postgres kafka        # infra only
EOF
            ;;
        'up-kind')  cat <<'EOF'
up-kind  [host]
  Starts Mode 2 — provisions the Kind cluster and deploys the application
  via ArgoCD. Starts postgres and kafka first if they are not already
  running. Idempotent — safe to re-run.

  bash dev.sh up-kind                           # prompts for GitHub username
  bash dev.sh up-kind -e image_owner=<user>     # non-interactive
EOF
            ;;
        down)   cat <<'EOF'
down  [host]
  Stops Mode 1 — all Docker Compose services.
  Note: if Mode 2 is running, this will cut the Kind pods off from postgres
  and kafka. Mode 2 has no protection against Mode 1 shutdown.

  bash dev.sh down                     # stop all containers
  bash dev.sh down -v                  # stop and wipe database (destructive)
EOF
            ;;
        'down-kind')  cat <<'EOF'
down-kind  [host]
  Stops Mode 2 — tears down the Kind cluster. Postgres and kafka are stopped
  only if Mode 1 is not running; otherwise they are left up.

  bash dev.sh down-kind
EOF
            ;;
        check)  cat <<'EOF'
check  [host]
  Verifies Mode 1 — Docker Compose infra (postgres, kafka), all three application
  services, and the API /health endpoint at port 8000.

  bash dev.sh check
EOF
            ;;
        'check-kind')  cat <<'EOF'
check-kind  [host]
  Verifies Mode 2 — Docker Compose infra (postgres, kafka), Kind cluster
  reachability, pod status, ArgoCD sync/health, and the API /health endpoint
  at port 8080.

  bash dev.sh check-kind
EOF
            ;;
        argo)   cat <<'EOF'
argo  [host]
  Prints the ArgoCD admin credentials, opens https://localhost:8443 in the
  default browser, then starts the kubectl port-forward (Ctrl+C to stop).

  bash dev.sh argo
EOF
            ;;
        help)   cat <<'EOF'
help
  Displays the developer quick reference.

  bash dev.sh help
EOF
            ;;
        *)
            echo "Unknown command: $1" >&2
            echo "Run 'bash dev.sh -h' for a list of commands." >&2
            return 1
            ;;
    esac
}

# ── Argument parsing ──────────────────────────────────────────────────────────

if [ $# -eq 0 ]; then
    usage_general
    exit 0
fi

# -h / --help as first arg
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    if [ $# -ge 2 ]; then
        usage_cmd "$2"
    else
        usage_general
    fi
    exit 0
fi

COMMAND="$1"
shift

# -h / --help after command
if [ $# -ge 1 ] && { [ "$1" = "-h" ] || [ "$1" = "--help" ]; }; then
    usage_cmd "$COMMAND"
    exit 0
fi

# ── Dispatch ──────────────────────────────────────────────────────────────────

case "$COMMAND" in
    setup)
        require_host
        bash ops/setup.sh
        ;;
    test)
        require_dev
        pytest "$@"
        ;;
    scan)
        if [ -f /.dockerenv ]; then
            bash ops/scripts/scan-dev.sh
            echo ""
            echo "Note: SAST and SCA only. Run 'bash dev.sh scan' from the host for Hadolint, Gitleaks, and Trivy."
        else
            bash ops/scripts/scan-host.sh
            echo ""
            echo "Note: Hadolint, Gitleaks, and Trivy only. Run 'bash dev.sh scan' from the dev container for SAST and SCA."
        fi
        ;;
    build)
        require_host
        docker compose build "$@"
        ;;
    up)
        require_host
        docker compose up "$@"
        ;;
    up-kind)
        require_host
        bash ops/bootstrap.sh "$@"
        ;;
    down)
        require_host
        docker compose down "$@"
        ;;
    down-kind)
        require_host
        ansible-playbook ops/ansible/kind-down.yml
        if mode1_active; then
            echo "Mode 1 is running — leaving postgres and kafka up."
        else
            echo "Mode 1 is not running — stopping shared infrastructure."
            docker compose stop postgres kafka
        fi
        ;;
    check)
        require_host
        bash ops/scripts/check-mode1.sh
        ;;
    check-kind)
        require_host
        bash ops/scripts/check-running.sh
        ;;
    argo)
        require_host
        ARGO_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
            -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)
        if [ -z "$ARGO_PASSWORD" ]; then
            echo "Error: could not retrieve ArgoCD admin password. Is the Kind cluster running?" >&2
            exit 1
        fi
        echo ""
        echo "ArgoCD credentials"
        echo "  Username : admin"
        echo "  Password : $ARGO_PASSWORD"
        echo ""
        echo "Opening https://localhost:8443 in your browser ..."
        if command -v open &>/dev/null; then
            open "https://localhost:8443"
        elif command -v xdg-open &>/dev/null; then
            xdg-open "https://localhost:8443"
        fi
        pkill -f "port-forward svc/argocd-server" 2>/dev/null && echo "Stopped existing port-forward." || true
        echo "Starting port-forward — press Ctrl+C to stop."
        echo ""
        kubectl port-forward svc/argocd-server -n argocd 8443:443
        ;;
    help)
        bash ops/help.sh
        ;;
    *)
        echo "Unknown command: $COMMAND" >&2
        echo "Run 'bash dev.sh -h' for a list of commands." >&2
        exit 1
        ;;
esac
