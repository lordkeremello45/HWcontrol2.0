import csv
import tempfile
import unittest
from pathlib import Path

from generate_fixture import COLUMNS, write_fixture

class GenerateFixtureTests(unittest.TestCase):
    def test_fixture_schema_and_rows(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.csv"
            write_fixture(path)
            with path.open(newline="", encoding="utf-8") as handle:
                rows = list(csv.reader(handle))
        self.assertEqual(rows[0], COLUMNS)
        self.assertEqual(len(rows), 3)
        self.assertEqual(rows[1][-1], "NORMAL")

if __name__ == "__main__":
    unittest.main()
