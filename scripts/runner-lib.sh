#!/usr/bin/env bash
# Shared library for runner-pool plugin scripts.
# Sourced by add/list/remove/status. Don't run directly.

set -euo pipefail

# Default install root on the target host (override with --root).
DEFAULT_ROOT="${RUNNER_POOL_ROOT:-$HOME/actions-runners}"

# Default labels appended to every runner; the host name is added automatically
# below (so workflows can target a specific host if they want).
DEFAULT_LABELS="self-hosted,linux,x64"

# Detect repo from the current git checkout if --repo is omitted.
detect_repo() {
  if command -v gh >/dev/null && gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null; then
    return 0
  fi
  echo "ERROR: not in a git repo with a gh-recognized remote. Pass --repo OWNER/REPO." >&2
  exit 2
}

# Run a command either locally or via ssh, depending on $HOST.
host_run() {
  local host="$1"; shift
  if [[ "$host" == "local" || "$host" == "localhost" || "$host" == "$(hostname)" ]]; then
    bash -c "$*"
  else
    ssh "$host" "$*"
  fi
}

# Push a file to a host (local cp or scp).
host_put() {
  local host="$1" src="$2" dst="$3"
  if [[ "$host" == "local" || "$host" == "localhost" || "$host" == "$(hostname)" ]]; then
    install -m 0644 "$src" "$dst"
  else
    scp -q "$src" "$host:$dst"
  fi
}

# Latest GitHub Actions runner version. Cached to avoid hammering the API.
LATEST_RUNNER_CACHE="/tmp/.gh-runner-latest"
gh_runner_latest_version() {
  if [[ -f "$LATEST_RUNNER_CACHE" ]] && [[ $(($(date +%s) - $(stat -c %Y "$LATEST_RUNNER_CACHE"))) -lt 3600 ]]; then
    cat "$LATEST_RUNNER_CACHE"
    return
  fi
  local v
  v=$(gh api repos/actions/runner/releases/latest --jq .tag_name 2>/dev/null | sed 's/^v//')
  if [[ -z "$v" ]]; then v="2.333.1"; fi  # fallback
  echo "$v" > "$LATEST_RUNNER_CACHE"
  echo "$v"
}

# Mint a registration token for a repo.
gh_runner_token() {
  local repo="$1"
  gh api -X POST "repos/$repo/actions/runners/registration-token" --jq .token
}

# Mint a remove token for a repo.
gh_runner_remove_token() {
  local repo="$1"
  gh api -X POST "repos/$repo/actions/runners/remove-token" --jq .token
}

# List all runners registered for a repo.
gh_runner_list() {
  local repo="$1"
  gh api "repos/$repo/actions/runners" --jq '.runners[] | {id, name, status, busy, labels: [.labels[].name]}'
}
