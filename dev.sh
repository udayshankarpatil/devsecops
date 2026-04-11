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
  setup    Install host tools and activate pre-commit hook       [host]
  test     Run pytest for all services                           [dev]
  scan     Run security scans (auto-detects host vs dev context)
  build    Build Docker images                                   [host]
  up       Start the stack                                       [host]
  down     Stop the stack                                        [host]
  run      Provision the Kind cluster (Mode 2)                   [host]
  check    Verify the application is running                     [host]
  stop     Tear down the Kind cluster (Mode 2)                   [host]
  help     Show the developer quick reference

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
  Starts the stack via docker compose.

  bash dev.sh up                       # all services + infra
  bash dev.sh up postgres kafka        # infra only
EOF
            ;;
        down)   cat <<'EOF'
down  [host]
  Stops the stack via docker compose.

  bash dev.sh down      # stop
  bash dev.sh down -v   # stop and wipe database (destructive)
EOF
            ;;
        run)    cat <<'EOF'
run  [host]
  Provisions the local Kind cluster and deploys ArgoCD (Mode 2). Idempotent —
  safe to re-run after 'stop'. Requires 'setup' to have been run first.

  bash dev.sh run                              # prompts for GitHub username
  bash dev.sh run -e image_owner=<username>    # non-interactive
EOF
            ;;
        check)  cat <<'EOF'
check  [host]
  Verifies Docker Compose infra, Kind cluster, pods, ArgoCD sync, and API health.

  bash dev.sh check
EOF
            ;;
        stop)   cat <<'EOF'
stop  [host]
  Tears down the local Kind cluster (Mode 2). Docker Compose services are left running.

  bash dev.sh stop
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
    down)
        require_host
        docker compose down "$@"
        ;;
    run)
        require_host
        bash ops/bootstrap.sh "$@"
        ;;
    check)
        require_host
        bash ops/scripts/check-running.sh
        ;;
    stop)
        require_host
        ansible-playbook ops/ansible/kind-down.yml
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
