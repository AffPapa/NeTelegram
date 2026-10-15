import os
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[2] / "Scripts/check-app-process.sh"


class AppProcessCheckTests(unittest.TestCase):
    def run_check(self, pgrep_status, swift_result=None, swift_status=0, pgrep_output="4242"):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            pgrep = root / "pgrep"
            pgrep.write_text(
                "#!/bin/sh\n"
                f"printf '%b\\n' '{pgrep_output}'\n"
                f"exit {pgrep_status}\n",
                encoding="utf-8",
            )
            pgrep.chmod(0o755)
            swift = root / "swift"
            swift.write_text(
                "#!/bin/sh\n"
                f"printf '%s' '{swift_result or ''}'\n"
                f"exit {swift_status}\n",
                encoding="utf-8",
            )
            swift.chmod(0o755)
            env = {
                **os.environ,
                "NETELEGRAM_PGREP_BIN": str(pgrep),
                "NETELEGRAM_PROCESS_SWIFT_BIN": str(swift),
                "NETELEGRAM_PROCESS_SWIFT_CACHE": str(root / "cache"),
            }
            return subprocess.run(
                [str(SCRIPT), "NeTelegram", "org.affpapa.netelegram.dev"],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )

    def test_pgrep_running_is_bound_to_requested_bundle_id(self):
        result = self.run_check(0, "running:4343", pgrep_output="4242\\n4343")
        self.assertEqual(result.returncode, 0)
        self.assertIn("running app NeTelegram (org.affpapa.netelegram.dev) (pid 4343)", result.stdout)

    def test_other_bundle_with_same_executable_does_not_block_dev_build(self):
        result = self.run_check(0, "other-only", pgrep_output="4242\\n4343")
        self.assertEqual(result.returncode, 1)

    def test_unknown_bundle_mapping_fails_closed(self):
        result = self.run_check(0, "unknown", pgrep_output="4242")
        self.assertEqual(result.returncode, 2)
        self.assertIn("Unable to verify bundle identity", result.stderr)

    def test_pgrep_no_match_is_authoritative(self):
        self.assertEqual(self.run_check(1).returncode, 1)

    def test_launch_services_fallback_detects_running_app(self):
        result = self.run_check(3, "running:4242")
        self.assertEqual(result.returncode, 0)
        self.assertIn("running app NeTelegram (org.affpapa.netelegram.dev) (pid 4242) detected by LaunchServices", result.stdout)

    def test_launch_services_empty_result_fails_closed(self):
        result = self.run_check(3, "absent")
        self.assertEqual(result.returncode, 2)
        self.assertIn("unable to prove process absence", result.stderr)

    def test_unknown_fallback_output_fails_closed(self):
        self.assertEqual(self.run_check(3, "maybe").returncode, 2)

    def test_fallback_execution_error_fails_closed(self):
        self.assertEqual(self.run_check(3, "", swift_status=7).returncode, 2)


if __name__ == "__main__":
    unittest.main()
