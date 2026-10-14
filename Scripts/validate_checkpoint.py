#!/usr/bin/env python3
"""Fail fast when the resume checkpoint points at conflicting artifacts."""

from __future__ import annotations

import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]


def read_json(name: str) -> dict:
    with (ROOT / name).open(encoding="utf-8") as source:
        return json.load(source)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def validate() -> None:
    project = read_json("PROJECT-STATE.json")
    acceptance = read_json("ACCEPTANCE.json")
    evidence = acceptance["current_evidence"]
    app_sha = evidence["app_source_commit"]
    site = project["site"]
    deployment = project["latest_site_deployment"]
    site_checkpoint = project["current_site_checkpoint"]
    local_app = project["local_development_candidate"]
    bundle = evidence["local_dev_app"]
    checks = [
        (project["product"]["app_source_commit"] == app_sha,
         "PROJECT-STATE.product.app_source_commit != ACCEPTANCE.current_evidence.app_source_commit"),
        (acceptance["last_verification"]["app_source_commit"] == app_sha,
         "ACCEPTANCE.last_verification is stale; use current_evidence for the resume checkpoint"),
        (local_app["application_source_commit"] == app_sha == bundle["source_commit"],
         "canonical Dev.app source does not match the current app source evidence"),
        (local_app["source_fingerprint_sha256"] == bundle["source_fingerprint_sha256"],
         "canonical Dev.app fingerprint differs across checkpoint files"),
        (deployment["version"] == site_checkpoint["version"] == site["latest_version"],
         "Site version differs across current checkpoint fields"),
        (deployment["project_id"] == site_checkpoint["project_id"] == site["project_id"],
         "Site project ID differs across current checkpoint fields"),
        (deployment["deployment_id"] == site_checkpoint["deployment_id"] == site["deployment_id"],
         "Site deployment ID differs across current checkpoint fields"),
        (deployment["source_commit"] == site_checkpoint["source_commit"] == site["source_commit"],
         "Site source commit differs across current checkpoint fields"),
        (project["latest_site_source_commit"] == site["source_commit"],
         "latest_site_source_commit is stale"),
        (project["latest_acceptance_slice"]["source_commit"] == app_sha,
         "latest_acceptance_slice is stale"),
    ]
    errors = [message for condition, message in checks if not condition]
    if errors:
        raise ValueError("\n".join(errors))
if __name__ == "__main__":
    try:
        validate()
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        print(f"checkpoint validation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
    print("checkpoint validation passed: app source, canonical Dev.app, and Site pointers agree")
