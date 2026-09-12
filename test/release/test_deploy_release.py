import contextlib
import hashlib
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
import deploy_release as deploy
import linux_runtime


class RuntimeRequirementsTest(unittest.TestCase):
    def test_prebuilt_database_raises_the_runner_glibc_floor(self):
        required = linux_runtime.glibc_requirement("Name: GLIBC_2.3 Name: GLIBC_2.38 Name: GLIBC_2.17")
        self.assertEqual(required, "2.38")
        self.assertEqual(linux_runtime.declare_glibc("libc6 (>= 2.34), libgcc-s1 (>= 4.2)", required),
                         "libc6 (>= 2.38), libgcc-s1 (>= 4.2)")

    def test_does_not_lower_a_newer_system_requirement(self):
        self.assertEqual(linux_runtime.declare_glibc("libc6 (>= 2.39)", "2.38"), "libc6 (>= 2.39)")

    def test_missing_libc_dependency_is_rejected(self):
        with self.assertRaises(ValueError):
            linux_runtime.declare_glibc("libgcc-s1 (>= 4.2)", "2.38")


class PublishedInstallersTest(unittest.TestCase):
    def release(self):
        return {"tagName": "v1.2.5", "isDraft": False,
                "assets": [{"name": name, "size": 42} for name in deploy.installer_names("1.2.5")]}

    def test_requires_public_release_and_both_platforms(self):
        deploy.validate_assets(self.release(), "1.2.5")
        for change in ("draft", "missing", "empty", "wrong_tag"):
            release = self.release()
            if change == "draft":
                release["isDraft"] = True
            elif change == "missing":
                release["assets"].pop(1)
            elif change == "empty":
                release["assets"][0]["size"] = 0
            else:
                release["tagName"] = "v1.2.4"
            with self.subTest(change=change), self.assertRaises(RuntimeError):
                deploy.validate_assets(release, "1.2.5")

    def test_checks_downloaded_bytes_not_just_asset_names(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            names = deploy.installer_names("1.2.5")[:-1]
            for name in names:
                (root / name).write_bytes(name.encode())
            checksums = "".join(f"{hashlib.sha256(name.encode()).hexdigest()}  {name}\n" for name in names)
            (root / "SHA256SUMS.txt").write_text(checksums)
            deploy.verify_downloads(root, "1.2.5")
            (root / names[1]).write_bytes(b"corrupt download")
            with self.assertRaisesRegex(RuntimeError, "Checksum incorrecto"):
                deploy.verify_downloads(root, "1.2.5")
            (root / "SHA256SUMS.txt").write_text(checksums.splitlines()[0] + "\n")
            with self.assertRaisesRegex(RuntimeError, "todos los instaladores"):
                deploy.verify_downloads(root, "1.2.5")

    def test_rejects_unsigned_tags_and_unverified_github_signatures(self):
        with patch.object(deploy, "api", return_value={"object": {"type": "commit"}}):
            with self.assertRaisesRegex(RuntimeError, "anotado y firmado"):
                deploy.verified_tag("owner/repo", "v1.2.5")
        with patch.object(deploy, "api", side_effect=[{"object": {"type": "tag", "sha": "abc"}},
                                                     {"verification": {"verified": False, "reason": "unsigned"}}]):
            with self.assertRaisesRegex(RuntimeError, "unsigned"):
                deploy.verified_tag("owner/repo", "v1.2.5")


class DeploymentSequenceTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = "name: keel_ui\nversion: 1.2.4+45\n"
        (self.root / "pubspec.yaml").write_text(self.source)
        self.commands = []
        self.responses = {
            ("git", "branch", "--show-current"): "main",
            ("gh", "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"): "owner/repo",
            ("git", "remote", "get-url", "origin"): "git@github.com:owner/repo.git",
            ("git", "config", "--get", "commit.gpgsign"): "true",
            ("git", "config", "--get", "user.signingkey"): "key",
            ("dart", "run", "tool/release_version.dart", "next", "1.2.4+45"): "1.2.5+46",
            ("git", "log", "-1", "--format=%G?"): "G",
            ("git", "rev-parse", "HEAD"): "commit",
        }

    def command(self, *args, **kwargs):
        self.commands.append(args)
        return self.responses.get(args, "")

    def execute(self, *arguments):
        with patch.object(deploy, "ROOT", self.root), patch.object(deploy, "run", side_effect=self.command), \
             patch.object(deploy.shutil, "which", return_value="/bin/tool"), \
             patch.object(deploy.subprocess, "run") as signing, \
             patch.object(deploy, "verified_tag") as verified, \
             patch.object(deploy, "wait_and_download") as downloaded, \
             patch.object(sys, "argv", ["deploy_release.py", *arguments]), contextlib.redirect_stdout(io.StringIO()):
            signing.return_value.returncode = 0
            deploy.main()
            return verified, downloaded

    def test_check_never_changes_version_commits_tags_or_pushes(self):
        self.execute("--check")
        self.assertEqual((self.root / "pubspec.yaml").read_text(), self.source)
        self.assertFalse(any(command[:2] in [("git", "commit"), ("git", "push")] for command in self.commands))
        self.assertFalse(any(command[:3] == ("git", "tag", "-s") for command in self.commands))

    def test_deploy_signs_and_verifies_before_atomic_push(self):
        verified, downloaded = self.execute()
        self.assertIn("version: 1.2.5+46", (self.root / "pubspec.yaml").read_text())
        signed = next(i for i, command in enumerate(self.commands) if command[:3] == ("git", "tag", "-s"))
        checked = self.commands.index(("git", "verify-tag", "v1.2.5"))
        pushed = self.commands.index(("git", "push", "--atomic", "origin", "HEAD:refs/heads/main", "refs/tags/v1.2.5"))
        self.assertLess(signed, checked)
        self.assertLess(checked, pushed)
        verified.assert_called_once_with("owner/repo", "v1.2.5")
        downloaded.assert_called_once_with("owner/repo", "v1.2.5", "1.2.5", "commit", resume=False)

    def test_dirty_tree_is_not_committed_or_published(self):
        self.responses[("git", "status", "--porcelain")] = " M lib/main.dart"
        with self.assertRaisesRegex(RuntimeError, "Guarda los cambios"):
            self.execute()
        self.assertEqual(self.commands, [("git", "status", "--porcelain")])

    def test_existing_tag_is_never_overwritten(self):
        self.responses[("git", "tag", "--list", "v1.2.5")] = "v1.2.5"
        with self.assertRaisesRegex(RuntimeError, "ya existe"):
            self.execute()
        self.assertEqual((self.root / "pubspec.yaml").read_text(), self.source)

    def test_unsigned_commit_is_never_tagged_or_pushed(self):
        self.responses[("git", "log", "-1", "--format=%G?")] = "N"
        with self.assertRaisesRegex(RuntimeError, "firma válida"):
            self.execute()
        self.assertFalse(any(command[:2] == ("git", "push") for command in self.commands))
        self.assertFalse(any(command[:3] == ("git", "tag", "-s") for command in self.commands))


if __name__ == "__main__":
    unittest.main()
