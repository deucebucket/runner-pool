#!/usr/bin/env bash
# Continuous autoscaler for a runner pool on a single host.
#
# Polls GitHub queue depth + pool capacity. Scales runners up when
# jobs are queued AND no idle runners exist; scales down when ALL
# runners have been idle for the cooldown window.
#
# Usage:
#   runner-autoscale.sh [--repo OWNER/REPO] [--min N] [--max N]
#                       [--cooldown SEC] [--interval SEC] [--host HOST]
#
# Defaults:
#   --repo     auto-detected from current git repo
#   --min      1
#   --max      8
#   --cooldown 600 (10 min idle before removing a runner)
#   --interval 30  (poll every 30s)
#   --host     local
#
# Requires: gh CLI authenticated, runner-add/remove scripts in the same dir.

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=runner-lib.sh
source "$DIR/runner-lib.sh"

REPO=""
MIN=1
MAX=8
COOLDOWN=600
INTERVAL=30
HOST="local"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --min) MIN="$2"; shift 2 ;;
    --max) MAX="$2"; shift 2 ;;
    --cooldown) COOLDOWN="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done
[[ -z "$REPO" ]] && REPO="$(detect_repo)"

# Track when the pool last had any busy runner. If it's been idle past
# COOLDOWN, scale down by one.
last_busy_ts=$(date +%s)

echo "▸ autoscaler started for $REPO on $HOST  (min=$MIN max=$MAX cooldown=${COOLDOWN}s interval=${INTERVAL}s)"

while :; do
  RUNNERS_JSON=$(gh api "repos/$REPO/actions/runners" --jq '.runners' 2>/dev/null || echo '[]')
  ONLINE=$(echo "$RUNNERS_JSON" | jq '[.[] | select(.status=="online")] | length')
  BUSY=$(echo "$RUNNERS_JSON" | jq '[.[] | select(.busy==true)] | length')
  IDLE=$((ONLINE - BUSY))

  QUEUED=$(gh api "repos/$REPO/actions/runs" --jq '[.workflow_runs[] | select(.status=="queued")] | length' 2>/dev/null || echo 0)

  now=$(date +%s)
  [[ "$BUSY" -gt 0 ]] && last_busy_ts=$now
  idle_for=$((now - last_busy_ts))

  printf '[%(%H:%M:%S)T] online=%d busy=%d idle=%d queued=%d idle_for=%ds\n' -1 "$ONLINE" "$BUSY" "$IDLE" "$QUEUED" "$idle_for"

  # Scale UP: queued jobs exist AND no idle runners AND under MAX
  if [[ "$QUEUED" -gt 0 ]] && [[ "$IDLE" -eq 0 ]] && [[ "$ONLINE" -lt "$MAX" ]]; then
    headroom=$((MAX - ONLINE))
    add=$(( QUEUED < headroom ? QUEUED : headroom ))
    echo "  ↑ scale up: adding $add runner(s)"
    bash "$DIR/runner-add.sh" --repo "$REPO" --host "$HOST" --count "$add" || true
    last_busy_ts=$now  # treat new runners picking up jobs as activity
  fi

  # Scale DOWN: pool fully idle for COOLDOWN seconds AND above MIN
  if [[ "$IDLE" -eq "$ONLINE" ]] && [[ "$ONLINE" -gt "$MIN" ]] && [[ "$idle_for" -ge "$COOLDOWN" ]]; then
    # Remove the highest-numbered runner (most recently added)
    name=$(echo "$RUNNERS_JSON" | jq -r '[.[] | select(.busy==false) | .name] | sort | last')
    if [[ -n "$name" && "$name" != "null" ]]; then
      echo "  ↓ scale down: removing $name (idle ${idle_for}s)"
      bash "$DIR/runner-remove.sh" --repo "$REPO" --host "$HOST" --name "$name" || true
      last_busy_ts=$now  # reset window after a removal
    fi
  fi

  sleep "$INTERVAL"
done
