import json
import hashlib
from pathlib import Path
import tempfile
import unittest
import plistlib
import stat
from unittest.mock import patch
import subprocess
import zipfile

from Scripts.generate_sbom import SBOMError, audit_release_bundle, audit_release_zip, build_bom, validate_release_archive


ROOT = Path(__file__).resolve().parents[2]
COMMIT = "a" * 40


class GenerateSBOMTests(unittest.TestCase):
    def test_generates_cyclonedx_inventory_from_current_locks(self):
        bom = build_bom(ROOT, "0.1.0-alpha.1", COMMIT, "2026-10-14T00:00:00Z")
        self.assertEqual((bom["bomFormat"], bom["specVersion"]), ("CycloneDX", "1.6"))
        names = {item["name"] for item in bom["components"]}
        self.assertIn("TDLib", names)
        self.assertIn("Sparkle", names)
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
            app = Path(temporary) / "NeTide.app"
            (app / "Contents/MacOS").mkdir(parents=True)
            (app / "Contents/Frameworks").mkdir(parents=True)
            (app / "Contents/Frameworks/Sparkle.framework/Versions/B").mkdir(parents=True)
            executable = app / "Contents/MacOS/NeTelegram"
            tdlib = app / "Contents/Frameworks/libtdjson.dylib"
            sparkle = app / "Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle"
            executable.write_bytes(b"release executable")
            tdlib.write_bytes(b"release tdlib")
            sparkle.write_bytes(b"release sparkle")
            (app / "Contents/Frameworks/Sparkle.framework/Versions/Current").symlink_to("B")
            (app / "Contents/Frameworks/Sparkle.framework/Sparkle").symlink_to("Versions/Current/Sparkle")
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
                    output = "arm64 x86_64\n"
                return subprocess.CompletedProcess(command, 0, stdout=output, stderr="")

            with patch("Scripts.generate_sbom.subprocess.run", side_effect=completed):
                bom = build_bom(ROOT, "1.2.3", COMMIT, "2026-10-14T00:00:00Z", app,
                                expected_team_id="TEAM")
            props = {item["name"]: item["value"] for item in bom["metadata"]["component"]["properties"]}
            self.assertEqual(props["neTelegram:sbom:release-binary-audit"], "passed")
            self.assertEqual(bom["metadata"]["component"]["hashes"][0]["content"], hashlib.sha256(executable.read_bytes()).hexdigest())
            tdlib_component = next(item for item in bom["components"] if item["name"] == "TDLib")
            self.assertEqual(tdlib_component["hashes"][0]["content"], hashlib.sha256(tdlib.read_bytes()).hexdigest())
            sparkle_component = next(item for item in bom["components"] if item["name"] == "Sparkle")
            self.assertEqual(sparkle_component["hashes"][0]["content"], hashlib.sha256(sparkle.read_bytes()).hexdigest())

    def test_archive_validator_allows_contained_framework_links_and_rejects_escape(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive_path = Path(temporary) / "safe.zip"
            with zipfile.ZipFile(archive_path, "w") as archive:
                archive.writestr("NeTide.app/Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle", b"binary")
                link = zipfile.ZipInfo("NeTide.app/Contents/Frameworks/Sparkle.framework/Versions/Current")
                link.create_system = 3
                link.external_attr = (stat.S_IFLNK | 0o777) << 16
                archive.writestr(link, "B")
                link = zipfile.ZipInfo("NeTide.app/Contents/Frameworks/Sparkle.framework/Sparkle")
                link.create_system = 3
                link.external_attr = (stat.S_IFLNK | 0o777) << 16
                archive.writestr(link, "Versions/Current/Sparkle")
            with zipfile.ZipFile(archive_path) as archive:
                self.assertEqual(len(validate_release_archive(archive)), 3)

            with zipfile.ZipFile(archive_path, "w") as archive:
                link = zipfile.ZipInfo("NeTide.app/Contents/Frameworks/escape")
                link.create_system = 3
                link.external_attr = (stat.S_IFLNK | 0o777) << 16
                archive.writestr(link, "../../../../../../outside")
            with zipfile.ZipFile(archive_path) as archive:
                with self.assertRaisesRegex(SBOMError, "escapes"):
                    validate_release_archive(archive)

    def test_bundle_audit_requires_exact_expected_team_id(self):
        with tempfile.TemporaryDirectory() as temporary:
            app = Path(temporary) / "NeTide.app"
            (app / "Contents/MacOS").mkdir(parents=True)
            (app / "Contents/Frameworks").mkdir(parents=True)
            (app / "Contents/MacOS/NeTelegram").write_bytes(b"executable")
            (app / "Contents/Frameworks/libtdjson.dylib").write_bytes(b"tdlib")
            (app / "Contents/Frameworks/Sparkle.framework/Versions/B").mkdir(parents=True)
            (app / "Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle").write_bytes(b"sparkle")
            (app / "Contents/Frameworks/Sparkle.framework/Versions/Current").symlink_to("B")
            (app / "Contents/Frameworks/Sparkle.framework/Sparkle").symlink_to("Versions/Current/Sparkle")
            (app / "Contents/Info.plist").write_bytes(plistlib.dumps({
                "CFBundleShortVersionString": "1.2.3",
                "CFBundleIdentifier": "org.affpapa.netelegram",
                "CFBundleExecutable": "NeTelegram",
                "NeTelegramSourceCommit": COMMIT,
            }))
            def completed(command, **_kwargs):
                output = "Authority=Developer ID Application: Example (ABCDEFGHIJ)\nTeamIdentifier=ABCDEFGHIJ\n" if command[1] == "-dv" else "arm64\n"
                return subprocess.CompletedProcess(command, 0, stdout=output, stderr="")
            with patch("Scripts.generate_sbom.subprocess.run", side_effect=completed):
                with self.assertRaisesRegex(SBOMError, "does not match"):
                    audit_release_bundle(app, "1.2.3", COMMIT, "ZYXWVUTSRQ")

    def test_final_zip_audit_binds_exact_archive_and_rejects_unsafe_entries(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive_path = Path(temporary) / "NeTide.zip"
            with zipfile.ZipFile(archive_path, "w") as archive:
                archive.writestr("NeTide.app/Contents/Info.plist", b"plist")
            audit = {"executable_sha256": "x", "tdlib_sha256": "y", "team_id": "ABCDEFGHIJ"}
            with patch("Scripts.generate_sbom.sys.platform", "darwin"), \
                 patch("Scripts.generate_sbom.audit_release_bundle", return_value=audit) as bundle_audit:
                result = audit_release_zip(archive_path, "1.2.3", COMMIT, "ABCDEFGHIJ")
            self.assertEqual(result["app_zip_sha256"], hashlib.sha256(archive_path.read_bytes()).hexdigest())
            bundle_audit.assert_called_once()
            with zipfile.ZipFile(archive_path, "w") as archive:
                archive.writestr("../outside", b"bad")
            with patch("Scripts.generate_sbom.sys.platform", "darwin"):
                with self.assertRaisesRegex(SBOMError, "unsafe"):
                    audit_release_zip(archive_path, "1.2.3", COMMIT, "ABCDEFGHIJ")

    def test_final_zip_hash_and_audit_use_the_same_snapshot_if_source_changes(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive_path = Path(temporary) / "NeTide.zip"
            with zipfile.ZipFile(archive_path, "w") as archive:
                archive.writestr("NeTide.app/Contents/Info.plist", b"audited snapshot")
            expected_digest = hashlib.sha256(archive_path.read_bytes()).hexdigest()
            def audit_then_replace(bundle, _version, _commit, _team):
                self.assertEqual((bundle / "Contents/Info.plist").read_bytes(), b"audited snapshot")
                with zipfile.ZipFile(archive_path, "w") as changed:
                    changed.writestr("NeTide.app/Contents/Info.plist", b"different final bytes")
                    changed.writestr("NeTide.app/Contents/Resources/extra", b"changed")
                return {"team_id": "ABCDEFGHIJ"}
            with patch("Scripts.generate_sbom.sys.platform", "darwin"), \
                 patch("Scripts.generate_sbom.audit_release_bundle", side_effect=audit_then_replace):
                result = audit_release_zip(archive_path, "1.2.3", COMMIT, "ABCDEFGHIJ")
            self.assertEqual(result["app_zip_sha256"], expected_digest)
            self.assertNotEqual(result["app_zip_sha256"], hashlib.sha256(archive_path.read_bytes()).hexdigest())

    def test_requires_full_source_commit_and_timestamp_zone(self):
        with self.assertRaisesRegex(SBOMError, "full lowercase"):
            build_bom(ROOT, "0.1.0", "abc")
        with self.assertRaisesRegex(SBOMError, "timezone"):
            build_bom(ROOT, "0.1.0", COMMIT, "2026-10-14T00:00:00")


if __name__ == "__main__":
    unittest.main()
