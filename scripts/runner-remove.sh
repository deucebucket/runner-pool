#!/usr/bin/env bash
# Deregister + uninstall a runner by name.
#
# Usage:
#   runner-remove.sh --name RUNNER_NAME [--repo OWNER/REPO] [--host HOST]
#
# - Stops the systemd unit on the target host
# - Uses the runner's own ./config.sh remove with a fresh remove-token
# - Deletes the install dir
#
# Defaults:
#   --repo : auto-detected from current git repo
#   --host : "local"

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=runner-lib.sh
source "$DIR/runner-lib.sh"

REPO=""
HOST="local"
NAME=""
ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --root) ROOT="$2"; shift 2 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

[[ -z "$NAME" ]] && { echo "ERROR: --name required" >&2; exit 2; }
[[ -z "$REPO" ]] && REPO="$(detect_repo)"
[[ -z "$ROOT" ]] && ROOT="$DEFAULT_ROOT"

# Locate the runner dir by checking each candidate.
RUNNER_DIR=$(host_run "$HOST" "ls -d $ROOT/*/ 2>/dev/null | while read d; do [[ -f \"\${d}.runner\" ]] && grep -q '\"agentName\": \"$NAME\"' \"\${d}.runner\" && echo \"\${d%/}\"; done | head -1")

if [[ -z "$RUNNER_DIR" ]]; then
  echo "ERROR: no runner named $NAME found in $ROOT on $HOST" >&2
  exit 1
fi

echo "▸ Removing $NAME from $HOST ($RUNNER_DIR)"

UNIT="actions-runner-${NAME}.service"
TOKEN=$(gh_runner_remove_token "$REPO")

host_run "$HOST" "
  systemctl --user disable --now $UNIT 2>/dev/null || true
  rm -f \$HOME/.config/systemd/user/$UNIT
  systemctl --user daemon-reload
  cd '$RUNNER_DIR' && ./config.sh remove --token '$TOKEN' || true
  cd / && rm -rf '$RUNNER_DIR'
"

echo "✓ Removed $NAME from $HOST"
