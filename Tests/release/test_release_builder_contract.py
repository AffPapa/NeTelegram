from __future__ import annotations

import base64
import json
import os
from pathlib import Path
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Scripts/build-release-candidate.sh"


class ReleaseBuilderContractTests(unittest.TestCase):
    def test_shell_syntax_is_valid(self):
        subprocess.run(["bash", "-n", str(SCRIPT)], check=True, cwd=ROOT)

    def test_help_is_available_without_release_credentials(self):
        result = subprocess.run([str(SCRIPT), "--help"], check=True, text=True,
                                capture_output=True, cwd=ROOT)
        self.assertIn("NETELEGRAM_NOTARY_PROFILE", result.stdout)
        self.assertIn("login Keychain", result.stdout)

    def test_preflight_fails_closed_before_side_effects_when_configuration_is_missing(self):
        env = os.environ.copy()
        for key in tuple(env):
            if key.startswith("NETELEGRAM_"):
                env.pop(key)
        result = subprocess.run([str(SCRIPT), "--preflight-only"], text=True,
                                capture_output=True, cwd=ROOT, env=env)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("NETELEGRAM_RELEASE_VERSION", result.stderr)
        self.assertFalse((ROOT / ".build/release-candidates").exists())

    def test_stable_candidate_is_rejected_before_network_or_output(self):
        env = os.environ.copy()
        env.update({
            "NETELEGRAM_RELEASE_VERSION": "0.1.0",
            "NETELEGRAM_RELEASE_BUILD": "1",
            "NETELEGRAM_RELEASE_CHANNEL": "stable",
            "NETELEGRAM_DEVELOPER_IDENTITY": "unused",
            "NETELEGRAM_DEVELOPER_TEAM_ID": "ABCDEFGHIJ",
            "NETELEGRAM_NOTARY_PROFILE": "unused",
            "NETELEGRAM_RELEASE_OUTPUT": "/private/tmp/netelegram-stable-must-not-exist",
        })
        result = subprocess.run([str(SCRIPT), "--preflight-only"], text=True,
                                capture_output=True, cwd=ROOT, env=env)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("stable remains gated", result.stderr)
        self.assertFalse(Path("/private/tmp/netelegram-stable-must-not-exist").exists())

    def test_release_assembly_is_separate_from_canonical_dev_app(self):
        source = SCRIPT.read_text(encoding="utf-8")
        self.assertNotIn("/private/tmp/NeTelegram-Dev.app", source)
        self.assertIn("NETELEGRAM_RELEASE_OUTPUT", source)
        self.assertIn("refusing to overwrite candidate bytes", source)

    def test_updater_config_contains_only_project_account_and_public_key(self):
        config = json.loads((ROOT / "UPDATER-CONFIG.json").read_text(encoding="utf-8"))
        self.assertEqual(set(config), {"schema_version", "sparkle_key_account", "sparkle_public_ed_key"})
        self.assertEqual(config["sparkle_key_account"], "netide-updates")
        self.assertEqual(len(base64.b64decode(config["sparkle_public_ed_key"], validate=True)), 32)

    def test_signing_is_inside_out_without_deep_signing(self):
        source = SCRIPT.read_text(encoding="utf-8")
        self.assertLess(source.index('sign_runtime "$SPARKLE_VERSION/XPCServices/Installer.xpc"'),
                        source.index('sign_runtime "$FRAMEWORKS/Sparkle.framework"'))
        self.assertLess(source.index('sign_runtime "$FRAMEWORKS/Sparkle.framework"'),
                        source.index('sign_runtime "$APP"'))
        self.assertNotIn("codesign --deep", source)

    def test_release_requires_accepted_notarization_and_sparkle_signature(self):
        source = SCRIPT.read_text(encoding="utf-8")
        self.assertIn('[[ "$status" == "Accepted"', source)
        self.assertIn('"$SPARKLE_SIGN_UPDATE" --account "$NETELEGRAM_SPARKLE_KEY_ACCOUNT" --verify "$UPDATE_ZIP" "$SIGNATURE"', source)
        self.assertIn('"$SPARKLE_GENERATE_KEYS" --account "$NETELEGRAM_SPARKLE_KEY_ACCOUNT" -p', source)
        self.assertIn('UPDATER-CONFIG.json', source)
        self.assertIn('git -c credential.helper=osxkeychain -C "$ROOT_DIR" ls-remote', source)
        self.assertIn('"sparkle_key_account":key_account', source)
        self.assertIn('"sparkle_short_version":version', source)
        self.assertIn('"update_channel":channel', source)
        self.assertIn('xcrun stapler validate "$APP"', source)
        self.assertIn('xcrun stapler validate "$DMG"', source)


if __name__ == "__main__":
    unittest.main()
