from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / "Scripts" / "dev_app_launch_mode.py"
SPEC = importlib.util.spec_from_file_location("dev_app_launch_mode", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class DevAppLaunchModeTests(unittest.TestCase):
    def test_normal_reopen_matches_normal_running_process(self) -> None:
        self.assertIsNone(MODULE.launch_mode_mismatch(
            ["--app-support-root", "/private/tmp/netelegram-dev-support-clean"],
            "/private/tmp/NeTelegram-Dev.app/Contents/MacOS/NeTelegram --app-support-root /private/tmp/netelegram-dev-support-clean",
        ))

    def test_normal_launch_refuses_offline_auth_preview_reuse(self) -> None:
        mismatch = MODULE.launch_mode_mismatch(
            ["--app-support-root", "/private/tmp/netelegram-dev-support-clean"],
            "/private/tmp/NeTelegram-Dev.app/Contents/MacOS/NeTelegram --app-support-root /private/tmp/netelegram-dev-support-clean --ci-auth-layout-preview --ci-auth-layout-preview-compact --ci-appearance-dark",
        )
        self.assertIn("offline UI preview", mismatch or "")

    def test_preview_launch_refuses_normal_process_reuse(self) -> None:
        mismatch = MODULE.launch_mode_mismatch(
            ["--app-support-root", "/private/tmp/netelegram-dev-support-clean", "--ci-auth-layout-preview"],
            "/private/tmp/NeTelegram-Dev.app/Contents/MacOS/NeTelegram --app-support-root /private/tmp/netelegram-dev-support-clean",
        )
        self.assertIn("normal client", mismatch or "")

    def test_different_preview_layout_or_appearance_requires_quit(self) -> None:
        mismatch = MODULE.launch_mode_mismatch(
            ["--ci-auth-layout-preview", "--ci-auth-layout-preview-compact"],
            "/private/tmp/NeTelegram-Dev.app/Contents/MacOS/NeTelegram --ci-auth-layout-preview",
        )
        self.assertIn("different UI preview", mismatch or "")

    def test_minimum_auth_preview_is_distinct_from_compact_preview(self) -> None:
        mismatch = MODULE.launch_mode_mismatch(
            ["--ci-auth-layout-preview", "--ci-auth-layout-preview-minimum"],
            "/private/tmp/NeTelegram-Dev.app/Contents/MacOS/NeTelegram --ci-auth-layout-preview --ci-auth-layout-preview-compact",
        )
        self.assertIn("different UI preview", mismatch or "")

    def test_minimum_auth_preview_appearance_is_part_of_launch_identity(self) -> None:
        mismatch = MODULE.launch_mode_mismatch(
            ["--ci-auth-layout-preview", "--ci-auth-layout-preview-minimum", "--ci-appearance-light"],
            "/private/tmp/NeTelegram-Dev.app/Contents/MacOS/NeTelegram --ci-auth-layout-preview --ci-auth-layout-preview-minimum --ci-appearance-dark",
        )
        self.assertIn("different UI preview", mismatch or "")

    def test_malformed_running_command_fails_closed(self) -> None:
        mismatch = MODULE.launch_mode_mismatch([], '"unterminated')
        self.assertIn("cannot read", mismatch or "")


if __name__ == "__main__":
    unittest.main()
