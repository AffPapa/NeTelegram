#!/usr/bin/env python3
"""Fail fast when the resume checkpoint points at conflicting artifacts."""

from __future__ import annotations

import json
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]


def read_json(name: str) -> dict:
    with (ROOT / name).open(encoding="utf-8") as source:
        return json.load(source)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def has_nested_key(value: object, key: str) -> bool:
    if isinstance(value, dict):
        return key in value or any(has_nested_key(child, key) for child in value.values())
    if isinstance(value, list):
        return any(has_nested_key(child, key) for child in value)
    return False


def validate_records(project: dict, acceptance: dict) -> None:
    evidence = acceptance["current_evidence"]
    app_sha = evidence["app_source_commit"]
    site = project["site"]
    deployment = project["latest_site_deployment"]
    site_checkpoint = project["current_site_checkpoint"]
    local_app = project["local_development_candidate"]
    bundle = evidence["local_dev_app"]
    hosted_ci = evidence["hosted_ci"]
    project_hosted_ci = project["source"]["latest_exact_commit_ci"]
    exact_ci_copies_match = all(
        project_hosted_ci.get(key) == hosted_ci.get(key)
        for key in ("run_id", "status", "url", "workflow_commit", "app_source_commit")
    )
    hosted_ci_matches_source = (
        hosted_ci["workflow_commit"] == app_sha
        and hosted_ci["app_source_commit"] == app_sha
    )
    hosted_ci_is_recorded = hosted_ci["status"] == "success" or (
        hosted_ci["status"] == "failure"
        and bool(hosted_ci.get("diagnosis"))
        and re.search(
            r"\bPASS \d+/\d+ exact-source local serial Swift suite\b",
            evidence["local_suite"],
        ) is not None
    )
    acceptance_site = acceptance["latest_site_deployment"]
    nested_acceptance_site = evidence.get("latest_site_deployment")
    acceptance_slice = acceptance["latest_acceptance_slice"]
    checks = [
        (not any(has_nested_key(value, "next_action") for key, value in project.items() if key != "next_action"),
         "PROJECT-STATE has nested next_action fields; keep one canonical root action"),
        (not any(has_nested_key(value, "next_action") for key, value in acceptance.items() if key != "next_action"),
         "ACCEPTANCE has nested next_action fields; keep one canonical root action"),
        (not ({
            "current_head_native_smoke",
            "current_head_native_build",
            "latest_local_appkit_build",
            "last_native_bundle_smoke",
            "latest_native_bundle",
            "latest_native_build",
        } & set(project.get("verification", {}))),
         "PROJECT-STATE.verification contains ambiguous current/latest native build pointers; keep only local_development_candidate current and label older receipts historical"),
        (acceptance["status"].startswith(acceptance_slice["id"]),
         "ACCEPTANCE.status is stale; it must identify latest_acceptance_slice"),
        (acceptance_slice["source_commit"] == app_sha,
         "ACCEPTANCE.latest_acceptance_slice source differs from current_evidence"),
        (project["product"]["app_source_commit"] == app_sha,
         "PROJECT-STATE.product.app_source_commit != ACCEPTANCE.current_evidence.app_source_commit"),
        (project["next_action"] == acceptance["next_action"],
         "PROJECT-STATE.next_action != ACCEPTANCE.next_action"),
        (acceptance["last_verification"]["app_source_commit"] == app_sha,
         "ACCEPTANCE.last_verification is stale; use current_evidence for the resume checkpoint"),
        (local_app["application_source_commit"] == bundle["source_commit"],
         "canonical Dev.app source differs between checkpoint files"),
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
        (acceptance_slice["source_commit"] == app_sha,
         "ACCEPTANCE.latest_acceptance_slice is stale"),
        (hosted_ci_matches_source and hosted_ci_is_recorded,
         "current hosted CI outcome is missing, stale, or an undiagnosed failure"),
        (exact_ci_copies_match,
         "duplicate exact-source CI checkpoint differs from current_evidence.hosted_ci"),
        (acceptance_site["version"] == deployment["version"]
         and acceptance_site["project_id"] == deployment["project_id"]
         and acceptance_site["source_commit"] == deployment["source_commit"]
         and acceptance_site["deployment_id"] == deployment["deployment_id"],
         "ACCEPTANCE Site deployment differs from PROJECT-STATE"),
        (nested_acceptance_site == acceptance_site,
         "ACCEPTANCE.current_evidence.latest_site_deployment is stale"),
    ]
    errors = [message for condition, message in checks if not condition]
    pending = project.get("pending_native_candidate")
    if local_app["application_source_commit"] != app_sha:
        pending_sources_match = (
            local_app.get("pending_source_commit") == app_sha
            and bundle.get("pending_source_commit") == app_sha
        )
        if not pending_sources_match:
            errors.append("pending native source differs between current checkpoint records")
        pending_matches = (
            isinstance(pending, dict)
            and pending.get("source_commit") == app_sha
            and pending.get("running_bundle_source_commit") == local_app["application_source_commit"]
            and pending.get("status") == "blocked_running_canonical_app"
            and bool(pending.get("reason"))
        )
        if not pending_matches:
            errors.append("canonical Dev.app is stale without a matching documented pending native candidate")
    elif (
        "pending_source_commit" in local_app
        or "pending_source_commit" in bundle
        or pending is not None
    ):
        errors.append("pending native source differs: remove superseded pending-source pointers after the canonical Dev.app reaches current app source")
    if errors:
        raise ValueError("\n".join(errors))


def validate() -> None:
    validate_records(read_json("PROJECT-STATE.json"), read_json("ACCEPTANCE.json"))
if __name__ == "__main__":
    try:
        validate()
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        print(f"checkpoint validation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
    print("checkpoint validation passed: app source, canonical Dev.app, and Site pointers agree")
