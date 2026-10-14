import unittest
from pathlib import Path


WORKFLOW = Path(__file__).resolve().parents[2] / ".github/workflows/native-app.yml"


class NativeWorkflowScopeTests(unittest.TestCase):
    def test_native_build_runs_for_app_sources_and_dependency_inputs(self):
        lines = WORKFLOW.read_text(encoding="utf-8").splitlines()

        def block(name):
            start = lines.index(f"  {name}:")
            end = next(
                (i for i in range(start + 1, len(lines)) if lines[i].startswith("  ") and not lines[i].startswith("    ")),
                len(lines),
            )
            return lines[start:end]

        def paths(event):
            section = block(event)
            start = section.index("    paths:")
            return [
                line.strip()[3:-1]
                for line in section[start + 1 :]
                if line.startswith("      - '")
            ]

        expected = [
            "Package.swift",
            "Scripts/build-tdlib.sh",
            "Scripts/dev-app.sh",
            "Scripts/window-lifecycle-smoke.sh",
            "Scripts/tdlib-smoke.c",
            "TDLIB.lock.json",
            "Sources/**",
        ]
        self.assertEqual(paths("push"), expected)
        self.assertEqual(paths("pull_request"), expected)
        self.assertNotIn(".github/workflows/native-app.yml", expected)

    def test_manual_native_bundle_gate_remains_available(self):
        self.assertIn("  workflow_dispatch:", WORKFLOW.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
