#!/usr/bin/env python3
"""Generate the small region/calling-code table from pinned libphonenumber XML."""

from __future__ import annotations

import argparse
import xml.etree.ElementTree as ET
from pathlib import Path


def entries_from(path: Path) -> list[tuple[str, str]]:
    root = ET.parse(path).getroot()
    entries: list[tuple[str, str]] = []
    for territory in root.findall("./territories/territory"):
        region = territory.attrib.get("id", "")
        calling_code = territory.attrib.get("countryCode", "")
        if region == "001":
            continue
        if len(region) != 2 or not region.isascii() or not region.isalpha():
            continue
        if not calling_code or not calling_code.isascii() or not calling_code.isdigit():
            raise ValueError(f"Invalid calling code for {region!r}")
        entries.append((region, calling_code))
    if len({region for region, _ in entries}) != len(entries):
        raise ValueError("Duplicate region in pinned metadata")
    return sorted(entries)


def swift_source(entries: list[tuple[str, str]]) -> str:
    lines = [
        "import Foundation",
        "",
        "/// Local country/calling-code data for the first-run sign-in form.",
        "/// Generated from Google libphonenumber v9.0.41 (Apache-2.0); see COUNTRY-DATA.lock.json.",
        "public struct CountryCallingCodeEntry: Equatable, Hashable, Sendable {",
        "    public let regionCode: String",
        "    public let callingCode: String",
        "}",
        "",
        "public enum CountryCallingCodeCatalog {",
        "    public static let entries: [CountryCallingCodeEntry] = [",
    ]
    lines.extend(
        f'        .init(regionCode: "{region}", callingCode: "{code}"),'
        for region, code in entries
    )
    lines.extend(["    ]", "}"])
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("metadata_xml", type=Path)
    parser.add_argument("output_swift", type=Path)
    args = parser.parse_args()
    args.output_swift.write_text(swift_source(entries_from(args.metadata_xml)), encoding="utf-8")


if __name__ == "__main__":
    main()
