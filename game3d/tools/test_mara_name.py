"""LE-094: Mara's English full name is «Mara Anchor» in every string table."""
import csv
import glob
import os
import unittest

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TABLES = sorted(glob.glob(os.path.join(ROOT, "game3d", "i18n", "*.csv"))) + [
    os.path.join(ROOT, "game", "i18n", "strings.csv")
]


def english_cells(path):
    with open(path, encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            yield row.get("keys") or row.get("key") or "", row.get("en") or ""


class MaraNameTest(unittest.TestCase):
    def test_tables_exist(self):
        self.assertGreater(len(TABLES), 1)
        for path in TABLES:
            self.assertTrue(os.path.isfile(path), path)

    def test_no_old_english_name(self):
        for path in TABLES:
            for key, en in english_cells(path):
                self.assertNotIn("Mara of the Anchor", en, f"{os.path.relpath(path, ROOT)}: {key}")

    def test_who_mara_is_mara_anchor(self):
        talk = dict(english_cells(os.path.join(ROOT, "game3d", "i18n", "talk.csv")))
        self.assertEqual("Mara Anchor", talk["WHO_MARA"])


if __name__ == "__main__":
    unittest.main()
