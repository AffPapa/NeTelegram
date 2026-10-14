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
import plistlib
import re
import subprocess
import uuid
from pathlib import Path


SPEC_VERSION = "1.6"
NAMESPACE = uuid.UUID("b98bb895-1e62-4d50-a8c1-9abfa2e4e5d2")
SHA40 = re.compile(r"^[0-9a-f]{40}$")
VERSION = re.compile(r"^[0-9A-Za-z][0-9A-Za-z.+-]*$")


class SBOMError(ValueError):
    pass


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


def audit_release_bundle(bundle: Path, version: str, source_commit: str) -> dict:
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
    if not executable.is_file() or not tdlib.is_file():
        raise SBOMError("app bundle is missing its executable or pinned libtdjson.dylib")

    def run(*command: str) -> str:
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        if result.returncode:
            details = (result.stderr or result.stdout).strip()
            raise SBOMError(f"release bundle check failed ({Path(command[0]).name}): {details[:300]}")
        return result.stdout + result.stderr

    signature = run("/usr/bin/codesign", "-dv", "--verbose=4", str(bundle))
    if "Authority=Developer ID Application:" not in signature or "TeamIdentifier=" not in signature:
        raise SBOMError("app bundle is not signed with a Developer ID Application identity")
    run("/usr/bin/codesign", "--verify", "--deep", "--strict", str(bundle))
    run("/usr/bin/xcrun", "stapler", "validate", str(bundle))
    run("/usr/sbin/spctl", "--assess", "--type", "execute", "--verbose=2", str(bundle))
    architectures: dict[str, list[str]] = {}
    for name, path in (("NeTelegram", executable), ("TDLib", tdlib)):
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
        "executable_sha256": digest(executable),
        "tdlib_sha256": digest(tdlib),
        "architectures": architectures,
    }


def build_bom(root: Path, version: str, source_commit: str, timestamp: str | None = None,
              app_bundle: Path | None = None) -> dict:
    if not VERSION.fullmatch(version):
        raise SBOMError("version must be a concrete version string")
    if not SHA40.fullmatch(source_commit):
        raise SBOMError("source_commit must be a full lowercase 40-character Git SHA")

    tdlib = json.loads((root / "TDLIB.lock.json").read_text(encoding="utf-8"))
    country = json.loads((root / "COUNTRY-DATA.lock.json").read_text(encoding="utf-8"))
    openssl = tdlib["build_dependencies"]["openssl"]
    gperf = tdlib["build_dependencies"]["gperf"]

    binary_audit = audit_release_bundle(app_bundle, version, source_commit) if app_bundle else None
    components = [
        component(
            "TDLib", tdlib["version"], tdlib["license"]["spdx"], scope="required",
            bom_ref="pkg:github/tdlib/td@" + tdlib["version"],
            purl="pkg:github/tdlib/td@" + tdlib["version"],
            properties={"neTelegram:source:commit": tdlib["ref"],
                        "neTelegram:distribution": "bundled-dynamic-library"},
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
                {"name": "neTelegram:sbom:completeness", "value": "source-pins-only; reconcile with final signed app bundle"},
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
        tdlib_component = next(item for item in components if item["name"] == "TDLib")
        tdlib_component["hashes"] = [{"alg": "SHA-256", "content": binary_audit["tdlib_sha256"]}]
        tdlib_component["properties"].append({
            "name": "neTelegram:binary:architectures",
            "value": ",".join(binary_audit["architectures"]["TDLib"]),
        })
        bom["metadata"]["properties"].append({
            "name": "neTelegram:sbom:release-binary-audit-evidence",
            "value": "Developer ID signature verified; notarization ticket stapled; Gatekeeper assessment accepted",
        })
    return bom


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--timestamp", help="ISO-8601 timestamp; defaults to current UTC")
    parser.add_argument("--app-bundle", type=Path, help="Notarized Developer ID .app to reconcile for release")
    args = parser.parse_args()
    try:
        bom = build_bom(Path(__file__).resolve().parent.parent, args.version, args.source_commit, args.timestamp, args.app_bundle)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(bom, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    except (OSError, KeyError, json.JSONDecodeError, SBOMError) as error:
        parser.error(str(error))
    print(f"Wrote CycloneDX {SPEC_VERSION} source inventory: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
