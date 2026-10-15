#!/usr/bin/env bash
set -euo pipefail

# Read-only, unauthenticated GitHub REST lookup for this public repository.
# This avoids opening a browser or depending on gh's account token for CI checks.
repo='AffPapa/NeTelegram'
sha="${1:-}"
if [[ ! "$sha" =~ ^[0-9a-fA-F]{40}$ ]]; then
  printf 'usage: %s FULL_40_CHARACTER_COMMIT_SHA\n' "$0" >&2
  exit 64
fi

url="https://api.github.com/repos/${repo}/actions/runs?head_sha=${sha}&per_page=100"
response="$(curl --fail --silent --show-error --location --max-time 20 \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  "$url")"

python3 -c '
import json, sys
payload = json.loads(sys.argv[1])
runs = payload.get("workflow_runs", [])
if not runs:
    print("No workflow runs found for this commit SHA.")
    raise SystemExit(2)
for run in runs:
    print("run_id={id} workflow={name!r} event={event} status={status} conclusion={conclusion} head={head_sha} url={html_url}".format(
        id=run["id"], name=run.get("name", ""), event=run.get("event", ""),
        status=run.get("status", ""), conclusion=run.get("conclusion") or "pending",
        head_sha=run.get("head_sha", ""), html_url=run.get("html_url", "")))
' "$response"
