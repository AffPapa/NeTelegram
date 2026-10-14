from __future__ import annotations

import copy
import json
import unittest
from pathlib import Path

from Scripts.validate_checkpoint import validate_records


ROOT = Path(__file__).resolve().parents[2]


class ValidateCheckpointTests(unittest.TestCase):
    def setUp(self):
        self.project = json.loads((ROOT / "PROJECT-STATE.json").read_text(encoding="utf-8"))
        self.acceptance = json.loads((ROOT / "ACCEPTANCE.json").read_text(encoding="utf-8"))

    def test_stale_running_bundle_requires_exact_pending_source_and_reason(self):
        project = copy.deepcopy(self.project)
        acceptance = copy.deepcopy(self.acceptance)
        current = "new-app-source"
        running = project["local_development_candidate"]["application_source_commit"]
        project["product"]["app_source_commit"] = current
        project["latest_acceptance_slice"]["source_commit"] = current
        acceptance["current_evidence"]["app_source_commit"] = current
        acceptance["current_evidence"]["hosted_ci"]["workflow_commit"] = current
        acceptance["current_evidence"]["hosted_ci"]["app_source_commit"] = current
        acceptance["latest_acceptance_slice"]["source_commit"] = current
        acceptance["last_verification"]["app_source_commit"] = current
        project["pending_native_candidate"] = {
            "source_commit": current,
            "running_bundle_source_commit": running,
            "status": "blocked_running_canonical_app",
            "reason": "The earlier app has not exited; the guarded builder refused replacement.",
        }

        validate_records(project, acceptance)

        project["pending_native_candidate"]["source_commit"] = "different-source"
        with self.assertRaisesRegex(ValueError, "stale without a matching documented pending"):
            validate_records(project, acceptance)

    def test_resume_action_must_match_across_checkpoint_files(self):
        project = copy.deepcopy(self.project)
        acceptance = copy.deepcopy(self.acceptance)
        acceptance["next_action"] += " Do something else."

        with self.assertRaisesRegex(ValueError, "next_action"):
            validate_records(project, acceptance)

    def test_current_hosted_ci_must_cover_exact_app_source(self):
        project = copy.deepcopy(self.project)
        acceptance = copy.deepcopy(self.acceptance)
        acceptance["current_evidence"]["hosted_ci"]["app_source_commit"] = "older-source"

        with self.assertRaisesRegex(ValueError, "missing, stale, or an undiagnosed failure"):
            validate_records(project, acceptance)

    def test_exact_source_timeout_can_be_checkpointed_without_calling_it_a_pass(self):
        project = copy.deepcopy(self.project)
        acceptance = copy.deepcopy(self.acceptance)
        current = "new-app-source"
        running = project["local_development_candidate"]["application_source_commit"]
        project["product"]["app_source_commit"] = current
        project["latest_acceptance_slice"]["source_commit"] = current
        project["pending_native_candidate"] = {
            "source_commit": current,
            "running_bundle_source_commit": running,
            "status": "blocked_running_canonical_app",
            "reason": "The canonical development app is still running.",
        }
        acceptance["current_evidence"]["app_source_commit"] = current
        acceptance["current_evidence"]["hosted_ci"] = {
            "run_id": 123,
            "status": "failure",
            "workflow_commit": current,
            "app_source_commit": current,
            "diagnosis": "The exact-source full-suite step timed out; local serial suite passed.",
        }
        acceptance["current_evidence"]["local_suite"] = "PASS 166/166 exact-source local serial suite."
        acceptance["latest_acceptance_slice"]["source_commit"] = current
        acceptance["last_verification"]["app_source_commit"] = current

        validate_records(project, acceptance)

        acceptance["current_evidence"]["hosted_ci"].pop("diagnosis")
        with self.assertRaisesRegex(ValueError, "undiagnosed failure"):
            validate_records(project, acceptance)

    def test_site_deployment_identity_must_match_both_checkpoints(self):
        project = copy.deepcopy(self.project)
        acceptance = copy.deepcopy(self.acceptance)
        acceptance["latest_site_deployment"]["version"] -= 1

        with self.assertRaisesRegex(ValueError, "Site deployment differs"):
            validate_records(project, acceptance)


if __name__ == "__main__":
    unittest.main()
