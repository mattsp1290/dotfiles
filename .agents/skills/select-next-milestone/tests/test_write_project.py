from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import unittest

SKILL_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = SKILL_ROOT / "scripts"
sys.path.insert(0, str(SCRIPTS))
sys.path.insert(0, str(Path(__file__).parent))

import validate_project as validator  # noqa: E402
import write_project as writer  # noqa: E402
from test_validate_project import valid_value  # noqa: E402


class WriterTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)
        self.root = self.base / "repo"
        self.root.mkdir()
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        self.data = validator.canonical_bytes(valid_value())
        self.digest = hashlib.sha256(self.data).hexdigest()
        self.candidate = self.base / "candidate.json"
        self.candidate.write_bytes(self.data)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_create_commits_exact_confirmed_bytes_and_validates(self) -> None:
        writer.create(str(self.root), str(self.candidate), self.digest)
        destination = self.root / ".agents" / "next-milestone.json"
        self.assertEqual(self.data, destination.read_bytes())
        validator.validate_repository(str(self.root))

    def test_digest_mismatch_writes_nothing(self) -> None:
        with self.assertRaises(validator.ValidationFailure) as caught:
            writer.create(str(self.root), str(self.candidate), "0" * 64)
        self.assertEqual(writer.CONFLICT, caught.exception.code)
        self.assertFalse((self.root / ".agents").exists())

    def test_existing_destination_is_never_overwritten(self) -> None:
        destination = self.root / ".agents" / "next-milestone.json"
        destination.parent.mkdir()
        destination.write_text("competing bytes")
        with self.assertRaises(validator.ValidationFailure) as caught:
            writer.create(str(self.root), str(self.candidate), self.digest)
        self.assertEqual(writer.CONFLICT, caught.exception.code)
        self.assertEqual("competing bytes", destination.read_text())

    def test_parent_symlink_is_rejected(self) -> None:
        outside = self.base / "outside"
        outside.mkdir()
        (self.root / ".agents").symlink_to(outside, target_is_directory=True)
        with self.assertRaises(validator.ValidationFailure) as caught:
            writer.create(str(self.root), str(self.candidate), self.digest)
        self.assertEqual(validator.UNSAFE, caught.exception.code)
        self.assertEqual([], list(outside.iterdir()))

    def test_invalid_candidate_is_not_written(self) -> None:
        self.candidate.write_text("{}\n")
        with self.assertRaises(validator.ValidationFailure) as caught:
            writer.create(str(self.root), str(self.candidate), hashlib.sha256(b"{}\n").hexdigest())
        self.assertEqual(validator.INVALID, caught.exception.code)
        self.assertFalse((self.root / ".agents").exists())

    def test_concurrent_creators_have_exactly_one_winner(self) -> None:
        barrier = threading.Barrier(3)
        outcomes: list[int] = []

        def attempt() -> None:
            barrier.wait()
            try:
                writer.create(str(self.root), str(self.candidate), self.digest)
                outcomes.append(0)
            except validator.ValidationFailure as exc:
                outcomes.append(exc.code)

        threads = [threading.Thread(target=attempt) for _ in range(2)]
        for thread in threads:
            thread.start()
        barrier.wait()
        for thread in threads:
            thread.join()
        self.assertCountEqual([0, writer.CONFLICT], outcomes)
        self.assertEqual(self.data, (self.root / ".agents" / "next-milestone.json").read_bytes())

    def test_cli_reports_conflict_class(self) -> None:
        writer.create(str(self.root), str(self.candidate), self.digest)
        result = subprocess.run(
            [sys.executable, str(SCRIPTS / "write_project.py"), "create", str(self.root), str(self.candidate), self.digest],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(writer.CONFLICT, result.returncode)
        self.assertIn("already exists", result.stderr)


if __name__ == "__main__":
    unittest.main()
