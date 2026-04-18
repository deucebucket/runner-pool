#!/usr/bin/env bash
# List all self-hosted runners registered for a repo.
#
# Usage:
#   runner-list.sh [--repo OWNER/REPO]
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

echo "Runners registered for $REPO:"
gh api "repos/$REPO/actions/runners" --jq '
  .runners[] |
  "  • \(.name) [\(.status)] busy=\(.busy) labels=" + ([.labels[].name] | join(","))
'
