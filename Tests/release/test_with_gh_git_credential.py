from __future__ import annotations

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Scripts/with-gh-git-credential.sh"
FAKE_CREDENTIAL = "test-only-do-not-print-this"


class GitHubCredentialWrapperTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.bin = Path(self.temp.name) / "bin"
        self.bin.mkdir()
        self.trace = Path(self.temp.name) / "trace"
        git = self.bin / "git"
        git.write_text(
            "#!/bin/sh\n"
            "printf '%s\\n' \"$*\" >> \"$TEST_TRACE\"\n"
            "if [ \"${TEST_GIT_FAIL:-0}\" = 1 ]; then exit 1; fi\n"
            "printf 'protocol=https\\nhost=github.com\\nusername=test\\npassword=%s\\n' \"$TEST_CREDENTIAL\"\n",
            encoding="utf-8",
        )
        git.chmod(0o755)
        gh = self.bin / "gh"
        gh.write_text(
            "#!/bin/sh\n"
            "if [ \"$*\" = 'api user --jq .login' ]; then printf '%s\\n' \"$TEST_LOGIN\"; exit 0; fi\n"
            "[ \"${GH_TOKEN:-}\" = \"$TEST_CREDENTIAL\" ] || exit 19\n"
            "printf 'forwarded:%s\\n' \"$*\" >> \"$TEST_TRACE\"\n"
            "printf 'ok\\n'\n",
            encoding="utf-8",
        )
        gh.chmod(0o755)
        self.env = os.environ.copy()
        self.env.update({
            "PATH": f"{self.bin}:{self.env.get('PATH', '')}",
            "TEST_TRACE": str(self.trace),
            "TEST_CREDENTIAL": FAKE_CREDENTIAL,
            "TEST_LOGIN": "AffPapa",
        })

    def run_wrapper(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(SCRIPT), *args], cwd=ROOT, env=self.env, text=True,
            capture_output=True, check=False,
        )

    def test_uses_osxkeychain_and_forwards_token_only_to_child_process(self) -> None:
        result = self.run_wrapper("release", "list", "--repo", "AffPapa/NeTelegram")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "ok\n")
        self.assertNotIn(FAKE_CREDENTIAL, result.stdout + result.stderr)
        trace = self.trace.read_text(encoding="utf-8")
        self.assertIn("-c credential.helper=osxkeychain credential fill", trace)
        self.assertIn("forwarded:release list --repo AffPapa/NeTelegram", trace)

    def test_refuses_non_affpapa_credential_without_forwarding(self) -> None:
        self.env["TEST_LOGIN"] = "someone-else"
        result = self.run_wrapper("release", "list", "--repo", "AffPapa/NeTelegram")
        self.assertEqual(result.returncode, 4)
        self.assertIn("unexpected account", result.stderr)
        self.assertNotIn("forwarded:", self.trace.read_text(encoding="utf-8"))
        self.assertNotIn(FAKE_CREDENTIAL, result.stdout + result.stderr)

    def test_reports_missing_keychain_credential_without_running_gh(self) -> None:
        self.env["TEST_GIT_FAIL"] = "1"
        result = self.run_wrapper("api", "user")
        self.assertEqual(result.returncode, 2)
        self.assertIn("credential", result.stderr)
        self.assertNotIn("forwarded:", self.trace.read_text(encoding="utf-8"))

    def test_requires_a_github_cli_command(self) -> None:
        result = self.run_wrapper()
        self.assertEqual(result.returncode, 64)


if __name__ == "__main__":
    unittest.main()
