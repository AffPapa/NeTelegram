#!/usr/bin/env python3
"""Generate a CycloneDX source dependency inventory from the committed pins.

This is deliberately not presented as a binary-complete release SBOM. Use the
output as a release input, then reconcile it against the final signed bundle.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
import plistlib
import posixpath
import re
import shutil
import subprocess
import sys
import tempfile
import uuid
import zipfile
from pathlib import Path, PurePosixPath


SPEC_VERSION = "1.6"
NAMESPACE = uuid.UUID("b98bb895-1e62-4d50-a8c1-9abfa2e4e5d2")
SHA40 = re.compile(r"^[0-9a-f]{40}$")
VERSION = re.compile(r"^[0-9A-Za-z][0-9A-Za-z.+-]*$")


class SBOMError(ValueError):
    pass


def validate_release_archive(archive: zipfile.ZipFile) -> list[zipfile.ZipInfo]:
    """Validate the archive namespace before reading or extracting any member."""
    entries = archive.infolist()
    if not entries or len(entries) > 100_000:
        raise SBOMError("app ZIP has an invalid entry count")
    names = [item.filename for item in entries]
    if len(names) != len(set(names)):
        raise SBOMError("app ZIP contains duplicate paths")
    total_size = 0
    for item in entries:
        name = item.filename
        path = Path(name)
        path_parts = name.rstrip("/").split("/")
        mode = (item.external_attr >> 16) & 0xFFFF
        kind = mode & 0o170000
        if ".." in path_parts or path.is_absolute() or "\\" in name:
            raise SBOMError("app ZIP contains an unsafe absolute or parent-traversal path")
        if (not name or any(part in ("", ".") for part in path_parts)
                or (name.endswith("/") and not item.is_dir())
                or item.flag_bits & 0x1 or (kind and kind not in (0o100000, 0o040000, 0o120000))):
            raise SBOMError("app ZIP contains an unsafe, encrypted, or special entry")
        if kind == 0o120000:
            if item.create_system != 3:
                raise SBOMError("app ZIP contains a non-Unix symbolic link")
            try:
                target = archive.read(item).decode("utf-8")
            except (UnicodeDecodeError, RuntimeError) as error:
                raise SBOMError("app ZIP contains an invalid symbolic link") from error
            if not target or "\\" in target or "\x00" in target or PurePosixPath(target).is_absolute():
                raise SBOMError("app ZIP contains an unsafe symbolic link target")
            resolved = posixpath.normpath(posixpath.join(posixpath.dirname(name), target))
            if not resolved.startswith("NeTelegram.app/"):
                raise SBOMError("app ZIP contains an unsafe symbolic link that escapes the application bundle")
        total_size += item.file_size
        if total_size > 8 * 1024 * 1024 * 1024:
            raise SBOMError("app ZIP uncompressed size exceeds the 8 GiB audit limit")
        if item.file_size > 0 and item.compress_size == 0:
            raise SBOMError("app ZIP contains an invalid compressed entry")
    normalized_names = {name.rstrip("/") for name in names}
    for name in tuple(normalized_names):
        parts = PurePosixPath(name).parts
        normalized_names.update("/".join(parts[:index]) for index in range(1, len(parts)))
    symlinks = {
        item.filename.rstrip("/"): posixpath.normpath(posixpath.join(
            posixpath.dirname(item.filename), archive.read(item).decode("utf-8")
        ))
        for item in entries if (((item.external_attr >> 16) & 0o170000) == 0o120000)
    }
    for name in names:
        parts = PurePosixPath(name.rstrip("/")).parts
        if any("/".join(parts[:index]) in symlinks for index in range(1, len(parts))):
            raise SBOMError("app ZIP contains a member nested through a symbolic link")
    def resolve_link_path(path: str, visited: frozenset[str] = frozenset()) -> str:
        parts = PurePosixPath(path).parts
        for index in range(1, len(parts) + 1):
            prefix = "/".join(parts[:index])
            if prefix not in symlinks:
                continue
            if prefix in visited:
                raise SBOMError("app ZIP contains a symbolic link cycle")
            replacement = symlinks[prefix]
            suffix = "/".join(parts[index:])
            next_path = posixpath.normpath(posixpath.join(replacement, suffix)) if suffix else replacement
            if not next_path.startswith("NeTelegram.app/"):
                raise SBOMError("app ZIP symbolic link chain escapes the application bundle")
            return resolve_link_path(next_path, visited | {prefix})
        return path

    for link in symlinks:
        resolved = resolve_link_path(link)
        if resolved not in normalized_names:
            raise SBOMError("app ZIP contains a broken symbolic link")
    roots = {PurePosixPath(name).parts[0] for name in names if PurePosixPath(name).parts}
    if roots != {"NeTelegram.app"}:
        raise SBOMError("app ZIP must contain exactly one NeTelegram.app root")
    return entries


def component(name: str, version: str, license_id: str, *, scope: str,
              bom_ref: str, purl: str | None = None, properties: dict[str, str] | None = None) -> dict:
    result = {
        "type": "library",
        "bom-ref": bom_ref,
        "name": name,
        "version": version,
        "scope": scope,
        "licenses": [{"license": {"id": license_id}}],
    }
    if purl:
        result["purl"] = purl
    if properties:
        result["properties"] = [
            {"name": key, "value": value} for key, value in sorted(properties.items())
        ]
    return result


def audit_release_bundle(bundle: Path, version: str, source_commit: str,
                         expected_team_id: str | None = None) -> dict:
    """Return binary hashes only after Developer ID, stapling, and Gatekeeper checks."""
    if not bundle.is_dir() or bundle.suffix != ".app":
        raise SBOMError("--app-bundle must be an existing .app directory")
    try:
        info = plistlib.loads((bundle / "Contents/Info.plist").read_bytes())
    except (OSError, plistlib.InvalidFileException) as error:
        raise SBOMError(f"cannot read app bundle Info.plist: {error}") from error
    if info.get("CFBundleShortVersionString") != version:
        raise SBOMError("app bundle version does not match --version")
    if "NeTelegramSourceCommit" in info:
        embedded_commit = info["NeTelegramSourceCommit"]
    else:
        embedded_commit = info.get("NeTelegramDevelopmentCommit")
    if embedded_commit != source_commit:
        raise SBOMError("app bundle source commit does not match --source-commit")
    bundle_id = str(info.get("CFBundleIdentifier", ""))
    if "netelegram" not in bundle_id.lower() or bundle_id.endswith(".dev"):
        raise SBOMError("app bundle identifier is missing or development-only")
    executable_name = info.get("CFBundleExecutable")
    if not isinstance(executable_name, str) or not executable_name:
        raise SBOMError("app bundle has no CFBundleExecutable")
    executable = bundle / "Contents/MacOS" / executable_name
    tdlib = bundle / "Contents/Frameworks/libtdjson.dylib"
    sparkle_framework = bundle / "Contents/Frameworks/Sparkle.framework"
    sparkle = sparkle_framework / "Sparkle"
    if not executable.is_file() or not tdlib.is_file() or not sparkle.is_file():
        raise SBOMError("app bundle is missing its executable, TDLib, or Sparkle framework binary")

    def run(*command: str) -> str:
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        if result.returncode:
            details = (result.stderr or result.stdout).strip()
            raise SBOMError(f"release bundle check failed ({Path(command[0]).name}): {details[:300]}")
        return result.stdout + result.stderr

    signature = run("/usr/bin/codesign", "-dv", "--verbose=4", str(bundle))
    team_match = re.search(r"^TeamIdentifier=([^\r\n]+)$", signature, re.MULTILINE)
    if "Authority=Developer ID Application:" not in signature or not team_match:
        raise SBOMError("app bundle is not signed with a Developer ID Application identity")
    team_id = team_match.group(1)
    if expected_team_id and team_id != expected_team_id:
        raise SBOMError("app bundle TeamIdentifier does not match --expected-team-id")
    run("/usr/bin/codesign", "--verify", "--deep", "--strict", str(bundle))
    run("/usr/bin/codesign", "--verify", "--strict", str(sparkle_framework))
    run("/usr/bin/xcrun", "stapler", "validate", str(bundle))
    run("/usr/sbin/spctl", "--assess", "--type", "execute", "--verbose=2", str(bundle))
    architectures: dict[str, list[str]] = {}
    for name, path in (("NeTelegram", executable), ("TDLib", tdlib), ("Sparkle", sparkle)):
        output = run("/usr/bin/lipo", "-archs", str(path)).strip().split()
        if "arm64" not in output:
            raise SBOMError(f"{name} does not include the supported arm64 architecture")
        architectures[name] = output
    def digest(path: Path) -> str:
        value = hashlib.sha256()
        with path.open("rb") as source:
            for chunk in iter(lambda: source.read(1024 * 1024), b""):
                value.update(chunk)
        return value.hexdigest()
    return {
        "executable_name": executable_name,
        "bundle_identifier": bundle_id,
        "minimum_macos": str(info.get("LSMinimumSystemVersion", "")),
        "team_id": team_id,
        "executable_sha256": digest(executable),
        "tdlib_sha256": digest(tdlib),
        "sparkle_sha256": digest(sparkle),
        "architectures": architectures,
    }


def audit_release_zip(app_zip: Path, version: str, source_commit: str,
                      expected_team_id: str | None = None) -> dict:
    """Safely materialize and audit the exact final ZIP on macOS."""
    if sys.platform != "darwin":
        raise SBOMError("--app-zip final signature audit requires macOS")
    if app_zip.is_symlink() or not app_zip.is_file():
        raise SBOMError("--app-zip must be an existing finalized ZIP")
    if not expected_team_id:
        raise SBOMError("--expected-team-id is required for final app ZIP auditing")
    try:
        with app_zip.open("rb") as source, tempfile.TemporaryDirectory(prefix="netelegram-final-zip-audit-") as directory:
            snapshot_path = Path(directory) / "candidate.zip"
            initial_stat = os.fstat(source.fileno())
            digest = hashlib.sha256()
            with snapshot_path.open("xb") as snapshot:
                for chunk in iter(lambda: source.read(1024 * 1024), b""):
                    digest.update(chunk)
                    snapshot.write(chunk)
            final_stat = os.fstat(source.fileno())
            stable_fields = ("st_dev", "st_ino", "st_size", "st_mtime_ns", "st_ctime_ns")
            if any(getattr(initial_stat, key) != getattr(final_stat, key) for key in stable_fields):
                raise SBOMError("app ZIP changed while the audit snapshot was being created")
            with zipfile.ZipFile(snapshot_path) as archive:
                entries = validate_release_archive(archive)
                root = Path(directory) / "extracted"
                for item in entries:
                    relative = PurePosixPath(item.filename)
                    target = root.joinpath(*relative.parts)
                    if item.is_dir():
                        target.mkdir(parents=True, exist_ok=True)
                    elif (((item.external_attr >> 16) & 0o170000) == 0o120000):
                        target.parent.mkdir(parents=True, exist_ok=True)
                        os.symlink(archive.read(item).decode("utf-8"), target)
                    else:
                        target.parent.mkdir(parents=True, exist_ok=True)
                        with archive.open(item) as member, target.open("xb") as destination:
                            shutil.copyfileobj(member, destination, 1024 * 1024)
                        os.chmod(target, ((item.external_attr >> 16) & 0o777) or 0o644)
                audit = audit_release_bundle(root / "NeTelegram.app", version, source_commit, expected_team_id)
                # Candidate validation later requires the public asset bytes to equal this snapshot.
                audit["app_zip_sha256"] = digest.hexdigest()
    except SBOMError:
        raise
    except (OSError, zipfile.BadZipFile, RuntimeError) as error:
        raise SBOMError(f"final app ZIP could not be safely audited: {error}") from error
    return audit


def build_bom(root: Path, version: str, source_commit: str, timestamp: str | None = None,
              app_bundle: Path | None = None, app_zip: Path | None = None,
              expected_team_id: str | None = None) -> dict:
    if not VERSION.fullmatch(version):
        raise SBOMError("version must be a concrete version string")
    if not SHA40.fullmatch(source_commit):
        raise SBOMError("source_commit must be a full lowercase 40-character Git SHA")

    tdlib = json.loads((root / "TDLIB.lock.json").read_text(encoding="utf-8"))
    country = json.loads((root / "COUNTRY-DATA.lock.json").read_text(encoding="utf-8"))
    sparkle = json.loads((root / "SPARKLE.lock.json").read_text(encoding="utf-8"))
    openssl = tdlib["build_dependencies"]["openssl"]
    gperf = tdlib["build_dependencies"]["gperf"]

    if app_bundle and app_zip:
        raise SBOMError("use only one of --app-bundle or --app-zip")
    binary_audit = (audit_release_zip(app_zip, version, source_commit, expected_team_id) if app_zip
                    else audit_release_bundle(app_bundle, version, source_commit, expected_team_id) if app_bundle
                    else None)
    components = [
        component(
            "TDLib", tdlib["version"], tdlib["license"]["spdx"], scope="required",
            bom_ref="pkg:github/tdlib/td@" + tdlib["version"],
            purl="pkg:github/tdlib/td@" + tdlib["version"],
            properties={"neTelegram:source:commit": tdlib["ref"],
                        "neTelegram:distribution": "bundled-dynamic-library"},
        ),
        component(
            "Sparkle", sparkle["version"], sparkle["license"]["spdx"], scope="required",
            bom_ref=f"pkg:github/sparkle-project/Sparkle@{sparkle['version']}",
            purl=f"pkg:github/sparkle-project/Sparkle@{sparkle['version']}",
            properties={"neTelegram:source:commit": sparkle["revision"],
                        "neTelegram:distribution": "bundled-framework"},
        ),
        component(
            "OpenSSL", openssl["version"], openssl["license"], scope="required",
            bom_ref="pkg:github/openssl/openssl@" + openssl["version"],
            purl="pkg:github/openssl/openssl@" + openssl["version"],
            properties={"neTelegram:source:commit": openssl["ref"],
                        "neTelegram:distribution": "statically-linked-into-TDLib"},
        ),
        component(
            "Google libphonenumber country calling-code data", country["version"],
            country["license"], scope="required",
            bom_ref="pkg:github/google/libphonenumber@" + country["version"],
            purl="pkg:github/google/libphonenumber@" + country["version"],
            properties={"neTelegram:source:commit": country["ref"],
                        "neTelegram:source:file": country["source_path"],
                        "neTelegram:source:file-sha256": country["source_sha256"],
                        "neTelegram:distribution": "generated-calling-code-catalog"},
        ),
        component(
            "SQLCipher SQLite contributions", tdlib["version"], "BSD-3-Clause",
            scope="required", bom_ref="pkg:generic/sqlcipher-contributions@" + tdlib["version"],
            properties={"neTelegram:source:commit": tdlib["ref"],
                        "neTelegram:distribution": "included-in-TDLib-SQLite-amalgamation"},
        ),
        component(
            "SQLite core", tdlib["version"], "blessing", scope="required",
            bom_ref="pkg:generic/sqlite-core@" + tdlib["version"],
            properties={"neTelegram:source:commit": tdlib["ref"],
                        "neTelegram:distribution": "included-in-TDLib-SQLite-amalgamation"},
        ),
        component(
            "zlib", "system", tdlib["build_dependencies"]["zlib"]["license"],
            scope="provided", bom_ref="pkg:generic/zlib@system",
            properties={"neTelegram:distribution": "macOS-system-library-not-bundled"},
        ),
        component(
            "gperf", gperf["version"], gperf["license"], scope="excluded",
            bom_ref="pkg:generic/gperf@" + gperf["version"],
            properties={"neTelegram:distribution": "build-only-tool-not-shipped",
                        "neTelegram:provider": gperf["provider"]},
        ),
    ]
    when = timestamp or datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    try:
        parsed = datetime.fromisoformat(when.replace("Z", "+00:00"))
    except ValueError as error:
        raise SBOMError("timestamp must be ISO-8601") from error
    if parsed.tzinfo is None:
        raise SBOMError("timestamp must include a timezone")
    serial = uuid.uuid5(NAMESPACE, f"NeTelegram:{version}:{source_commit}")
    bom = {
        "bomFormat": "CycloneDX",
        "specVersion": SPEC_VERSION,
        "serialNumber": f"urn:uuid:{serial}",
        "version": 1,
        "metadata": {
            "timestamp": when,
            "component": {
                "type": "application",
                "bom-ref": f"NeTelegram:{version}:{source_commit}",
                "name": "NeTelegram",
                "version": version,
                "licenses": [{"license": {"id": "MIT"}}],
                "properties": [
                    {"name": "neTelegram:source:commit", "value": source_commit},
                    {"name": "neTelegram:sbom:coverage", "value": "locked-source-dependency-inventory"},
                    {"name": "neTelegram:sbom:release-binary-audit", "value": "passed" if binary_audit else "required-before-release"},
                ],
            },
            "properties": [
                {"name": "neTelegram:sbom:completeness", "value": "source-pins-only; reconcile against the exact final signed app ZIP before release"},
            ],
        },
        "components": components,
    }
    if binary_audit:
        bom["metadata"]["component"]["hashes"] = [{"alg": "SHA-256", "content": binary_audit["executable_sha256"]}]
        bom["metadata"]["component"]["properties"].extend([
            {"name": "neTelegram:bundle:identifier", "value": binary_audit["bundle_identifier"]},
            {"name": "neTelegram:bundle:minimum-macos", "value": binary_audit["minimum_macos"]},
            {"name": "neTelegram:binary:architectures", "value": ",".join(binary_audit["architectures"]["NeTelegram"])},
        ])
        if binary_audit.get("app_zip_sha256"):
            bom["metadata"]["component"]["properties"].extend([
                {"name": "neTelegram:sbom:audit-input", "value": "final-app-zip"},
                {"name": "neTelegram:sbom:audited-app-zip-sha256", "value": binary_audit["app_zip_sha256"]},
                {"name": "neTelegram:signing:team-id", "value": binary_audit["team_id"]},
            ])
        tdlib_component = next(item for item in components if item["name"] == "TDLib")
        tdlib_component["hashes"] = [{"alg": "SHA-256", "content": binary_audit["tdlib_sha256"]}]
        tdlib_component["properties"].append({
            "name": "neTelegram:binary:architectures",
            "value": ",".join(binary_audit["architectures"]["TDLib"]),
        })
        sparkle_component = next(item for item in components if item["name"] == "Sparkle")
        sparkle_component["hashes"] = [{"alg": "SHA-256", "content": binary_audit["sparkle_sha256"]}]
        sparkle_component["properties"].append({
            "name": "neTelegram:binary:architectures",
            "value": ",".join(binary_audit["architectures"]["Sparkle"]),
        })
        bom["metadata"]["properties"].append({
            "name": "neTelegram:sbom:release-binary-audit-evidence",
            "value": "final app ZIP SHA-256 bound; Developer ID signature verified; notarization ticket stapled; Gatekeeper assessment accepted",
        })
    return bom


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--timestamp", help="ISO-8601 timestamp; defaults to current UTC")
    parser.add_argument("--app-bundle", type=Path, help="Notarized Developer ID .app to reconcile for release")
    parser.add_argument("--app-zip", type=Path, help="Final app ZIP; extract and verify its signature, stapling, and Gatekeeper status")
    parser.add_argument("--expected-team-id", help="Require this exact Apple Developer Team ID")
    args = parser.parse_args()
    try:
        bom = build_bom(Path(__file__).resolve().parent.parent, args.version, args.source_commit, args.timestamp,
                        args.app_bundle, args.app_zip, args.expected_team_id)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(bom, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    except (OSError, KeyError, json.JSONDecodeError, SBOMError) as error:
        parser.error(str(error))
    print(f"Wrote CycloneDX {SPEC_VERSION} source inventory: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
