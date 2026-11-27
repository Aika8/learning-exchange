"""LE-409: the first of Mara's talk balloons that mentions six moons also says what a moon is."""
import csv
import os
import unittest

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TALK = os.path.join(ROOT, "game3d", "i18n", "talk.csv")


def mara_rows():
    with open(TALK, encoding="utf-8", newline="") as f:
        return [row for row in csv.DictReader(f) if row["keys"].startswith("TALK_MARA")]


def first_with(column, phrase):
    for row in mara_rows():
        if phrase in row[column].lower():
            return row
    return None


class MoonWordTest(unittest.TestCase):
    def test_russian_first_mention_explains_moon(self):
        row = first_with("ru", "шесть лун")
        self.assertIsNotNone(row, "no Mara balloon mentions «шесть лун»")
        self.assertIn("луна — месяц расходов", row["ru"], row["keys"])

    def test_english_first_mention_explains_moon(self):
        row = first_with("en", "six moons")
        self.assertIsNotNone(row, "no Mara balloon mentions six moons")
        self.assertIn("a moon is a month of expenses", row["en"], row["keys"])

    def test_both_languages_explain_in_the_same_balloon(self):
        self.assertEqual(first_with("ru", "шесть лун")["keys"], first_with("en", "six moons")["keys"])


if __name__ == "__main__":
    unittest.main()
