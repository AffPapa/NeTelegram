#!/usr/bin/env python3
"""Build a deterministic release notice from project and pinned license texts."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


class NoticeError(ValueError):
    pass


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def build_notice(root: Path) -> str:
    try:
        tdlib = json.loads((root / "TDLIB.lock.json").read_text(encoding="utf-8"))
        country = json.loads((root / "COUNTRY-DATA.lock.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise NoticeError(f"cannot read dependency lock: {error}") from error

    pinned = {
        "ThirdPartyLicenses/TDLib-BSL-1.0.txt": tdlib["license"]["sha256"],
        "ThirdPartyLicenses/OpenSSL-Apache-2.0.txt": tdlib["build_dependencies"]["openssl"]["license_sha256"],
        country["license_path"]: country["license_sha256"],
    }
    sections: list[tuple[str, bytes]] = []
    for relative, expected_hash in sorted(pinned.items()):
        path = root / relative
        try:
            data = path.read_bytes()
        except OSError as error:
            raise NoticeError(f"missing pinned license text {relative}: {error}") from error
        if sha256(data) != expected_hash:
            raise NoticeError(f"license text hash does not match lock: {relative}")
        sections.append((relative, data))

    try:
        mit = (root / "LICENSE").read_bytes()
        notice = (root / "NOTICE").read_bytes()
        sqlcipher = (root / "ThirdPartyLicenses/SQLCipher-BSD.txt").read_bytes()
    except OSError as error:
        raise NoticeError(f"missing project or embedded third-party notice: {error}") from error

    all_sections = [("LICENSE", mit), ("NOTICE", notice), *sections,
                    ("ThirdPartyLicenses/SQLCipher-BSD.txt", sqlcipher)]
    output = ["NeTelegram — Third-Party Notices", "", "This file reproduces the project license, third-party notices, and the license texts for dependencies recorded in the source locks.", ""]
    seen: set[str] = set()
    for name, data in all_sections:
        if name in seen:
            continue
        seen.add(name)
        try:
            text = data.decode("utf-8").strip()
        except UnicodeDecodeError as error:
            raise NoticeError(f"license text is not UTF-8: {name}") from error
        output.extend(["=" * 78, name, "=" * 78, text, ""])
    return "\n".join(output).rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        text = build_notice(Path(__file__).resolve().parent.parent)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text, encoding="utf-8", newline="\n")
    except (OSError, KeyError, NoticeError) as error:
        parser.error(str(error))
    print(f"Wrote pinned third-party notices: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
