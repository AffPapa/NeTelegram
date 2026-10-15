# Fast source and CI workflow

## Publish source

From the canonical NeTelegram checkout, verify the repository and worktree before pushing:

```sh
git remote -v
git branch --show-current
git status --short
git rev-parse HEAD
git push origin main
```

Git transport uses the configured system credential helper. Do not start `gh auth login` just because the GitHub CLI reports a separate account token as invalid; Git transport, GitHub API access, and Sites access have separate credentials.

## Read Actions status without a browser

The repository is public, so CI status is available from GitHub's unauthenticated REST API. Pass the full source or test commit SHA:

```sh
Scripts/github-ci-status.sh "$(git rev-parse HEAD)"
```

The script is read-only and prints each matching run's ID, workflow, status, conclusion, exact head SHA, and URL. An empty result means no run was found; it is not a pass. Use the URL only as a shareable reference; opening the GitHub UI is not part of routine development or verification.

## Release writes

Creating releases or uploading assets requires a working write-capable API credential and completed signing, notarization, Gatekeeper, and compatibility gates. Check those gates independently. Do not create or broaden a token to work around a read-only CI lookup.
