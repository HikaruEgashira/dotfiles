import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class LockedWorktreeTest(unittest.TestCase):
    def test_locked_worktree_survives_all_cleanup_modes(self):
        script = Path(__file__).resolve().parents[1] / "scripts/clean-worktree.sh"
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repo = root / "owner/repo"
            repo.mkdir(parents=True)

            def git(*args):
                return subprocess.check_output(
                    ["git", "-C", str(repo), *args], text=True, stderr=subprocess.PIPE
                )

            git("init", "-b", "main")
            git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                "-c", "commit.gpgsign=false", "commit", "--allow-empty", "-m", "fixture")
            worktree = root / "locked"
            git("worktree", "add", "-b", "merged", str(worktree))
            git("worktree", "lock", "--reason", "active owner", str(worktree))
            before = git("worktree", "list", "--porcelain")
            bin_dir = root / "bin"
            bin_dir.mkdir()
            gh = bin_dir / "gh"
            gh.write_text("#!/bin/sh\nexit 1\n")
            gh.chmod(0o700)
            env = {**os.environ, "GHQ_ROOT": str(root),
                   "PATH": str(bin_dir) + os.pathsep + os.environ["PATH"]}
            for flags in ([], ["--dry-run"], ["--force"]):
                with self.subTest(flags=flags):
                    result = subprocess.run(["bash", str(script), *flags], env=env,
                                            text=True, capture_output=True, check=True)
                    self.assertIn("(locked)", result.stdout)
                    self.assertTrue(worktree.is_dir())
                    self.assertEqual(git("worktree", "list", "--porcelain"), before)
                    git("show-ref", "--verify", "refs/heads/merged")
            # Git must also reject a lock acquired after the script listed worktrees.
            result = subprocess.run(["git", "-C", str(repo), "worktree", "remove",
                                     "--force", str(worktree)], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertTrue(worktree.is_dir())


if __name__ == "__main__":
    unittest.main()
