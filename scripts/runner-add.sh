#!/usr/bin/env bash
# Install N self-hosted GitHub Actions runners on a target host for a given repo.
# Works for any repo, any host, any count. Local or remote.
#
# Usage:
#   runner-add.sh [--repo OWNER/REPO] [--host HOST] [--count N]
#                 [--root /path] [--label foo,bar] [--name-prefix scrithub]
#
# Defaults:
#   --repo  : auto-detected from current git repo via gh
#   --host  : "local" (this workstation). Pass any ssh alias / user@ip for remote
#   --count : 1
#   --root  : ~/actions-runners (per host)
#   --label : self-hosted,linux,x64 (host name auto-appended)
#   --name-prefix : derived from repo name, e.g. scrithub → scrithub
#
# Requires:
#   - gh CLI authenticated with `actions:write` scope on the repo
#   - ssh key auth to remote hosts (no-op for local)
#   - linger enabled if installing for a non-login user (loginctl enable-linger USER)

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=runner-lib.sh
source "$DIR/runner-lib.sh"

REPO=""
HOST="local"
COUNT=1
ROOT=""
LABELS=""
NAME_PREFIX=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --count) COUNT="$2"; shift 2 ;;
    --root) ROOT="$2"; shift 2 ;;
    --label|--labels) LABELS="$2"; shift 2 ;;
    --name-prefix) NAME_PREFIX="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$REPO" ]] && REPO="$(detect_repo)"
[[ -z "$ROOT" ]] && ROOT="$DEFAULT_ROOT"
[[ -z "$NAME_PREFIX" ]] && NAME_PREFIX="$(echo "$REPO" | awk -F/ '{print $2}')"

# Hostname label: short name of target. For local, use $(hostname).
if [[ "$HOST" == "local" || "$HOST" == "localhost" ]]; then
  HOST_LABEL=$(hostname -s)
  HOST_TARGET="local"
else
  HOST_LABEL=$(host_run "$HOST" "hostname -s" 2>/dev/null || echo "$HOST" | sed 's/[^a-zA-Z0-9-]/-/g')
  HOST_TARGET="$HOST"
fi

[[ -z "$LABELS" ]] && LABELS="$DEFAULT_LABELS,$HOST_LABEL"

VERSION=$(gh_runner_latest_version)
TARBALL_URL="https://github.com/actions/runner/releases/download/v${VERSION}/actions-runner-linux-x64-${VERSION}.tar.gz"

echo "▸ Installing $COUNT runner(s) on $HOST_TARGET ($HOST_LABEL) for $REPO"
echo "  root=$ROOT  labels=$LABELS  version=$VERSION"

# Ensure root + tarball exist on target.
host_run "$HOST_TARGET" "mkdir -p '$ROOT'"

# Download tarball once on target if missing.
host_run "$HOST_TARGET" "
  if [[ ! -f '$ROOT/actions-runner-${VERSION}.tar.gz' ]]; then
    curl -fL -o '$ROOT/actions-runner-${VERSION}.tar.gz' '$TARBALL_URL'
  fi
"

# Find next available index for this repo on this host.
EXISTING=$(host_run "$HOST_TARGET" "ls -d '$ROOT/${NAME_PREFIX}'-* 2>/dev/null | wc -l" || echo 0)
START_IDX=$((EXISTING + 1))

for ((i=0; i<COUNT; i++)); do
  IDX=$((START_IDX + i))
  NAME="${NAME_PREFIX}-${HOST_LABEL}-${IDX}"
  RUNNER_DIR="$ROOT/${NAME_PREFIX}-${IDX}"
  TOKEN=$(gh_runner_token "$REPO")

  echo "  └─ provisioning $NAME at $RUNNER_DIR"

  host_run "$HOST_TARGET" "
    mkdir -p '$RUNNER_DIR' &&
    cd '$RUNNER_DIR' &&
    tar xzf '$ROOT/actions-runner-${VERSION}.tar.gz' &&
    ./config.sh \
      --url 'https://github.com/$REPO' \
      --token '$TOKEN' \
      --name '$NAME' \
      --labels '$LABELS' \
      --work _work \
      --unattended \
      --replace > /dev/null
  "

  # systemd user service
  UNIT="actions-runner-${NAME}.service"
  UNIT_PATH="\$HOME/.config/systemd/user/$UNIT"

  host_run "$HOST_TARGET" "
    mkdir -p \$HOME/.config/systemd/user
    mkdir -p \$HOME/.gradle-runner-${IDX}
    cat > $UNIT_PATH <<EOF
[Unit]
Description=GitHub Actions runner $NAME
After=network-online.target

[Service]
ExecStart=$RUNNER_DIR/run.sh
WorkingDirectory=$RUNNER_DIR
Restart=always
RestartSec=5
MemoryHigh=2G
MemoryMax=4G
CPUQuota=200%
# Per-runner Gradle home — prevents lock collision when two builds run in parallel.
Environment=GRADLE_USER_HOME=\$HOME/.gradle-runner-${IDX}
# Shared tool cache so setup-python finds the pre-installed Python.
# (Operator: pre-populate \$HOME/runner-tool-cache/Python/<ver>/x64 once before launching the pool.)
Environment=RUNNER_TOOL_CACHE=\$HOME/runner-tool-cache
Environment=AGENT_TOOLSDIRECTORY=\$HOME/runner-tool-cache

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload
    systemctl --user enable --now $UNIT
  "

  echo "    ✓ $NAME running"
done

echo "✓ Done. $COUNT runner(s) added to $HOST_LABEL for $REPO."
echo "  Verify with: runner-list.sh --repo $REPO"
