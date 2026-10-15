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

For authenticated GitHub CLI operations, use the existing helper without persisting a new CLI token:

```sh
Scripts/with-gh-git-credential.sh api repos/AffPapa/NeTelegram
```

The wrapper reads the already configured credential via `git credential fill`, checks the authenticated API owner is `AffPapa`, passes it only through the child process environment, and fails closed on missing or unexpected credentials. Never run `gh auth login` or create another token to repair a stale CLI-specific credential when this route works.

## Read Actions status without a browser

The repository is public, so CI status is available from GitHub's unauthenticated REST API. Pass the full source or test commit SHA:

```sh
Scripts/github-ci-status.sh "$(git rev-parse HEAD)"
```

The script is read-only and prints each matching run's ID, workflow, status, conclusion, exact head SHA, and URL. An empty result means no run was found; it is not a pass. Use the URL only as a shareable reference; opening the GitHub UI is not part of routine development or verification.

## Accountless authorization layout smoke

To inspect all five authorization states at the minimum supported window size, launch the canonical offline preview:

```sh
Scripts/dev-app.sh --launch-auth-layout-preview-minimum
```

The window title reports the actual AppKit frame size. Press Command-Option-0 to cycle phone, code, password, QR, and registration. This preview skips profile restoration and networking; it proves layout and accessibility-tree structure only, not Telegram authentication or account behavior. Exit the preview before launching the normal client or rebuilding.

## Release writes

Use the authenticated CLI wrapper for GitHub release operations only after confirming that the existing helper credential has the required repository permissions. Creating releases or uploading assets also requires completed signing, notarization, Gatekeeper, and compatibility gates. Check those gates independently. Do not create or broaden a token to work around a read-only CI lookup.
