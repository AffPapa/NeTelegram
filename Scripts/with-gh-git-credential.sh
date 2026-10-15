#!/usr/bin/env bash
set -euo pipefail

# Run GitHub CLI using the credential already held by Git's configured helper.
# The credential is never printed or written to disk; GH_TOKEN exists only for
# this child process. Fail closed unless the API confirms the expected owner.
if [[ "$#" -eq 0 ]]; then
  printf 'usage: %s gh-arguments...\n' "$0" >&2
  exit 64
fi

set +x
credential_record="$(printf 'protocol=https\nhost=github.com\n\n' | GIT_TERMINAL_PROMPT=0 git -c credential.helper=osxkeychain credential fill)" || {
  printf 'Git credential helper did not provide a GitHub credential.\n' >&2
  exit 2
}
github_token="$(printf '%s\n' "$credential_record" | sed -n 's/^password=//p')"
unset credential_record
if [[ -z "$github_token" ]]; then
  printf 'Git credential helper returned no GitHub credential.\n' >&2
  exit 2
fi

github_login="$(GH_TOKEN="$github_token" gh api user --jq .login)" || {
  unset github_token
  printf 'Existing GitHub credential failed API authentication.\n' >&2
  exit 3
}
if [[ "$github_login" != 'AffPapa' ]]; then
  unset github_token
  printf 'GitHub credential belongs to an unexpected account; command refused.\n' >&2
  exit 4
fi

export GH_TOKEN="$github_token"
unset github_token github_login
exec gh "$@"
