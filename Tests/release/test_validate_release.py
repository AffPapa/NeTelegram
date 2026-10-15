import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import zipfile
import stat

from Scripts.validate_release import ValidationError, validate_candidate, validate_receipt


def valid_candidate(root: Path, *, channel: str = "alpha", accounts: int = 1) -> tuple[Path, Path, dict]:
    assets = root / "assets"
    assets.mkdir()
    artifacts = []
    source_commit = "a" * 40
    executable_bytes = b"fixture:NeTelegram executable"
    tdlib_bytes = b"fixture:libtdjson"
    sparkle_bytes = b"fixture:Sparkle"
    app_archive = assets / "NeTide.zip"
    with zipfile.ZipFile(app_archive, "w") as archive:
        archive.writestr("NeTide.app/Contents/MacOS/NeTelegram", executable_bytes)
        archive.writestr("NeTide.app/Contents/Frameworks/libtdjson.dylib", tdlib_bytes)
        archive.writestr("NeTide.app/Contents/Frameworks/Sparkle.framework/Sparkle", sparkle_bytes)
    sbom_path = assets / "NeTelegram.cdx.json"
    sbom_path.write_text(json.dumps({
        "bomFormat": "CycloneDX",
        "specVersion": "1.6",
        "metadata": {"component": {
            "name": "NeTelegram",
            "version": "1.2.3",
            "hashes": [{"alg": "SHA-256", "content": hashlib.sha256(executable_bytes).hexdigest()}],
            "properties": [
                {"name": "neTelegram:source:commit", "value": source_commit},
                {"name": "neTelegram:sbom:release-binary-audit", "value": "passed"},
                {"name": "neTelegram:sbom:audit-input", "value": "final-app-zip"},
                {"name": "neTelegram:sbom:audited-app-zip-sha256", "value": hashlib.sha256(app_archive.read_bytes()).hexdigest()},
                {"name": "neTelegram:signing:team-id", "value": "ABCDEFGHIJ"},
            ],
        }},
        "components": [
            {"name": "TDLib", "hashes": [{"alg": "SHA-256", "content": hashlib.sha256(tdlib_bytes).hexdigest()}]},
            {"name": "Sparkle", "hashes": [{"alg": "SHA-256", "content": hashlib.sha256(sparkle_bytes).hexdigest()}]},
        ],
    }), encoding="utf-8")
    notice_path = assets / "THIRD-PARTY-NOTICES.txt"
    notice_path.write_text("MIT License\nTDLib\nOpenSSL\ngperf\n", encoding="utf-8")
    artifacts.extend([
        {
            "kind": "app_zip", "filename": app_archive.name, "path": app_archive.name,
            "url": f"https://github.com/AffPapa/NeTelegram/releases/download/v1.2.3/{app_archive.name}",
            "bytes": app_archive.stat().st_size, "sha256": hashlib.sha256(app_archive.read_bytes()).hexdigest(),
            "signing_status": "passed", "notarization_status": "accepted_stapled", "gatekeeper_status": "passed",
            "verification_evidence": ["notary-log-sha256:123", "gatekeeper-smoke:456"],
        },
        {
            "kind": "dmg", "filename": "NeTide.dmg", "path": "NeTide.dmg",
            "url": "https://github.com/AffPapa/NeTelegram/releases/download/v1.2.3/NeTide.dmg",
            "bytes": len(b"fixture:NeTide.dmg"), "sha256": hashlib.sha256(b"fixture:NeTide.dmg").hexdigest(),
            "signing_status": "passed", "notarization_status": "accepted_stapled", "gatekeeper_status": "passed",
            "verification_evidence": ["notary-log-sha256:123", "gatekeeper-smoke:456"],
        },
    ])
    (assets / "NeTide.dmg").write_bytes(b"fixture:NeTide.dmg")
    update_path = assets / "NeTelegram-update.zip"
    update_bytes = b"fixture:signed Sparkle update archive"
    update_path.write_bytes(update_bytes)
    artifacts.append({
        "kind": "sparkle_update_zip",
        "filename": update_path.name,
        "path": update_path.name,
        "url": f"https://github.com/AffPapa/NeTelegram/releases/download/v1.2.3/{update_path.name}",
        "bytes": len(update_bytes),
        "sha256": hashlib.sha256(update_bytes).hexdigest(),
        "signing_status": "passed",
        "notarization_status": "accepted_stapled",
        "gatekeeper_status": "passed",
        "verification_evidence": ["sparkle-signature-verified", "gatekeeper-smoke:456"],
        "sparkle_ed_signature": "fixture-signature",
        "sparkle_key_account": "netide-updates",
        "sparkle_version": "2.10.0",
        "sparkle_short_version": "1.2.3",
        "update_channel": channel,
        "minimum_system_version": "14.0",
    })
    for kind, path in (("sbom", sbom_path), ("notice", notice_path)):
        data = path.read_bytes()
        artifacts.append({
            "kind": kind,
            "filename": path.name,
            "path": path.name,
            "url": f"https://github.com/AffPapa/NeTelegram/releases/download/v1.2.3/{path.name}",
            "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
            "verification_evidence": ["fixture-source-and-byte-reconciliation"],
        })
    manifest = {
        "schema_version": 1,
        "record_status": "release_candidate",
        "release_id": "netelegram-1.2.3-100",
        "product": "NeTelegram",
        "public_title": "NeTide",
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
        "artifact_contract": {
            "private_key_included": False,
            "required_kinds": ["app_zip", "dmg", "sbom", "notice", "sparkle_update_zip"],
        },
    }
    manifest_path = root / "release.json"
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    return manifest_path, assets, manifest


def validate_fixture_candidate(root: Path, manifest: Path, assets: Path) -> str:
    """Use a deterministic verifier stub; it never claims a real Sparkle signature."""
    verifier = root / "fixture-sign_update"
    verifier.write_text(
        "#!/bin/sh\n"
        "[ \"$1\" = \"--account\" ] || exit 19\n"
        "[ \"$2\" = \"netide-updates\" ] || exit 20\n"
        "[ \"$3\" = \"--verify\" ] || exit 21\n"
        "[ -f \"$4\" ] || exit 22\n"
        "[ \"$5\" = \"fixture-signature\" ] || exit 23\n"
        "exit 0\n",
        encoding="utf-8",
    )
    verifier.chmod(0o700)
    return validate_candidate(manifest, assets, sparkle_sign_update=verifier)


class CandidateValidationTests(unittest.TestCase):
    def test_public_title_uses_selected_name_without_telegram(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest_path, assets, manifest = valid_candidate(Path(temporary))
            manifest["public_title"] = "NeTelegram"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "public_title may use Telegram only with the required Unofficial prefix"):
                validate_fixture_candidate(Path(temporary), manifest_path, assets)

    def test_duplicate_artifact_kinds_are_rejected_even_with_distinct_filenames(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest_path, assets, manifest = valid_candidate(Path(temporary))
            duplicate = dict(manifest["artifacts"][0])
            duplicate["filename"] = "NeTelegram-copy.zip"
            duplicate["path"] = duplicate["filename"]
            duplicate["url"] = duplicate["url"].removesuffix("NeTide.zip") + duplicate["filename"]
            duplicate_path = assets / duplicate["path"]
            duplicate_path.write_bytes((assets / "NeTide.zip").read_bytes())
            duplicate["bytes"] = duplicate_path.stat().st_size
            duplicate["sha256"] = hashlib.sha256(duplicate_path.read_bytes()).hexdigest()
            manifest["artifacts"].append(duplicate)
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "kind must appear only once: app_zip"):
                validate_fixture_candidate(Path(temporary), manifest_path, assets)

    def test_requires_reconciled_sbom_and_third_party_notices(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest_path, assets, manifest = valid_candidate(Path(temporary))
            manifest["artifacts"] = [item for item in manifest["artifacts"] if item["kind"] != "notice"]
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "must include app_zip, dmg, sbom, notice, and sparkle_update_zip"):
                validate_fixture_candidate(Path(temporary), manifest_path, assets)

    def test_candidate_requires_a_sparkle_update_archive(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest_path, assets, manifest = valid_candidate(Path(temporary))
            manifest["artifacts"] = [item for item in manifest["artifacts"] if item["kind"] != "sparkle_update_zip"]
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "missing sparkle_update_zip"):
                validate_fixture_candidate(Path(temporary), manifest_path, assets)

    def test_manifest_contract_must_declare_every_required_release_asset(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest_path, assets, manifest = valid_candidate(Path(temporary))
            manifest["artifact_contract"]["required_kinds"].remove("sparkle_update_zip")
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "artifact_contract.required_kinds"):
                validate_fixture_candidate(Path(temporary), manifest_path, assets)

    def test_candidate_cryptographically_verifies_sparkle_archive_signature(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest_path, assets, manifest = valid_candidate(Path(temporary))
            update = next(item for item in manifest["artifacts"] if item["kind"] == "sparkle_update_zip")
            update["sparkle_ed_signature"] = "not-the-fixture-signature"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "Sparkle EdDSA signature verification failed"):
                validate_fixture_candidate(Path(temporary), manifest_path, assets)

    def test_candidate_fails_closed_when_sparkle_verifier_is_missing(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest_path, assets, _ = valid_candidate(Path(temporary))
            with self.assertRaisesRegex(ValidationError, "pinned Sparkle sign_update verifier is unavailable"):
                validate_candidate(
                    manifest_path,
                    assets,
                    sparkle_sign_update=Path(temporary) / "missing-sign_update",
                )

    def test_sbom_binary_hashes_must_match_the_app_zip(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest_path, assets, manifest = valid_candidate(Path(temporary))
            sbom_artifact = next(item for item in manifest["artifacts"] if item["kind"] == "sbom")
            sbom_path = assets / sbom_artifact["path"]
            sbom = json.loads(sbom_path.read_text(encoding="utf-8"))
            sbom["components"][0]["hashes"][0]["content"] = "0" * 64
            changed = json.dumps(sbom).encode()
            sbom_path.write_bytes(changed)
            sbom_artifact["bytes"] = len(changed)
            sbom_artifact["sha256"] = hashlib.sha256(changed).hexdigest()
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "SBOM TDLib hash does not match app_zip"):
                validate_fixture_candidate(Path(temporary), manifest_path, assets)

    def test_source_only_sbom_cannot_be_published_as_a_release_sbom(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest_path, assets, manifest = valid_candidate(Path(temporary))
            artifact = next(item for item in manifest["artifacts"] if item["kind"] == "sbom")
            path = assets / artifact["path"]
            sbom = json.loads(path.read_text(encoding="utf-8"))
            sbom["metadata"]["component"]["properties"][1]["value"] = "required-before-release"
            data = json.dumps(sbom).encode()
            path.write_bytes(data)
            artifact["bytes"] = len(data)
            artifact["sha256"] = hashlib.sha256(data).hexdigest()
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "not reconciled with the signed notarized"):
                validate_fixture_candidate(Path(temporary), manifest_path, assets)

    def test_sbom_must_bind_the_exact_final_archive_hash(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest_path, assets, manifest = valid_candidate(Path(temporary))
            sbom_artifact = next(item for item in manifest["artifacts"] if item["kind"] == "sbom")
            sbom_path = assets / sbom_artifact["path"]
            sbom = json.loads(sbom_path.read_text(encoding="utf-8"))
            props = sbom["metadata"]["component"]["properties"]
            next(p for p in props if p["name"] == "neTelegram:sbom:audited-app-zip-sha256")["value"] = "0" * 64
            data = json.dumps(sbom).encode()
            sbom_path.write_bytes(data)
            sbom_artifact["bytes"] = len(data)
            sbom_artifact["sha256"] = hashlib.sha256(data).hexdigest()
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "final app ZIP hash"):
                validate_fixture_candidate(Path(temporary), manifest_path, assets)

    def test_release_asset_url_must_match_the_candidate_tag_and_filename(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest_path, assets, manifest = valid_candidate(Path(temporary))
            manifest["artifacts"][0]["url"] = "https://example.com/NeTide.zip"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "matching GitHub release"):
                validate_fixture_candidate(Path(temporary), manifest_path, assets)

    def test_app_zip_parent_traversal_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest_path, assets, manifest = valid_candidate(Path(temporary))
            app = assets / "NeTide.zip"
            with zipfile.ZipFile(app, "w") as archive:
                archive.writestr("../outside.txt", b"unsafe")
            artifact = next(item for item in manifest["artifacts"] if item["kind"] == "app_zip")
            artifact["bytes"] = app.stat().st_size
            artifact["sha256"] = hashlib.sha256(app.read_bytes()).hexdigest()
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "parent-traversal"):
                validate_fixture_candidate(Path(temporary), manifest_path, assets)

    def test_candidate_validator_reuses_single_app_root_and_special_file_guards(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest_path, assets, manifest = valid_candidate(Path(temporary))
            app = assets / "NeTide.zip"
            symlink = zipfile.ZipInfo("NeTide.app/Contents/Frameworks/unsafe")
            symlink.external_attr = (stat.S_IFLNK | 0o777) << 16
            with zipfile.ZipFile(app, "w") as archive:
                archive.writestr("other/NeTide.app/Contents/MacOS/NeTelegram", b"x")
                archive.writestr("other/NeTide.app/Contents/Frameworks/libtdjson.dylib", b"y")
                archive.writestr(symlink, "../../../../outside")
            artifact = next(item for item in manifest["artifacts"] if item["kind"] == "app_zip")
            artifact["bytes"] = app.stat().st_size
            artifact["sha256"] = hashlib.sha256(app.read_bytes()).hexdigest()
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "archive structure is invalid: app ZIP contains an unsafe"):
                validate_fixture_candidate(Path(temporary), manifest_path, assets)

    def test_valid_prerelease_checks_exact_asset_bytes_and_account_evidence(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest, assets, _ = valid_candidate(Path(temporary))
            self.assertEqual(len(validate_fixture_candidate(Path(temporary), manifest, assets)), 64)

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
                validate_fixture_candidate(Path(temporary), manifest, assets)

    def test_mismatched_asset_bytes_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest, assets, data = valid_candidate(Path(temporary))
            (assets / "NeTide.zip").write_bytes(b"changed bytes")
            with self.assertRaisesRegex(ValidationError, "do not match"):
                validate_fixture_candidate(Path(temporary), manifest, assets)

    def test_missing_performance_matrix_levels_are_rejected_for_stable(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest, assets, data = valid_candidate(Path(temporary), channel="stable", accounts=20)
            data["account_coverage"]["performance_account_counts"] = [1, 5, 10]
            manifest.write_text(json.dumps(data), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "include 1, 5, 10, and 20"):
                validate_fixture_candidate(Path(temporary), manifest, assets)

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
            self.assertEqual(len(validate_fixture_candidate(Path(temporary), manifest_path, assets)), 64)

    def test_sparkle_update_requires_complete_matching_metadata(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest_path, assets, manifest = valid_candidate(Path(temporary))
            update = next(item for item in manifest["artifacts"] if item["kind"] == "sparkle_update_zip")
            del update["sparkle_ed_signature"]
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "sparkle_ed_signature"):
                validate_fixture_candidate(Path(temporary), manifest_path, assets)

    def test_sparkle_key_account_is_required_and_restricted(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest_path, assets, manifest = valid_candidate(Path(temporary))
            update = next(item for item in manifest["artifacts"] if item["kind"] == "sparkle_update_zip")
            update["sparkle_key_account"] = "../other-key"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "sparkle_key_account contains unsupported characters"):
                validate_fixture_candidate(Path(temporary), manifest_path, assets)

    def test_synthetic_tests_do_not_substitute_for_real_account_coverage(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest_path, assets, manifest = valid_candidate(Path(temporary))
            manifest["test_evidence"][0]["kind"] = "synthetic_suite"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "real-account evidence must cover"):
                validate_fixture_candidate(Path(temporary), manifest_path, assets)

    def test_secret_fields_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest_path, assets, manifest = valid_candidate(Path(temporary))
            manifest["api_hash"] = "must-not-appear"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "Secret-bearing field"):
                validate_fixture_candidate(Path(temporary), manifest_path, assets)

    def test_asset_path_cannot_escape_candidate_directory(self):
        with tempfile.TemporaryDirectory() as temporary:
            manifest_path, assets, manifest = valid_candidate(Path(temporary))
            manifest["artifacts"][0]["path"] = "../outside.zip"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "must stay inside"):
                validate_fixture_candidate(Path(temporary), manifest_path, assets)

    def test_staged_receipts_verify_assets_before_site_and_delivery_after(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            manifest_path, assets, manifest = valid_candidate(root)
            digest = validate_fixture_candidate(Path(temporary), manifest_path, assets)
            assets_receipt = {
                "record_status": "asset_publication_verified",
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
                },
            }
            assets_receipt_path = root / "assets-receipt.json"
            assets_receipt_path.write_text(json.dumps(assets_receipt), encoding="utf-8")
            self.assertEqual(validate_receipt(manifest_path, assets_receipt_path, stage="assets"), digest)

            receipt = {
                **assets_receipt,
                "record_status": "publication_verified",
                "asset_receipt_sha256": hashlib.sha256(assets_receipt_path.read_bytes()).hexdigest(),
                "asset_manifest_sha256": digest,
                "site_url": "https://netelegram.example.test",
                "site_deployment_id": "site-deploy-42",
                "site_version_id": "site-version-42",
                "site_evidence": ["https://netelegram.example.test/downloads/", "https://netelegram.example.test/appcast.xml"],
                "checks": {
                    **assets_receipt["checks"],
                    "site_download_links": "passed",
                    "update_feed": "passed",
                },
            }
            receipt_path = root / "delivery-receipt.json"
            receipt_path.write_text(json.dumps(receipt), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "requires the pre-Site asset receipt"):
                validate_receipt(manifest_path, receipt_path, stage="delivery")
            self.assertEqual(
                validate_receipt(
                    manifest_path,
                    receipt_path,
                    stage="delivery",
                    asset_receipt_path=assets_receipt_path,
                ),
                digest,
            )

            receipt["asset_receipt_sha256"] = "0" * 64
            receipt_path.write_text(json.dumps(receipt), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "does not reference the supplied asset receipt"):
                validate_receipt(
                    manifest_path,
                    receipt_path,
                    stage="delivery",
                    asset_receipt_path=assets_receipt_path,
                )

            receipt["asset_receipt_sha256"] = hashlib.sha256(assets_receipt_path.read_bytes()).hexdigest()
            receipt["manifest_sha256"] = "0" * 64
            receipt_path.write_text(json.dumps(receipt), encoding="utf-8")
            with self.assertRaisesRegex(ValidationError, "does not match"):
                validate_receipt(
                    manifest_path,
                    receipt_path,
                    stage="delivery",
                    asset_receipt_path=assets_receipt_path,
                )


if __name__ == "__main__":
    unittest.main()
