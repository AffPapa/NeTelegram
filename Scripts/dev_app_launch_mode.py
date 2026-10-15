#!/usr/bin/env python3
"""Compare requested Dev.app preview flags with an already-running process."""

from __future__ import annotations

import json
import shlex
import sys
from collections.abc import Sequence


PREVIEW_FLAGS = frozenset({
    "--ci-auth-layout-preview",
    "--ci-auth-layout-preview-compact",
    "--ci-auth-layout-preview-minimum",
    "--ci-chat-shell-preview",
    "--ci-chat-shell-preview-compact",
    "--ci-appearance-dark",
    "--ci-appearance-light",
})


def launch_mode_mismatch(requested: Sequence[str], running_command: str) -> str | None:
    requested_flags = set(requested) & PREVIEW_FLAGS
    try:
        running_flags = set(shlex.split(running_command)) & PREVIEW_FLAGS
    except ValueError:
        return "cannot read the running app's launch arguments safely"
    if requested_flags == running_flags:
        return None
    if running_flags and not requested_flags:
        return "the running app is an offline UI preview; quit it before launching the normal client"
    if requested_flags and not running_flags:
        return "the running app is the normal client; quit it before launching a UI preview"
    return "the running app uses a different UI preview; quit it before changing preview mode"


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: dev_app_launch_mode.py <requested-flags-json> <running-command>", file=sys.stderr)
        return 2
    try:
        requested = json.loads(sys.argv[1])
    except json.JSONDecodeError:
        print("invalid requested launch flags", file=sys.stderr)
        return 2
    if not isinstance(requested, list) or not all(isinstance(flag, str) for flag in requested):
        print("requested launch flags must be a JSON string array", file=sys.stderr)
        return 2
    mismatch = launch_mode_mismatch(requested, sys.argv[2])
    if mismatch:
        print(mismatch, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
