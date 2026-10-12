# Website assets

The static development site is published through the existing OpenAI Sites project. Its source-sync checkout and Git remote are separate from this application repository. To update it, follow the current Sites workflow, keep the existing project ID, push the exact source state to the Site's own source remote, package and save that version, then deploy it. Never change this repository's `origin` to the Site helper remote.

`dist/` is the static output corresponding to the current development Site publication. It contains no app downloads until a verified release exists. Update it alongside completed milestones and releases; do not hand-edit version or download metadata outside the release manifest.
