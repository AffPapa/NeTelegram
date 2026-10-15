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

For authenticated GitHub API operations, use the existing helper without persisting a new CLI token. First check the identity and target-repository permissions with output limited to non-secret metadata:

```sh
Scripts/with-gh-git-credential.sh api user --jq .login
Scripts/with-gh-git-credential.sh api repos/AffPapa/NeTelegram --jq '{full_name,private,permissions}'
```

The wrapper reads the already configured credential via `git credential fill`, checks the authenticated API owner is `AffPapa`, passes it only through the child process environment, and fails closed on missing or unexpected credentials. A plain `gh auth status` checks gh's separate stored login and is not the credential preflight for this route. Never run `gh auth login` or create another token to repair a stale CLI-specific credential when this route works.

If Keychain access or GitHub DNS fails inside the restricted command sandbox, classify it as a local execution boundary first. Retry the same read-only wrapper command once through the approved host-network route; do not switch repositories, alter remotes, open GitHub in a browser, or create a token. If identity and `permissions.push` are confirmed, use the same Git credential path for the already-authorized push. Record only the login, permission flags, source SHA, and result; never print or persist the credential.

## Publish the Site

Keep the existing Site `project_id` and its own source checkout. Use the official Sites source helper to commit, push, validate, and package the exact Site source, then use the native Sites API to save that archive and deploy its returned version. Do not point the app repository's `origin` at the Site repository. If the helper's Git endpoint is unreachable only inside the sandbox, retry the same helper and credential once through the approved host-network route. A successful deployment result plus the targeted anonymous route/MIME checks is sufficient; do not open a browser just to repeat those checks.

## One-candidate rule

For each milestone, freeze one source SHA and canonical Dev.app identity. Run one focused local regression while iterating; after the slice, use the automatic exact-SHA CI run as the full-suite gate. Rebuild and launch the canonical app only for visible AppKit, authentication, or lifecycle changes. A Site-only fix never rebuilds the app; a failed check must change the next action based on its diagnosed failure stage. Never repeat a successful gate for unchanged inputs.

## Read Actions status without a browser

The repository is public, so CI status is available from GitHub's unauthenticated REST API. Pass the full source or test commit SHA:

```sh
Scripts/github-ci-status.sh "$(git rev-parse HEAD)"
```

The script is read-only and prints each matching run's ID, workflow, status, conclusion, exact head SHA, and URL. An empty result means no run was found; it is not a pass. Use the URL only as a shareable reference; opening the GitHub UI is not part of routine development or verification.

## Accountless authorization layout smoke

To inspect all five authorization states at the minimum supported window size, launch the canonical offline preview:

```sh
Scripts/dev-app.sh --launch-auth-layout-preview-minimum-dark
Scripts/dev-app.sh --launch-auth-layout-preview-minimum-light
```

The window title reports the actual AppKit frame size. Press Command-Option-0 to cycle phone, code, password, QR, and registration. These per-process appearance overrides do not change macOS settings. The preview skips profile restoration and networking; it proves layout and accessibility-tree structure only, not Telegram authentication or account behavior. Exit the preview before launching the normal client or rebuilding.

## Release writes

Use the authenticated CLI wrapper for GitHub release operations only after confirming that the existing helper credential has the required repository permissions. Creating releases or uploading assets also requires completed signing, notarization, Gatekeeper, and compatibility gates. Check those gates independently. Do not create or broaden a token to work around a read-only CI lookup.
