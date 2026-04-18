#!/usr/bin/env bash
# Health-check all runners across hosts. Reports queued vs idle vs busy.
#
# Usage:
#   runner-status.sh [--repo OWNER/REPO]
#
# Defaults: --repo auto-detected from current git repo via gh.

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=runner-lib.sh
source "$DIR/runner-lib.sh"

REPO=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done
[[ -z "$REPO" ]] && REPO="$(detect_repo)"

JSON=$(gh api "repos/$REPO/actions/runners" --jq '.runners')
TOTAL=$(echo "$JSON" | jq 'length')
ONLINE=$(echo "$JSON" | jq '[.[] | select(.status=="online")] | length')
OFFLINE=$(echo "$JSON" | jq '[.[] | select(.status!="online")] | length')
BUSY=$(echo "$JSON" | jq '[.[] | select(.busy==true)] | length')
IDLE=$((ONLINE - BUSY))

QUEUED=$(gh api "repos/$REPO/actions/runs" --jq '[.workflow_runs[] | select(.status=="queued")] | length')
INPROG=$(gh api "repos/$REPO/actions/runs" --jq '[.workflow_runs[] | select(.status=="in_progress")] | length')

echo "Pool for $REPO"
echo "  runners: $TOTAL total · $ONLINE online · $OFFLINE offline"
echo "           $BUSY busy · $IDLE idle"
echo "  jobs:    $QUEUED queued · $INPROG in-progress"

if [[ "$QUEUED" -gt 0 ]] && [[ "$IDLE" -eq 0 ]]; then
  echo
  echo "  ⚠ queue depth $QUEUED with no idle runners. Consider:"
  echo "    runner-add.sh --count $QUEUED  (locally) or --host LLM --count $QUEUED"
fi

echo
echo "Runners:"
echo "$JSON" | jq -r '
  .[] |
  "  \(.name) [\(.status)] " +
  (if .busy then "busy" else "idle" end) +
  " labels=" + ([.labels[].name] | join(","))
'
