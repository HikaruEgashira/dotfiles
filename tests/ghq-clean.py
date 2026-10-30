#!/usr/bin/env python3
from __future__ import annotations

import datetime as dt
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

script = Path(__file__).resolve().parents[1] / "scripts" / "ghq-clean.py"
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("ghq_clean", script)
ghq_clean = importlib.util.module_from_spec(spec)
assert spec and spec.loader
sys.modules[spec.name] = ghq_clean
spec.loader.exec_module(ghq_clean)


def git(path: Path, *args: str, env: dict[str, str] | None = None) -> bytes:
    return subprocess.run(
        ["git", "-C", str(path), *args],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
    ).stdout


class GhqCleanTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)
        self.ghq = self.base / "ghq" / "github.com"
        self.ghq.mkdir(parents=True)
        self.cache = self.base / "cache" / "metadata.json"
        self.repo = self.ghq / "example" / "sample"
        self.repo.parent.mkdir()
        self.create_repo(self.repo)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def create_repo(self, path: Path, slug: str = "example/sample", commit_time: int = 946684800) -> None:
        path.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "init", "--quiet", "-b", "main", str(path)], check=True, capture_output=True)
        git(path, "config", "user.name", "Fixture")
        git(path, "config", "user.email", "fixture@example.invalid")
        git(path, "config", "commit.gpgsign", "false")
        (path / "tracked.txt").write_text("fixture\n", encoding="utf-8")
        git(path, "add", "tracked.txt")
        env = os.environ.copy()
        timestamp = dt.datetime.fromtimestamp(commit_time, tz=dt.timezone.utc).isoformat()
        env.update({"GIT_AUTHOR_DATE": timestamp, "GIT_COMMITTER_DATE": timestamp})
        git(path, "commit", "--quiet", "-m", "fixture", env=env)
        git(path, "remote", "add", "origin", f"https://github.com/{slug}.git")

    def metadata(self, *, archived: bool = False, pushed_at: int = 946684800, fetched_at: int = 1_000_000_000):
        return ghq_clean.Metadata("fresh", archived, pushed_at, fetched_at)

    def test_origin_parser_rejects_non_github_and_bad_path(self) -> None:
        self.assertEqual(ghq_clean.parse_slug("https://github.com/Example/Repo.git"), "Example/Repo")
        self.assertEqual(ghq_clean.parse_slug("git@github.com:Example/Repo.git"), "Example/Repo")
        self.assertIsNone(ghq_clean.parse_slug("https://github.example/Example/Repo.git"))
        self.assertIsNone(ghq_clean.parse_slug("https://github.com:bad/Example/Repo.git"))
        self.assertIsNone(ghq_clean.parse_slug("https://github.com/Example/Repo/tree/main"))

    def test_discovery_separates_clone_roots_linked_worktrees_and_other_dirs(self) -> None:
        linked = self.ghq / "example" / "linked"
        linked.mkdir()
        (linked / ".git").write_text("gitdir: ../sample/.git/worktrees/linked\n", encoding="utf-8")
        (self.ghq / "example" / "cache").mkdir()
        roots, linked_count, nonrepo_count = ghq_clean.discover_roots(self.ghq)
        self.assertEqual(roots, [self.repo.resolve()])
        self.assertEqual(linked_count, 1)
        self.assertEqual(nonrepo_count, 1)

    def test_symlinked_git_marker_fails_inventory_closed(self) -> None:
        marker = self.repo / ".git"
        saved_marker = self.repo / ".git.saved"
        marker.rename(saved_marker)
        marker.symlink_to(saved_marker, target_is_directory=True)
        state = ghq_clean.snapshot_repo(self.repo)
        self.assertIn("symlinked", state.error)
        self.assertEqual(
            ghq_clean.inspect_row(state, self.metadata(archived=True), [], 14, 2_000_000_000).state,
            "unknown",
        )
        with self.assertRaisesRegex(ghq_clean.ScanError, "symlinked .git marker"):
            ghq_clean.discover_roots(self.ghq)

    def test_dirty_and_linked_worktree_protect_candidate(self) -> None:
        meta = self.metadata(archived=True)
        (self.repo / "tracked.txt").write_text("modified\n", encoding="utf-8")
        dirty = ghq_clean.snapshot_repo(self.repo)
        self.assertEqual(ghq_clean.inspect_row(dirty, meta, [], 14, 2_000_000_000).state, "protected")

        (self.repo / "tracked.txt").write_text("fixture\n", encoding="utf-8")
        linked = self.base / "active-worktree"
        subprocess.run(
            ["git", "-C", str(self.repo), "worktree", "add", "--quiet", "-b", "active", str(linked)],
            check=True,
            capture_output=True,
        )
        state = ghq_clean.snapshot_repo(self.repo)
        row = ghq_clean.inspect_row(state, meta, [], 14, 2_000_000_000)
        self.assertEqual(row.state, "protected")
        self.assertEqual(len(state.linked_worktrees), 1)

    def test_archived_candidate_and_recent_remote_push_override_local_old_commit(self) -> None:
        local = ghq_clean.snapshot_repo(self.repo)
        archived = ghq_clean.inspect_row(local, self.metadata(archived=True, pushed_at=1_999_900_000), [], 14, 2_000_000_000)
        self.assertEqual(archived.state, "candidate")
        recent = ghq_clean.inspect_row(local, self.metadata(pushed_at=1_999_900_000), [], 14, 2_000_000_000)
        self.assertEqual(recent.state, "retained")

    def test_stale_metadata_and_missing_remote_are_unknown(self) -> None:
        local = ghq_clean.snapshot_repo(self.repo)
        stale = ghq_clean.inspect_row(
            local,
            ghq_clean.Metadata("stale", True, 1, 1, "refresh failed"),
            [],
            14,
            2_000_000_000,
        )
        missing = ghq_clean.inspect_row(
            local,
            ghq_clean.Metadata("unknown", detail="remote missing or inaccessible"),
            [],
            14,
            2_000_000_000,
        )
        self.assertEqual(stale.state, "unknown")
        self.assertEqual(missing.state, "unknown")

    def test_orca_matching_is_path_based_and_ambiguous_matches_fail_closed(self) -> None:
        local = ghq_clean.snapshot_repo(self.repo)
        same_project_other_path = ghq_clean.Setup("other", str(self.base / "other"), "github:example/sample", "git", "local")
        row = ghq_clean.inspect_row(local, self.metadata(archived=True), [same_project_other_path], 14, 2_000_000_000)
        self.assertEqual(row.state, "candidate")
        same_text_path_remote_host = ghq_clean.Setup(
            "remote", str(self.repo), "github:example/sample", "git", "ssh:remote-id"
        )
        row = ghq_clean.inspect_row(local, self.metadata(archived=True), [same_text_path_remote_host], 14, 2_000_000_000)
        self.assertEqual(row.state, "protected")
        exact = ghq_clean.Setup("exact", str(self.repo), "github:example/sample", "git", "local")
        row = ghq_clean.inspect_row(local, self.metadata(archived=True), [exact, exact], 14, 2_000_000_000)
        self.assertEqual(row.state, "unknown")

    def test_metadata_cache_batches_unique_slugs_and_stale_cache_cannot_be_used_for_deletion(self) -> None:
        value = {
            "found": True,
            "nameWithOwner": "example/sample",
            "archived": True,
            "pushedAt": 946684800,
        }
        with patch.object(ghq_clean, "graphql_batch", return_value={"example/sample": value}) as fetch:
            first = ghq_clean.metadata_for(
                ["example/sample", "EXAMPLE/SAMPLE"], self.cache, 3600, 2_000_000_000
            )
        self.assertEqual(fetch.call_count, 1)
        self.assertEqual(first["example/sample"].state, "fresh")

        with patch.object(ghq_clean, "graphql_batch", side_effect=AssertionError("fresh cache should avoid API")):
            second = ghq_clean.metadata_for(["example/sample"], self.cache, 3600, 2_000_000_010)
        self.assertEqual(second["example/sample"].state, "fresh")

        with patch.object(ghq_clean, "graphql_batch", side_effect=ghq_clean.ScanError("offline")):
            third = ghq_clean.metadata_for(["example/sample"], self.cache, 3600, 2_000_004_000)
        self.assertEqual(third["example/sample"].state, "stale")
        self.assertEqual(
            ghq_clean.inspect_row(
                ghq_clean.snapshot_repo(self.repo), third["example/sample"], [], 14, 2_000_004_000
            ).state,
            "unknown",
        )
        with patch.object(ghq_clean, "graphql_batch", side_effect=AssertionError("failure backoff should avoid API")):
            fourth = ghq_clean.metadata_for(["example/sample"], self.cache, 3600, 2_000_004_001)
        self.assertEqual(fourth["example/sample"].state, "stale")
        self.assertEqual(self.cache.stat().st_mode & 0o777, 0o600)

    def test_null_push_time_does_not_poison_batch_or_repeat_api(self) -> None:
        payload = {"data": {
            "r0": {"nameWithOwner": "example/sample", "isArchived": False, "pushedAt": None},
            "r1": {"nameWithOwner": "example/other", "isArchived": False, "pushedAt": "2026-10-30T00:00:00Z"},
        }}
        slugs = ["example/sample", "example/other"]
        with patch.object(ghq_clean, "command_text", return_value=json.dumps(payload)) as fetch:
            first = ghq_clean.metadata_for(slugs, self.cache, 3600, 2_000_000_000)
        self.assertEqual(fetch.call_count, 1)
        self.assertTrue(all(item.state == "fresh" for item in first.values()))
        self.assertIsNone(first["example/sample"].pushed_at)
        with patch.object(ghq_clean, "graphql_batch", side_effect=AssertionError("cache should avoid API")):
            second = ghq_clean.metadata_for(slugs, self.cache, 3600, 2_000_000_001)
        self.assertEqual(first, second)
        row = ghq_clean.inspect_row(ghq_clean.snapshot_repo(self.repo), second["example/sample"], [], 14, 2_000_000_001)
        self.assertEqual(row.state, "candidate")

    def test_metadata_fetch_is_chunked_to_bound_graphql_cost(self) -> None:
        slugs = [f"owner/repo-{index}" for index in range(26)]

        def response(batch):
            return {
                slug.casefold(): {
                    "found": True,
                    "nameWithOwner": slug,
                    "archived": False,
                    "pushedAt": 1_999_000_000,
                }
                for slug in batch
            }

        with patch.object(ghq_clean, "graphql_batch", side_effect=response) as fetch:
            result = ghq_clean.metadata_for(slugs, self.cache, 3600, 2_000_000_000)
        self.assertEqual(fetch.call_count, 2)
        self.assertEqual([len(call.args[0]) for call in fetch.call_args_list], [25, 1])
        self.assertEqual(len(result), 26)

    def test_null_remote_result_is_cached_as_unknown(self) -> None:
        with patch.object(ghq_clean, "graphql_batch", return_value={"example/sample": None}) as fetch:
            first = ghq_clean.metadata_for(["example/sample"], self.cache, 3600, 2_000_000_000)
        with patch.object(ghq_clean, "graphql_batch", side_effect=AssertionError("negative cache should be reused")):
            second = ghq_clean.metadata_for(["example/sample"], self.cache, 3600, 2_000_000_001)
        self.assertEqual(fetch.call_count, 1)
        self.assertEqual(first["example/sample"].state, "unknown")
        self.assertEqual(second["example/sample"].state, "unknown")

    def test_metadata_failure_without_cache_uses_cooldown(self) -> None:
        with patch.object(ghq_clean, "graphql_batch", side_effect=ghq_clean.ScanError("offline")) as fetch:
            first = ghq_clean.metadata_for(["example/sample"], self.cache, 3600, 2_000_000_000)
        with patch.object(ghq_clean, "graphql_batch", side_effect=AssertionError("failure cooldown should avoid API")):
            second = ghq_clean.metadata_for(["example/sample"], self.cache, 3600, 2_000_000_001)
        self.assertEqual(fetch.call_count, 1)
        self.assertEqual(first["example/sample"].state, "unknown")
        self.assertEqual(second["example/sample"].state, "unknown")

    def test_cache_write_does_not_change_existing_parent_permissions(self) -> None:
        parent = self.base / "existing-cache-dir"
        parent.mkdir()
        parent.chmod(0o755)
        value = {
            "found": True,
            "nameWithOwner": "example/sample",
            "archived": False,
            "pushedAt": 1_999_000_000,
        }
        with patch.object(ghq_clean, "graphql_batch", return_value={"example/sample": value}):
            ghq_clean.metadata_for(["example/sample"], parent / "metadata.json", 3600, 2_000_000_000)
        self.assertEqual(parent.stat().st_mode & 0o777, 0o755)

    def test_apply_fixture_removes_only_confirmed_temporary_clone_and_never_uses_force(self) -> None:
        current = int(__import__("time").time())
        local = ghq_clean.snapshot_repo(self.repo)
        meta = ghq_clean.Metadata("fresh", True, current - 86400, current)
        row = ghq_clean.Row(local, meta, "candidate", "remote archived")
        with patch.object(ghq_clean, "inspect", return_value=([row], 0, 0)), \
             patch.object(ghq_clean, "metadata_for", return_value={"example/sample": meta}), \
             patch.object(ghq_clean, "read_orca_setups", side_effect=[[], []]), \
             patch.object(ghq_clean.sys.stdin, "isatty", return_value=True), \
             patch("builtins.input", return_value="REMOVE 1"):
            status = ghq_clean.apply_rows([row], self.ghq, 14, 86400, self.cache)
        self.assertEqual(status, 0)
        self.assertFalse(self.repo.exists())

    def test_apply_fixture_deregisters_exact_setup_without_force_before_removal(self) -> None:
        current = int(__import__("time").time())
        local = ghq_clean.snapshot_repo(self.repo)
        meta = ghq_clean.Metadata("fresh", True, current - 86400, current)
        setup = ghq_clean.Setup("setup-1", str(self.repo), "github:example/sample", "git", "local")
        row = ghq_clean.Row(local, meta, "candidate", "remote archived", setup)
        original_command = ghq_clean.command
        calls = []

        def fake_command(argv, timeout=30):
            if argv[:3] == ["orca", "project", "setup-delete"]:
                calls.append(argv)
                return subprocess.CompletedProcess(argv, 0, b'{"ok":true}', b"")
            return original_command(argv, timeout)

        with patch.object(ghq_clean, "inspect", return_value=([row], 0, 0)), \
             patch.object(ghq_clean, "metadata_for", return_value={"example/sample": meta}), \
             patch.object(ghq_clean, "read_orca_setups", side_effect=[[setup], [], []]), \
             patch.object(ghq_clean, "command", side_effect=fake_command), \
             patch.object(ghq_clean.sys.stdin, "isatty", return_value=True), \
             patch("builtins.input", return_value="REMOVE 1"):
            status = ghq_clean.apply_rows([row], self.ghq, 14, 86400, self.cache)
        self.assertEqual(status, 0)
        self.assertFalse(self.repo.exists())
        self.assertEqual(len(calls), 1)
        self.assertIn("setup-1", calls[0])
        self.assertEqual(calls[0][calls[0].index("--host") + 1], "local")
        self.assertNotIn("--force", calls[0])

    def test_apply_fixture_preserves_clone_when_orca_refuses(self) -> None:
        current = int(__import__("time").time())
        local = ghq_clean.snapshot_repo(self.repo)
        meta = ghq_clean.Metadata("fresh", True, current - 86400, current)
        setup = ghq_clean.Setup("setup-1", str(self.repo), "github:example/sample", "git", "local")
        row = ghq_clean.Row(local, meta, "candidate", "remote archived", setup)
        original_command = ghq_clean.command

        def fake_command(argv, timeout=30):
            if argv[:3] == ["orca", "project", "setup-delete"]:
                return subprocess.CompletedProcess(argv, 1, b"", b"refused")
            return original_command(argv, timeout)

        with patch.object(ghq_clean, "inspect", return_value=([row], 0, 0)), \
             patch.object(ghq_clean, "metadata_for", return_value={"example/sample": meta}), \
             patch.object(ghq_clean, "read_orca_setups", return_value=[setup]), \
             patch.object(ghq_clean, "command", side_effect=fake_command), \
             patch.object(ghq_clean.sys.stdin, "isatty", return_value=True), \
             patch("builtins.input", return_value="REMOVE 1"):
            status = ghq_clean.apply_rows([row], self.ghq, 14, 86400, self.cache)
        self.assertEqual(status, 1)
        self.assertTrue(self.repo.exists())

    def test_apply_aborts_if_remote_metadata_changes_after_confirmation(self) -> None:
        current = int(__import__("time").time())
        local = ghq_clean.snapshot_repo(self.repo)
        old = ghq_clean.Row(local, ghq_clean.Metadata("fresh", True, current - 86400, current), "candidate", "remote archived")
        changed = ghq_clean.Row(local, ghq_clean.Metadata("fresh", True, current - 172800, current), "candidate", "remote archived")
        with patch.object(ghq_clean, "inspect", return_value=([changed], 0, 0)), \
             patch.object(ghq_clean, "metadata_for", return_value={"example/sample": changed.metadata}), \
             patch.object(ghq_clean.sys.stdin, "isatty", return_value=True), \
             patch("builtins.input", return_value="REMOVE 1"):
            status = ghq_clean.apply_rows([old], self.ghq, 14, 86400, self.cache)
        self.assertEqual(status, 2)
        self.assertTrue(self.repo.exists())

    def test_apply_aborts_if_same_timestamp_amend_changes_head_or_refs(self) -> None:
        current = int(__import__("time").time())
        old_local = ghq_clean.snapshot_repo(self.repo)
        meta = ghq_clean.Metadata("fresh", True, current - 86400, current)
        old = ghq_clean.Row(old_local, meta, "candidate", "remote archived")
        amended_state = []
        real_inspect = ghq_clean.inspect

        def amend_then_inspect(root, days, ttl_seconds, cache_path, **kwargs):
            timestamp = dt.datetime.fromtimestamp(old_local.latest_commit, tz=dt.timezone.utc).isoformat()
            env = os.environ.copy()
            env.update({"GIT_AUTHOR_DATE": timestamp, "GIT_COMMITTER_DATE": timestamp})
            git(self.repo, "commit", "--amend", "--quiet", "-m", "same timestamp amendment", env=env)
            kwargs["metadata_override"] = {"example/sample": meta}
            rows, linked_count, nonrepo_count = real_inspect(root, days, ttl_seconds, cache_path, **kwargs)
            amended_state.append(rows[0].local)
            return rows, linked_count, nonrepo_count

        with patch.object(ghq_clean, "metadata_for", return_value={"example/sample": meta}), \
             patch.object(ghq_clean, "inspect", side_effect=amend_then_inspect), \
             patch.object(ghq_clean, "read_orca_setups", return_value=[]), \
             patch.object(ghq_clean.sys.stdin, "isatty", return_value=True), \
             patch("builtins.input", return_value="REMOVE 1"):
            status = ghq_clean.apply_rows([old], self.ghq, 14, 86400, self.cache)
        self.assertEqual(status, 2)
        self.assertEqual(old_local.latest_commit, amended_state[0].latest_commit)
        self.assertEqual(old_local.local_only_commits, amended_state[0].local_only_commits)
        self.assertEqual(old_local.upstreamless_branches, amended_state[0].upstreamless_branches)
        self.assertNotEqual(old_local.head_oid, amended_state[0].head_oid)
        self.assertNotEqual(old_local.ref_oids, amended_state[0].ref_oids)
        self.assertTrue(self.repo.exists())

    def test_final_orca_readback_cannot_hide_a_concurrent_same_timestamp_amend(self) -> None:
        current = int(__import__("time").time())
        old_local = ghq_clean.snapshot_repo(self.repo)
        meta = ghq_clean.Metadata("fresh", True, current - 86400, current)
        row = ghq_clean.Row(old_local, meta, "candidate", "remote archived")
        calls = 0

        def read_setups_with_amend():
            nonlocal calls
            calls += 1
            if calls == 2:
                timestamp = dt.datetime.fromtimestamp(old_local.latest_commit, tz=dt.timezone.utc).isoformat()
                env = os.environ.copy()
                env.update({"GIT_AUTHOR_DATE": timestamp, "GIT_COMMITTER_DATE": timestamp})
                git(self.repo, "commit", "--amend", "--quiet", "-m", "during final Orca readback", env=env)
            return []

        with patch.object(ghq_clean, "inspect", return_value=([row], 0, 0)), \
             patch.object(ghq_clean, "metadata_for", return_value={"example/sample": meta}), \
             patch.object(ghq_clean, "read_orca_setups", side_effect=read_setups_with_amend), \
             patch.object(ghq_clean.sys.stdin, "isatty", return_value=True), \
             patch("builtins.input", return_value="REMOVE 1"):
            status = ghq_clean.apply_rows([row], self.ghq, 14, 86400, self.cache)
        self.assertEqual(status, 1)
        self.assertEqual(calls, 2)
        self.assertTrue(self.repo.exists())

    def test_apply_aborts_when_forced_metadata_refresh_is_stale(self) -> None:
        current = int(__import__("time").time())
        local = ghq_clean.snapshot_repo(self.repo)
        meta = ghq_clean.Metadata("fresh", True, current - 86400, current)
        row = ghq_clean.Row(local, meta, "candidate", "remote archived")
        stale = ghq_clean.Metadata("stale", True, current - 86400, current - 7200, "refresh failed")
        with patch.object(ghq_clean, "metadata_for", return_value={"example/sample": stale}), \
             patch.object(ghq_clean, "inspect", side_effect=AssertionError("stale refresh must abort before inspect")), \
             patch.object(ghq_clean.sys.stdin, "isatty", return_value=True), \
             patch("builtins.input", return_value="REMOVE 1"):
            status = ghq_clean.apply_rows([row], self.ghq, 14, 86400, self.cache)
        self.assertEqual(status, 2)
        self.assertTrue(self.repo.exists())

    def test_default_dry_run_does_not_enter_apply_path(self) -> None:
        local = ghq_clean.snapshot_repo(self.repo)
        row = ghq_clean.Row(local, self.metadata(archived=True), "candidate", "remote archived")
        with patch.object(ghq_clean, "inspect", return_value=([row], 0, 0)), \
             patch.object(ghq_clean, "apply_rows", side_effect=AssertionError("dry-run called apply")):
            status = ghq_clean.main(["--ghq-root", str(self.ghq), "--cache", str(self.cache)])
        self.assertEqual(status, 0)
        self.assertTrue(self.repo.exists())


if __name__ == "__main__":
    unittest.main()

