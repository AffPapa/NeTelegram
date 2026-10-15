import tempfile
from pathlib import Path
import unittest

from Scripts.generate_release_notices import NoticeError, build_notice


ROOT = Path(__file__).resolve().parents[2]


class ReleaseNoticeTests(unittest.TestCase):
    def test_notice_includes_project_and_pinned_licenses_deterministically(self):
        first = build_notice(ROOT)
        second = build_notice(ROOT)
        self.assertEqual(first, second)
        for required in ("MIT License", "TDLib", "OpenSSL", "libphonenumber", "ZETETIC LLC", "gperf", "Sparkle-LICENSE.txt"):
            self.assertIn(required, first)

    def test_changed_pinned_license_fails_closed(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for path in ("TDLIB.lock.json", "COUNTRY-DATA.lock.json", "SPARKLE.lock.json", "LICENSE", "NOTICE"):
                (root / path).write_bytes((ROOT / path).read_bytes())
            source_licenses = ROOT / "ThirdPartyLicenses"
            (root / "ThirdPartyLicenses").mkdir()
            for path in source_licenses.iterdir():
                (root / "ThirdPartyLicenses" / path.name).write_bytes(path.read_bytes())
            path = root / "ThirdPartyLicenses/TDLib-BSL-1.0.txt"
            path.write_text(path.read_text(encoding="utf-8") + "\nchanged\n", encoding="utf-8")
            with self.assertRaisesRegex(NoticeError, "hash does not match lock"):
                build_notice(root)


if __name__ == "__main__":
    unittest.main()
