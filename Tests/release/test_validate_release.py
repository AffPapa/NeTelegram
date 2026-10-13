import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from Scripts.validate_release import ValidationError, validate_candidate, validate_receipt


def valid_candidate(root: Path, *, channel: str = "alpha", accounts: int = 1) -> tuple[Path, Path, dict]:
    assets = root / "assets"
    assets.mkdir()
    artifacts = []
    for kind, filename in (("app_zip", "NeTelegram.zip"), ("dmg", "NeTelegram.dmg")):
        path = assets / filename
        data = f"fixture:{filename}".encode()
        path.write_bytes(data)
        artifacts.append({
            "kind": kind,
            "filename": filename,
            "path": filename,
            "url": f"https://github.com/AffPapa/NeTelegram/releases/download/v1.2.3/{filename}",
            "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
            "signing_status": "passed",
            "notarization_status": "accepted_stapled",
            "gatekeeper_status": "passed",
            "verification_evidence": ["notary-log-sha256:123", "gatekeeper-smoke:456"],
        })
    source_commit = "a" * 40
    manifest = {
        "schema_version": 1,
        "record_status": "release_candidate",
        "release_id": "netelegram-1.2.3-100",
        "product": "NeTelegram",
        "public_title": "NeTelegram",
        "version": "1.2.3",
        "build_number": 100,
        "channel": channel,
        "record_created_at": "2026-10-14T01:02:03Z",
        "repository": "AffPapa/NeTelegram",
        "tag": "v1.2.3",
        "source_commit": source_commit,
        "tdlib_commit": "b" * 40,
        "license_spdx": "MIT",
        "release_url": "https://github.com/AffPapa/NeTelegram/releases/tag/v1.2.3",
        "minimum_macos": "14.0",
        "architectures": ["arm64"],
        "artifacts": artifacts,
        "changes": ["Example change"],
        "known_limitations": ["Prerelease coverage is limited"],
        "test_evidence": [{
            "result": "passed",
            "source_commit": source_commit,
            "kind": "real_account_smoke",
            "accounts_tested": accounts,
            "scope": "One authorized account login and text smoke",
            "environment": "macOS 15 arm64",
            "evidence_ref": "https://github.com/AffPapa/NeTelegram/actions/runs/123",
        }],
        "account_coverage": {
            "real_authorized_accounts": accounts,
            "performance_account_counts": [1],
            "performance_matrix": [],
        },
        "telegram_compatibility": {
            "terms_2_3_title": "open",
            "sponsored_media_3_3": "deferred",
            "basic_functionality_1_3_1_4": "open",
        },
        "artifact_contract": {"private_key_included": False},
    }
    manifest_path = root / "release.json"
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    return manifest_path, assets, manifest


class CandidateValidationTests(unittest.TestCase):
    def test_valid_prerelease_checks_exact_asset_bytes_and_account_evidence(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest, assets, _ = valid_candidate(Path(temporary))
            self.assertEqual(len(validate_candidate(manifest, assets)), 64)

    def test_template_is_not_publishable(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            template = root / "template.json"
            template.write_text(json.dumps({"record_status": "template_not_a_release"}), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "release_candidate"):
                validate_candidate(template, root)

    def test_stable_requires_twenty_real_authorized_accounts(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest, assets, _ = valid_candidate(Path(temporary), channel="stable", accounts=1)
            with self.assertRaisesRegex(ValidationError, "at least 20 real authorized"):
                validate_candidate(manifest, assets)

    def test_mismatched_asset_bytes_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest, assets, data = valid_candidate(Path(temporary))
            (assets / "NeTelegram.zip").write_bytes(b"changed bytes")
            with self.assertRaisesRegex(ValidationError, "do not match"):
                validate_candidate(manifest, assets)

    def test_missing_performance_matrix_levels_are_rejected_for_stable(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest, assets, data = valid_candidate(Path(temporary), channel="stable", accounts=20)
            data["account_coverage"]["performance_account_counts"] = [1, 5, 10]
            manifest.write_text(json.dumps(data), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "include 1, 5, 10, and 20"):
                validate_candidate(manifest, assets)

    def test_stable_candidate_requires_real_twenty_account_matrix_and_compatibility(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest_path, assets, manifest = valid_candidate(Path(temporary), channel="stable", accounts=20)
            manifest["account_coverage"]["performance_account_counts"] = [1, 5, 10, 20]
            metric_names = (
                "physical_memory_mb_p50", "physical_memory_mb_p95",
                "idle_cpu_percent_p50", "idle_cpu_percent_p95",
                "wakeups_per_hour_p50", "wakeups_per_hour_p95",
                "network_bytes_per_hour_p50", "network_bytes_per_hour_p95",
                "decode_latency_ms_p50", "decode_latency_ms_p95",
            )
            manifest["account_coverage"]["performance_matrix"] = [
                {
                    "connected_accounts": count,
                    "host_id": "test-mac-1",
                    "corpus_id": "fixture-corpus",
                    "toolchain": "Xcode 16.4 / Swift 6.1.2",
                    "architecture": "arm64",
                    "duration_seconds": 60,
                    "evidence_ref": "https://github.com/AffPapa/NeTelegram/actions/runs/456",
                    **{metric: 0 for metric in metric_names},
                }
                for count in (1, 5, 10, 20)
            ]
            manifest["telegram_compatibility"] = {
                "terms_2_3_title": "passed",
                "sponsored_media_3_3": "passed",
                "basic_functionality_1_3_1_4": "passed",
            }
            manifest["test_evidence"][0]["accounts_tested"] = 20
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            self.assertEqual(len(validate_candidate(manifest_path, assets)), 64)

    def test_sparkle_update_requires_complete_matching_metadata(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest_path, assets, manifest = valid_candidate(Path(temporary))
            update = assets / "NeTelegram-update.zip"
            payload = b"update fixture"
            update.write_bytes(payload)
            manifest["artifacts"].append({
                "kind": "sparkle_update_zip",
                "filename": update.name,
                "path": update.name,
                "url": "https://github.com/AffPapa/NeTelegram/releases/download/v1.2.3/NeTelegram-update.zip",
                "bytes": len(payload),
                "sha256": hashlib.sha256(payload).hexdigest(),
                "signing_status": "passed",
                "notarization_status": "accepted_stapled",
                "gatekeeper_status": "passed",
                "verification_evidence": ["sparkle-signature-verified"],
            })
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "sparkle_ed_signature"):
                validate_candidate(manifest_path, assets)

    def test_synthetic_tests_do_not_substitute_for_real_account_coverage(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest_path, assets, manifest = valid_candidate(Path(temporary))
            manifest["test_evidence"][0]["kind"] = "synthetic_suite"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "real-account evidence must cover"):
                validate_candidate(manifest_path, assets)

    def test_secret_fields_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest_path, assets, manifest = valid_candidate(Path(temporary))
            manifest["api_hash"] = "must-not-appear"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "Secret-bearing field"):
                validate_candidate(manifest_path, assets)

    def test_asset_path_cannot_escape_candidate_directory(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest_path, assets, manifest = valid_candidate(Path(temporary))
            manifest["artifacts"][0]["path"] = "../outside.zip"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "must stay inside"):
                validate_candidate(manifest_path, assets)

    def test_receipt_must_match_frozen_manifest_hash_and_public_bytes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            manifest_path, assets, manifest = valid_candidate(root)
            digest = validate_candidate(manifest_path, assets)
            receipt = {
                "record_status": "publication_verified",
                "manifest_sha256": digest,
                "source_commit": manifest["source_commit"],
                "published_at": "2026-10-14T02:00:00Z",
                "verified_at": "2026-10-14T02:10:00Z",
                "assets": [
                    {
                        "filename": artifact["filename"],
                        "url": artifact["url"],
                        "bytes": artifact["bytes"],
                        "sha256": artifact["sha256"],
                        "public_http_status": 200,
                        "download_sha256": artifact["sha256"],
                    }
                    for artifact in manifest["artifacts"]
                ],
                "checks": {
                    "gatekeeper_quarantine_smoke": "passed",
                    "native_install_reopen": "passed",
                    "site_download_links": "passed",
                    "update_feed": "passed",
                },
            }
            receipt_path = root / "receipt.json"
            receipt_path.write_text(json.dumps(receipt), encoding="utf-8")
            self.assertEqual(validate_receipt(manifest_path, receipt_path), digest)
            receipt["manifest_sha256"] = "0" * 64
            receipt_path.write_text(json.dumps(receipt), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "does not match"):
                validate_receipt(manifest_path, receipt_path)


if __name__ == "__main__":
    unittest.main()
