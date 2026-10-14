import json
import hashlib
from pathlib import Path
import tempfile
import unittest
import plistlib
from unittest.mock import patch
import subprocess

from Scripts.generate_sbom import SBOMError, build_bom


ROOT = Path(__file__).resolve().parents[2]
COMMIT = "a" * 40


class GenerateSBOMTests(unittest.TestCase):
    def test_generates_cyclonedx_inventory_from_current_locks(self):
        bom = build_bom(ROOT, "0.1.0-alpha.1", COMMIT, "2026-10-14T00:00:00Z")
        self.assertEqual((bom["bomFormat"], bom["specVersion"]), ("CycloneDX", "1.6"))
        names = {item["name"] for item in bom["components"]}
        self.assertIn("TDLib", names)
        self.assertIn("OpenSSL", names)
        self.assertIn("gperf", names)
        self.assertEqual(next(c for c in bom["components"] if c["name"] == "gperf")["scope"], "excluded")
        coverage = {p["name"]: p["value"] for p in bom["metadata"]["component"]["properties"]}
        self.assertEqual(coverage["neTelegram:sbom:coverage"], "locked-source-dependency-inventory")
        self.assertEqual(coverage["neTelegram:sbom:release-binary-audit"], "required-before-release")
        self.assertEqual(json.loads(json.dumps(bom))["metadata"]["timestamp"], "2026-10-14T00:00:00Z")

    def test_release_bom_requires_successful_bundle_verification_before_claiming_complete(self):
        with self.assertRaisesRegex(SBOMError, "existing .app directory"):
            build_bom(ROOT, "1.2.3", COMMIT, app_bundle=Path("/tmp/missing-neTelegram.app"))

    def test_bundle_audit_records_executable_hashes_after_release_gates(self):
        from Scripts.generate_sbom import build_bom
        with tempfile.TemporaryDirectory() as temporary:
            app = Path(temporary) / "NeTelegram.app"
            (app / "Contents/MacOS").mkdir(parents=True)
            (app / "Contents/Frameworks").mkdir(parents=True)
            executable = app / "Contents/MacOS/NeTelegram"
            tdlib = app / "Contents/Frameworks/libtdjson.dylib"
            executable.write_bytes(b"release executable")
            tdlib.write_bytes(b"release tdlib")
            info = {
                "CFBundleShortVersionString": "1.2.3",
                "CFBundleIdentifier": "org.affpapa.netelegram",
                "CFBundleExecutable": "NeTelegram",
                "NeTelegramSourceCommit": COMMIT,
                "LSMinimumSystemVersion": "14.0",
            }
            (app / "Contents/Info.plist").write_bytes(plistlib.dumps(info))

            def completed(command, **_kwargs):
                output = ""
                if command[1:3] == ("-dv", "--verbose=4"):
                    output = "Authority=Developer ID Application: Example (TEAM)\nTeamIdentifier=TEAM\n"
                elif command[1] == "-archs":
                    output = "arm64\n"
                return subprocess.CompletedProcess(command, 0, stdout=output, stderr="")

            with patch("Scripts.generate_sbom.subprocess.run", side_effect=completed):
                bom = build_bom(ROOT, "1.2.3", COMMIT, "2026-10-14T00:00:00Z", app)
            props = {item["name"]: item["value"] for item in bom["metadata"]["component"]["properties"]}
            self.assertEqual(props["neTelegram:sbom:release-binary-audit"], "passed")
            self.assertEqual(bom["metadata"]["component"]["hashes"][0]["content"], hashlib.sha256(executable.read_bytes()).hexdigest())
            tdlib_component = next(item for item in bom["components"] if item["name"] == "TDLib")
            self.assertEqual(tdlib_component["hashes"][0]["content"], hashlib.sha256(tdlib.read_bytes()).hexdigest())

    def test_requires_full_source_commit_and_timestamp_zone(self):
        with self.assertRaisesRegex(SBOMError, "full lowercase"):
            build_bom(ROOT, "0.1.0", "abc")
        with self.assertRaisesRegex(SBOMError, "timezone"):
            build_bom(ROOT, "0.1.0", COMMIT, "2026-10-14T00:00:00")


if __name__ == "__main__":
    unittest.main()
