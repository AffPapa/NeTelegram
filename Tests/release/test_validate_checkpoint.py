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


if __name__ == "__main__":
    unittest.main()
