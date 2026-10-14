#!/usr/bin/env python3
"""Fail-closed validation for NeTelegram candidate manifests and publish receipts."""

from __future__ import annotations

import argparse
from datetime import datetime
import hashlib
import json
import re
import sys
from pathlib import Path
from pathlib import PurePosixPath
from urllib.parse import urlparse
import zipfile

if __package__:
    from .generate_sbom import SBOMError, validate_release_archive
else:
    from generate_sbom import SBOMError, validate_release_archive


HEX_40 = re.compile(r"^[0-9a-f]{40}$")
HEX_64 = re.compile(r"^[0-9a-f]{64}$")
VERSION = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")
PLACEHOLDER = re.compile(r"(?:^|[<>])(?:TODO|TBD|CHANGEME|PLACEHOLDER|EXAMPLE)(?:$|[<>])", re.I)
REQUIRED_MANIFEST_FIELDS = (
    "release_id", "public_title", "version", "channel",
    "record_created_at", "tag", "source_commit", "tdlib_commit", "license_spdx",
    "release_url", "minimum_macos",
)
REQUIRED_ARTIFACT_FIELDS = (
    "kind", "filename", "path", "url", "sha256",
)
SIGNED_ARTIFACT_KINDS = {"app_zip", "dmg", "sparkle_update_zip"}
REQUIRED_ARTIFACT_KINDS = {"app_zip", "dmg", "sbom", "notice"}
ALLOWED_ARTIFACT_KINDS = REQUIRED_ARTIFACT_KINDS | {"sparkle_update_zip"}
FORBIDDEN_SECRET_KEYS = {
    "api_hash", "api_secret", "access_token", "bearer_token", "private_key",
    "signing_key", "sparkle_private_key", "notary_password", "password",
}


class ValidationError(Exception):
    pass


def read_object(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValidationError(f"Cannot read JSON object {path}: {error}") from error
    if not isinstance(value, dict):
        raise ValidationError(f"Expected a JSON object in {path}")
    return value


def reject_secrets(value: object, trail: str = "manifest") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            if str(key).lower() in FORBIDDEN_SECRET_KEYS:
                raise ValidationError(f"Secret-bearing field is forbidden: {trail}.{key}")
            reject_secrets(child, f"{trail}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            reject_secrets(child, f"{trail}[{index}]")


def require_text(obj: dict, field: str) -> str:
    value = obj.get(field)
    if not isinstance(value, str) or not value.strip():
        raise ValidationError(f"{field} must be a non-empty string")
    if PLACEHOLDER.search(value.strip()):
        raise ValidationError(f"{field} contains a placeholder")
    return value.strip()


def require_https(value: str, field: str) -> None:
    parsed = urlparse(value)
    if parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.password:
        raise ValidationError(f"{field} must be an HTTPS URL without embedded credentials")


def require_timestamp(value: str, field: str) -> None:
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise ValidationError(f"{field} must be an ISO-8601 timestamp") from error
    if parsed.tzinfo is None:
        raise ValidationError(f"{field} must include a timezone")


def validate_evidence_list(value: object, field: str) -> None:
    if not isinstance(value, list) or not value:
        raise ValidationError(f"{field} must contain at least one evidence reference")
    if any(not isinstance(item, str) or not item.strip() or PLACEHOLDER.search(item) for item in value):
        raise ValidationError(f"{field} contains an empty or placeholder evidence reference")


def validate_candidate(manifest_path: Path, assets_dir: Path) -> str:
    manifest = read_object(manifest_path)
    reject_secrets(manifest)
    if manifest.get("record_status") != "release_candidate":
        raise ValidationError("record_status must be release_candidate; templates are not publishable")
    if "published_at" in manifest:
        raise ValidationError("published_at belongs in the separate append-only verification receipt")
    if manifest.get("product") != "NeTelegram" or manifest.get("repository") != "AffPapa/NeTelegram":
        raise ValidationError("product and repository must identify the NeTelegram project")
    if manifest.get("schema_version") != 1:
        raise ValidationError("unsupported manifest schema_version")
    contract = manifest.get("artifact_contract")
    if not isinstance(contract, dict) or contract.get("private_key_included") is not False:
        raise ValidationError("artifact_contract.private_key_included must remain false")
    for field in REQUIRED_MANIFEST_FIELDS:
        require_text(manifest, field)
    for field in ("changes", "known_limitations"):
        value = manifest.get(field)
        if not isinstance(value, list) or any(not isinstance(item, str) or not item.strip() or PLACEHOLDER.search(item) for item in value):
            raise ValidationError(f"{field} must be a list of non-empty factual strings")
    if not manifest["changes"]:
        raise ValidationError("changes must contain at least one entry")
    if not VERSION.fullmatch(manifest["version"]):
        raise ValidationError("version must be a released SemVer value without a prerelease suffix")
    try:
        build_number = int(manifest["build_number"])
    except (TypeError, ValueError) as error:
        raise ValidationError("build_number must be a positive integer") from error
    if build_number <= 0:
        raise ValidationError("build_number must be a positive integer")
    if manifest["channel"] not in {"stable", "alpha", "beta", "rc"}:
        raise ValidationError("channel must be stable, alpha, beta, or rc")
    if not HEX_40.fullmatch(manifest["source_commit"]):
        raise ValidationError("source_commit must be a full 40-character Git SHA")
    if not HEX_40.fullmatch(manifest["tdlib_commit"]):
        raise ValidationError("tdlib_commit must be a full pinned Git SHA")
    require_timestamp(manifest["record_created_at"], "record_created_at")
    require_https(manifest["release_url"], "release_url")
    if not re.fullmatch(r"\d+\.\d+(?:\.\d+)?", manifest["minimum_macos"]):
        raise ValidationError("minimum_macos must be a numeric macOS version")
    architectures = manifest["architectures"]
    if not isinstance(architectures, list) or "arm64" not in architectures or len(set(architectures)) != len(architectures):
        raise ValidationError("architectures must be a unique list containing arm64")

    coverage = manifest["account_coverage"]
    if not isinstance(coverage, dict):
        raise ValidationError("account_coverage must be an object")
    authorized = coverage.get("real_authorized_accounts")
    if not isinstance(authorized, int) or isinstance(authorized, bool):
        raise ValidationError("account_coverage.real_authorized_accounts must be an integer")
    minimum_accounts = 20 if manifest["channel"] == "stable" else 1
    if authorized < minimum_accounts:
        raise ValidationError(
            f"{manifest['channel']} requires evidence from at least {minimum_accounts} real authorized account(s)"
        )
    matrix = coverage.get("performance_account_counts")
    if not isinstance(matrix, list) or any(not isinstance(n, int) or isinstance(n, bool) for n in matrix):
        raise ValidationError("account_coverage.performance_account_counts must be an integer list")
    if len(matrix) != len(set(matrix)) or any(n < 1 or n > authorized for n in matrix):
        raise ValidationError("performance_account_counts must be unique and within real account coverage")
    if manifest["channel"] == "stable":
        if not {1, 5, 10, 20}.issubset(set(matrix)):
            raise ValidationError("stable account_coverage.performance_account_counts must include 1, 5, 10, and 20")
        performance = coverage.get("performance_matrix")
        if not isinstance(performance, list):
            raise ValidationError("stable releases require a performance_matrix")
        measured: dict[int, dict] = {}
        metrics = (
            "physical_memory_mb_p50", "physical_memory_mb_p95",
            "idle_cpu_percent_p50", "idle_cpu_percent_p95",
            "wakeups_per_hour_p50", "wakeups_per_hour_p95",
            "network_bytes_per_hour_p50", "network_bytes_per_hour_p95",
            "decode_latency_ms_p50", "decode_latency_ms_p95",
        )
        for index, sample in enumerate(performance):
            if not isinstance(sample, dict):
                raise ValidationError(f"performance_matrix[{index}] must be an object")
            count = sample.get("connected_accounts")
            if not isinstance(count, int) or isinstance(count, bool) or count not in {1, 5, 10, 20} or count in measured:
                raise ValidationError(f"performance_matrix[{index}] has an invalid or duplicate connected_accounts")
            for field in ("host_id", "corpus_id", "toolchain", "architecture", "evidence_ref"):
                require_text(sample, field)
            require_https(sample["evidence_ref"], f"performance_matrix[{index}].evidence_ref")
            duration = sample.get("duration_seconds")
            if not isinstance(duration, (int, float)) or isinstance(duration, bool) or duration <= 0:
                raise ValidationError(f"performance_matrix[{index}].duration_seconds must be positive")
            for field in metrics:
                value = sample.get(field)
                if not isinstance(value, (int, float)) or isinstance(value, bool) or value < 0:
                    raise ValidationError(f"performance_matrix[{index}].{field} must be a non-negative number")
            measured[count] = sample
        if set(measured) != {1, 5, 10, 20}:
            raise ValidationError("stable performance_matrix must measure 1, 5, 10, and 20 connected accounts")
        if len({(item["host_id"], item["corpus_id"], item["toolchain"], item["architecture"]) for item in measured.values()}) != 1:
            raise ValidationError("stable performance measurements must use one Mac, corpus, toolchain, and architecture")

    compatibility = manifest.get("telegram_compatibility")
    compatibility_gates = ("terms_2_3_title", "sponsored_media_3_3", "basic_functionality_1_3_1_4")
    if not isinstance(compatibility, dict) or any(compatibility.get(field) not in {"passed", "open", "deferred"} for field in compatibility_gates):
        raise ValidationError("telegram_compatibility must record the three known compatibility gates")
    if manifest["channel"] == "stable" and any(compatibility.get(field) != "passed" for field in compatibility_gates):
        raise ValidationError("stable release requires all known Telegram API compatibility gates to pass")

    evidence = manifest["test_evidence"]
    if not isinstance(evidence, list) or not evidence:
        raise ValidationError("test_evidence must be a non-empty list")
    real_accounts_tested = 0
    for index, item in enumerate(evidence):
        if not isinstance(item, dict):
            raise ValidationError(f"test_evidence[{index}] must be an object")
        if item.get("result") != "passed" or item.get("source_commit") != manifest["source_commit"]:
            raise ValidationError(f"test_evidence[{index}] must pass on the exact release source_commit")
        if item.get("kind") == "real_account_smoke":
            tested = item.get("accounts_tested")
            if not isinstance(tested, int) or isinstance(tested, bool) or tested <= 0:
                raise ValidationError(f"test_evidence[{index}] real-account evidence requires accounts_tested > 0")
            real_accounts_tested = max(real_accounts_tested, tested)
        for field in ("scope", "environment", "evidence_ref"):
            require_text(item, field)
        require_https(item["evidence_ref"], f"test_evidence[{index}].evidence_ref")
    if real_accounts_tested < authorized:
        raise ValidationError("real-account evidence must cover account_coverage.real_authorized_accounts")

    artifacts = manifest["artifacts"]
    if not isinstance(artifacts, list) or not artifacts:
        raise ValidationError("artifacts must be a non-empty list")
    filenames: set[str] = set()
    kinds: set[str] = set()
    expected_asset_prefix = f"https://github.com/{manifest['repository']}/releases/download/{manifest['tag']}/"
    for index, artifact in enumerate(artifacts):
        field = f"artifacts[{index}]"
        if not isinstance(artifact, dict):
            raise ValidationError(f"{field} must be an object")
        for name in REQUIRED_ARTIFACT_FIELDS:
            require_text(artifact, name)
        filename = artifact["filename"]
        if Path(filename).name != filename or filename in {".", ".."} or filename in filenames:
            raise ValidationError(f"{field}.filename must be a unique basename")
        filenames.add(filename)
        kind = artifact["kind"]
        if kind not in ALLOWED_ARTIFACT_KINDS:
            raise ValidationError(f"{field}.kind is unsupported: {kind}")
        if kind in kinds:
            raise ValidationError(f"{field}.kind must appear only once: {kind}")
        kinds.add(kind)
        require_https(artifact["url"], f"{field}.url")
        if artifact["url"] != expected_asset_prefix + filename:
            raise ValidationError(f"{field}.url must identify this exact asset in the matching GitHub release")
        validate_evidence_list(artifact["verification_evidence"], f"{field}.verification_evidence")
        if kind in SIGNED_ARTIFACT_KINDS:
            for name in ("signing_status", "notarization_status", "gatekeeper_status"):
                require_text(artifact, name)
            if artifact["signing_status"] != "passed":
                raise ValidationError(f"{field}.signing_status must be passed")
            if artifact["notarization_status"] != "accepted_stapled":
                raise ValidationError(f"{field}.notarization_status must be accepted_stapled")
            if artifact["gatekeeper_status"] != "passed":
                raise ValidationError(f"{field}.gatekeeper_status must be passed")
        if not isinstance(artifact["bytes"], int) or isinstance(artifact["bytes"], bool) or artifact["bytes"] <= 0:
            raise ValidationError(f"{field}.bytes must be a positive integer")
        if not HEX_64.fullmatch(artifact["sha256"]):
            raise ValidationError(f"{field}.sha256 must be a lowercase SHA-256 digest")
        relative = Path(artifact["path"])
        if relative.is_absolute() or ".." in relative.parts:
            raise ValidationError(f"{field}.path must stay inside the candidate directory")
        candidate_path = (assets_dir / relative).resolve()
        lexical_path = assets_dir / relative
        current = assets_dir
        has_symlink_component = False
        for part in relative.parts:
            current = current / part
            has_symlink_component = has_symlink_component or current.is_symlink()
        if has_symlink_component or not candidate_path.is_relative_to(assets_dir.resolve()) or not candidate_path.is_file():
            raise ValidationError(f"{field}.path must resolve to a regular file inside assets_dir")
        data = candidate_path.read_bytes()
        if len(data) != artifact["bytes"] or hashlib.sha256(data).hexdigest() != artifact["sha256"]:
            raise ValidationError(f"{field} bytes or sha256 do not match the frozen local asset")
        if kind == "sbom":
            try:
                sbom = json.loads(data.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError) as error:
                raise ValidationError(f"{field} must be UTF-8 CycloneDX JSON: {error}") from error
            if sbom.get("bomFormat") != "CycloneDX" or sbom.get("specVersion") != "1.6":
                raise ValidationError(f"{field} must be a CycloneDX 1.6 BOM")
            metadata_component = sbom.get("metadata", {}).get("component", {})
            if metadata_component.get("name") != "NeTelegram" or metadata_component.get("version") != manifest["version"]:
                raise ValidationError(f"{field} metadata component identity does not match the release")
            source_properties = {
                prop.get("name"): prop.get("value")
                for prop in metadata_component.get("properties", [])
                if isinstance(prop, dict)
            }
            if source_properties.get("neTelegram:source:commit") != manifest["source_commit"]:
                raise ValidationError(f"{field} source commit does not match the release")
            if source_properties.get("neTelegram:sbom:release-binary-audit") != "passed":
                raise ValidationError(f"{field} is not reconciled with the signed notarized release bundle")
        elif kind == "notice":
            try:
                notice_text = data.decode("utf-8")
            except UnicodeDecodeError as error:
                raise ValidationError(f"{field} must be UTF-8 third-party notice text") from error
            if not all(required in notice_text for required in ("TDLib", "OpenSSL", "gperf", "MIT License")):
                raise ValidationError(f"{field} omits required project or third-party license notices")
        if artifact["kind"] == "sparkle_update_zip":
            sparkle_fields = (
                "sparkle_ed_signature", "sparkle_version", "sparkle_short_version",
                "update_channel", "minimum_system_version",
            )
            for name in sparkle_fields:
                require_text(artifact, name)
            if artifact["sparkle_short_version"] != manifest["version"]:
                raise ValidationError(f"{field}.sparkle_short_version must match manifest version")
            if artifact["update_channel"] != manifest["channel"]:
                raise ValidationError(f"{field}.update_channel must match manifest channel")
            if artifact["minimum_system_version"] != manifest["minimum_macos"]:
                raise ValidationError(f"{field}.minimum_system_version must match manifest minimum_macos")
    if not REQUIRED_ARTIFACT_KINDS.issubset(kinds):
        missing = sorted(REQUIRED_ARTIFACT_KINDS - kinds)
        raise ValidationError(f"artifacts must include app_zip, dmg, sbom, and notice; missing {', '.join(missing)}")

    sbom_item = next(item for item in artifacts if item["kind"] == "sbom")
    sbom = read_object(assets_dir / sbom_item["path"])
    metadata_component = sbom.get("metadata", {}).get("component", {})
    executable_hashes = metadata_component.get("hashes", [])
    tdlib = next((item for item in sbom.get("components", []) if item.get("name") == "TDLib"), None)
    tdlib_hashes = tdlib.get("hashes", []) if isinstance(tdlib, dict) else []
    executable_digest = next((item.get("content") for item in executable_hashes if item.get("alg") == "SHA-256"), None)
    tdlib_digest = next((item.get("content") for item in tdlib_hashes if item.get("alg") == "SHA-256"), None)
    if not executable_digest or not tdlib_digest:
        raise ValidationError("SBOM must include SHA-256 hashes for the app executable and bundled TDLib")
    app_zip = next(assets_dir / item["path"] for item in artifacts if item["kind"] == "app_zip")
    sbom_properties = {
        prop.get("name"): prop.get("value")
        for prop in metadata_component.get("properties", [])
        if isinstance(prop, dict)
    }
    if sbom_properties.get("neTelegram:sbom:audit-input") != "final-app-zip":
        raise ValidationError("release SBOM must audit the final app ZIP, not a pre-ZIP bundle")
    if not re.fullmatch(r"[A-Z0-9]{10}", sbom_properties.get("neTelegram:signing:team-id", "")):
        raise ValidationError("release SBOM must record the exact audited Developer Team ID")
    try:
        with zipfile.ZipFile(app_zip) as archive:
            try:
                entries = validate_release_archive(archive)
            except SBOMError as error:
                raise ValidationError(f"app_zip archive structure is invalid: {error}") from error
            names = [item.filename for item in entries]
            for name in names:
                path = PurePosixPath(name)
                if "\\" in name or path.is_absolute() or ".." in path.parts:
                    raise ValidationError("app_zip contains an absolute or parent-traversal path")
            executable = next((name for name in names if name.endswith(".app/Contents/MacOS/NeTelegram")), None)
            tdlib_binary = next((name for name in names if name.endswith(".app/Contents/Frameworks/libtdjson.dylib")), None)
            if not executable or not tdlib_binary:
                raise ValidationError("app_zip must contain NeTelegram.app executable and libtdjson.dylib")
            if hashlib.sha256(archive.read(executable)).hexdigest() != executable_digest:
                raise ValidationError("SBOM app executable hash does not match app_zip bytes")
            if hashlib.sha256(archive.read(tdlib_binary)).hexdigest() != tdlib_digest:
                raise ValidationError("SBOM TDLib hash does not match app_zip bytes")
            if sbom_properties.get("neTelegram:sbom:audited-app-zip-sha256") != hashlib.sha256(app_zip.read_bytes()).hexdigest():
                raise ValidationError("SBOM final app ZIP hash does not match the candidate app_zip bytes")
    except (OSError, zipfile.BadZipFile, StopIteration, RuntimeError) as error:
        raise ValidationError(f"app_zip could not be reconciled with SBOM binary hashes: {error}") from error

    return hashlib.sha256(manifest_path.read_bytes()).hexdigest()


def validate_receipt(manifest_path: Path, receipt_path: Path) -> str:
    manifest = read_object(manifest_path)
    receipt = read_object(receipt_path)
    reject_secrets(receipt, "receipt")
    if receipt.get("record_status") != "publication_verified":
        raise ValidationError("receipt record_status must be publication_verified")
    manifest_sha = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
    if receipt.get("manifest_sha256") != manifest_sha:
        raise ValidationError("receipt manifest_sha256 does not match the immutable candidate manifest")
    if receipt.get("source_commit") != manifest.get("source_commit"):
        raise ValidationError("receipt source_commit does not match candidate manifest")
    require_timestamp(require_text(receipt, "published_at"), "published_at")
    require_timestamp(require_text(receipt, "verified_at"), "verified_at")
    published = receipt.get("assets")
    expected = manifest.get("artifacts")
    if not isinstance(published, list) or not isinstance(expected, list):
        raise ValidationError("receipt assets and candidate artifacts must be lists")
    by_name = {item.get("filename"): item for item in expected if isinstance(item, dict)}
    if len(published) != len(by_name) or len(published) != len(expected):
        raise ValidationError("receipt must cover every published candidate asset exactly once")
    seen: set[str] = set()
    for index, asset in enumerate(published):
        if not isinstance(asset, dict):
            raise ValidationError(f"receipt assets[{index}] must be an object")
        name = require_text(asset, "filename")
        if name in seen or name not in by_name:
            raise ValidationError(f"receipt assets[{index}] is duplicate or absent from the candidate")
        seen.add(name)
        artifact = by_name[name]
        if asset.get("sha256") != artifact.get("sha256") or asset.get("bytes") != artifact.get("bytes"):
            raise ValidationError(f"receipt asset {name} differs from the immutable candidate bytes")
        url = require_text(asset, "url")
        require_https(url, f"receipt asset {name}.url")
        if asset.get("public_http_status") != 200 or asset.get("download_sha256") != artifact.get("sha256"):
            raise ValidationError(f"receipt asset {name} was not publicly downloaded and hash-verified")
    checks = receipt.get("checks")
    if not isinstance(checks, dict) or any(checks.get(name) != "passed" for name in (
        "gatekeeper_quarantine_smoke", "native_install_reopen", "site_download_links", "update_feed",
    )):
        raise ValidationError("receipt must confirm Gatekeeper, native install/reopen, Site links, and update-feed checks")
    return manifest_sha


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    candidate = sub.add_parser("candidate", help="validate frozen candidate metadata and local asset bytes")
    candidate.add_argument("manifest", type=Path)
    candidate.add_argument("--assets-dir", required=True, type=Path)
    receipt = sub.add_parser("receipt", help="validate post-publication byte receipt against the frozen manifest")
    receipt.add_argument("manifest", type=Path)
    receipt.add_argument("receipt", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "candidate":
            digest = validate_candidate(args.manifest, args.assets_dir)
            print(f"PASS candidate manifest_sha256={digest}")
        else:
            digest = validate_receipt(args.manifest, args.receipt)
            print(f"PASS publication receipt manifest_sha256={digest}")
        return 0
    except ValidationError as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
