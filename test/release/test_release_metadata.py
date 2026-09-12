import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/release_metadata.py"
SPEC = importlib.util.spec_from_file_location("release_metadata", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ReleaseMetadataTest(unittest.TestCase):
    def test_tag_uses_the_committed_version_without_bumping(self):
        self.assertEqual(
            MODULE.release_metadata("name: keel_ui\nversion: 1.2.3+44\n", "v1.2.3"),
            {"version": "1.2.3", "build": "44", "tag": "v1.2.3"},
        )

    def test_manual_build_resolves_the_same_artifact_names(self):
        self.assertEqual(MODULE.release_metadata("version: 1.2.3+44\n")["tag"], "v1.2.3")

    def test_rejects_mismatched_or_malformed_tags(self):
        for tag in ["v1.2.4", "1.2.3", "v1.2.3-rc.1", "v1.2.3\nversion=9", "v1.2.3;echo bad"]:
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                MODULE.release_metadata("version: 1.2.3+44\n", tag)

    def test_rejects_missing_build_or_ambiguous_versions(self):
        for text in ["", "version: 1.2.3", "version: 01.2.3+4", "version: 1.2.3+0",
                     "version: 1.2.3+4\nversion: 1.2.4+5\n"]:
            with self.subTest(text=text), self.assertRaises(ValueError):
                MODULE.release_metadata(text)

    def test_cli_writes_only_validated_outputs_and_preserves_pubspec(self):
        with tempfile.TemporaryDirectory() as directory:
            pubspec = Path(directory) / "pubspec.yaml"
            output = Path(directory) / "output"
            source = "name: keel_ui\nversion: 1.2.3+44\n"
            pubspec.write_text(source)
            result = subprocess.run(
                ["python3", str(SCRIPT), "--pubspec", str(pubspec), "--tag", "v1.2.3", "--github-output"],
                env={**os.environ, "GITHUB_OUTPUT": str(output)}, capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout)["version"], "1.2.3")
            self.assertEqual(output.read_text(), "version=1.2.3\nbuild=44\ntag=v1.2.3\n")
            self.assertEqual(pubspec.read_text(), source)
            output.unlink()
            failed = subprocess.run(
                ["python3", str(SCRIPT), "--pubspec", str(pubspec), "--tag", "v1.2.4", "--github-output"],
                env={**os.environ, "GITHUB_OUTPUT": str(output)}, capture_output=True, text=True,
            )
            self.assertNotEqual(failed.returncode, 0)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
