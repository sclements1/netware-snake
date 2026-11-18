"""Fail-closed release state transitions without credentials or network access."""

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace

spec = importlib.util.spec_from_file_location(
    "release_macos", Path(__file__).resolve().parents[1] / "tools/release_macos.py"
)
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.folder = Path(self.directory.name)
        (self.folder / "test.dmg").write_bytes(b"original")
        self.state = dict(
            artifact="test.dmg",
            sha256=release.digest(self.folder / "test.dmg"),
            development=False,
            phase="bundles",
        )
        release.save(self.folder, self.state)

    def test_modified_artifact_rejected(self):
        (self.folder / "test.dmg").write_bytes(b"changed")
        with self.assertRaisesRegex(RuntimeError, "Artifact changed"):
            release.load(self.folder)

    def test_dirty_signed_preparation_stops_before_build_or_staging(self):
        with patch.object(
            release.platform, "system", return_value="Darwin"
        ), patch.object(release.platform, "machine", return_value="arm64"), patch.dict(
            "os.environ", SIGN_IDENTITY="fixture", TEAM_ID="fixture"
        ), patch.object(
            release, "ROOT", self.folder
        ), patch.object(
            release, "run", return_value=SimpleNamespace(stdout=" M source.m\n")
        ) as run:
            with self.assertRaisesRegex(RuntimeError, "clean checkout"):
                release.prepare(False)
            self.assertEqual(run.call_count, 1)
            self.assertFalse((self.folder / "build").exists())

    def test_development_cannot_submit(self):
        self.state["development"] = True
        release.save(self.folder, self.state)
        with patch("sys.argv", ["release", "submit", str(self.folder)]), patch.object(
            release, "run"
        ) as run:
            with self.assertRaisesRegex(RuntimeError, "cannot be submitted"):
                release.main()
            run.assert_not_called()

    def test_pending_acceptance_stops_before_log(self):
        self.state["submission_id"] = "test-id"
        with patch.object(release, "credentials", return_value="fixture"), patch.object(
            release,
            "run",
            return_value=SimpleNamespace(stdout=json.dumps({"status": "In Progress"})),
        ) as run:
            with self.assertRaisesRegex(RuntimeError, "In Progress"):
                release.accepted(self.folder, self.state)
            self.assertEqual(run.call_count, 1)

    def test_duplicate_submission_rejected(self):
        self.state["submission_id"] = "test-id"
        release.save(self.folder, self.state)
        with patch("sys.argv", ["release", "submit", str(self.folder)]), patch.object(
            release, "run"
        ) as run:
            with self.assertRaisesRegex(RuntimeError, "Already submitted"):
                release.main()
            run.assert_not_called()

    def test_changed_payload_stops_before_apple(self):
        (self.folder / "payload").mkdir()
        (self.folder / "payload/fixture").write_text("signed data")
        self.state["payload_hashes"] = release.payload_hashes(self.folder)
        release.save(self.folder, self.state)
        (self.folder / "payload/fixture").write_text("different")
        with patch("sys.argv", ["release", "package", str(self.folder)]), patch.object(
            release, "run"
        ) as run:
            with self.assertRaisesRegex(RuntimeError, "payload changed"):
                release.main()
            run.assert_not_called()
