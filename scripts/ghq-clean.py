#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gh_extensions  # noqa: E402

CACHE_VERSION = 1
DEFAULT_DAYS = 14
GH_EXTENSION_DIR = gh_extensions.DEFAULT_DIR
DEFAULT_TTL_SECONDS = 24 * 60 * 60
MAX_ALIASES = 25
APPLY_METADATA_MAX_AGE = 5 * 60
SLUG_COMPONENT = re.compile(r"^[A-Za-z0-9_.-]+$")


class ScanError(RuntimeError):
    pass


@dataclass(frozen=True)
class Metadata:
    state: str
    archived: bool | None = None
    pushed_at: int | None = None
    fetched_at: int | None = None
    detail: str = ""


@dataclass(frozen=True)
class LocalState:
    path: Path
    slug: str | None
    dirty: bool | None
    linked_worktrees: tuple[str, ...]
    local_only_commits: int | None
    upstreamless_branches: tuple[str, ...]
    latest_commit: int | None
    device: int | None
    inode: int | None
    error: str = ""
    head_oid: str | None = None
    ref_oids: tuple[str, ...] = ()


@dataclass(frozen=True)
class Row:
    local: LocalState
    metadata: Metadata | None
    state: str
    reason: str


def command(argv: list[str], timeout: int = 30) -> subprocess.CompletedProcess[bytes]:
    try:
        return subprocess.run(
            argv,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise ScanError(f"{argv[0]} unavailable or timed out") from exc


def command_text(argv: list[str], timeout: int = 30) -> str:
    result = command(argv, timeout)
    if result.returncode != 0:
        raise ScanError(f"{argv[0]} failed (exit {result.returncode})")
    return result.stdout.decode("utf-8", "replace").strip()


def parse_slug(remote: str) -> str | None:
    remote = remote.strip()
    if remote.startswith("git@github.com:"):
        path = remote.removeprefix("git@github.com:")
    elif remote.startswith("ssh://git@github.com/"):
        path = remote.removeprefix("ssh://git@github.com/")
    else:
        parsed = urlsplit(remote)
        if parsed.scheme != "https" or (parsed.hostname or "").casefold() != "github.com":
            return None
        try:
            port = parsed.port
        except ValueError:
            return None
        if port not in (None, 443):
            return None
        path = parsed.path.lstrip("/")
    path = path.removesuffix(".git").strip("/")
    parts = path.split("/")
    if len(parts) != 2 or not all(SLUG_COMPONENT.fullmatch(part) for part in parts):
        return None
    return "/".join(parts)


def snapshot_repo(path: Path) -> LocalState:
    resolved = path.resolve(strict=False)
    git_marker = path / ".git"
    if path.is_symlink() or git_marker.is_symlink():
        return LocalState(path, None, None, (), None, (), None, None, None, "symlinked clone or .git marker")
    if not git_marker.is_dir():
        return LocalState(path, None, None, (), None, (), None, None, None, "not a canonical clone root")
    try:
        st = path.stat()
    except OSError:
        return LocalState(path, None, None, (), None, (), None, None, None, "cannot stat clone root")
    try:
        remote = command_text(["git", "-C", str(path), "remote", "get-url", "origin"])
        slug = parse_slug(remote)
        if slug is None:
            raise ScanError("origin is not a supported github.com URL")

        status = command(["git", "-C", str(path), "status", "--porcelain", "-z", "--untracked-files=all"])
        if status.returncode != 0:
            raise ScanError("git status failed")
        dirty = bool(status.stdout)

        count_text = command_text(["git", "-C", str(path), "rev-list", "--all", "--not", "--remotes", "--count"])
        if not count_text.isdecimal():
            raise ScanError("invalid local-only commit count")
        local_only = int(count_text)

        latest_text = command_text(["git", "-C", str(path), "log", "-1", "--format=%ct", "--all"])
        if not latest_text.isdecimal():
            raise ScanError("clone has no readable commit timestamp")
        latest_commit = int(latest_text)

        head_oid = command_text(["git", "-C", str(path), "rev-parse", "--verify", "HEAD"])
        if not re.fullmatch(r"[0-9a-fA-F]{40,64}", head_oid):
            raise ScanError("invalid HEAD object id")
        refs = command(["git", "-C", str(path), "for-each-ref", "--format=%(refname)%00%(objectname)"])
        if refs.returncode != 0:
            raise ScanError("git ref inventory failed")
        ref_oids = []
        for line in refs.stdout.splitlines():
            name, separator, oid = line.partition(b"\x00")
            oid = oid.strip()
            if not separator or not name or not re.fullmatch(rb"[0-9a-fA-F]{40,64}", oid):
                raise ScanError("invalid git ref inventory")
            ref_oids.append(f"{os.fsdecode(name)} {os.fsdecode(oid)}")

        refs = command(["git", "-C", str(path), "for-each-ref", "--format=%(refname:short)%00%(upstream:short)", "refs/heads"])
        if refs.returncode != 0:
            raise ScanError("git branch inventory failed")
        upstreamless = []
        for line in refs.stdout.splitlines():
            name, separator, upstream = line.partition(b"\x00")
            if separator and name and not upstream.rstrip(b"\n"):
                upstreamless.append(os.fsdecode(name))

        worktrees = command(["git", "-C", str(path), "worktree", "list", "--porcelain", "-z"])
        if worktrees.returncode != 0:
            raise ScanError("git worktree inventory failed")
        linked = []
        for record in worktrees.stdout.split(b"\x00\x00"):
            first = record.split(b"\x00", 1)[0]
            if not first.startswith(b"worktree "):
                continue
            listed = Path(os.fsdecode(first[len(b"worktree "):])).resolve(strict=False)
            if listed != resolved:
                linked.append(str(listed))

        return LocalState(
            path=resolved,
            slug=slug,
            dirty=dirty,
            linked_worktrees=tuple(sorted(set(linked))),
            local_only_commits=local_only,
            upstreamless_branches=tuple(sorted(upstreamless)),
            latest_commit=latest_commit,
            device=st.st_dev,
            inode=st.st_ino,
            head_oid=head_oid,
            ref_oids=tuple(sorted(ref_oids)),
        )
    except ScanError as exc:
        return LocalState(path, None, None, (), None, (), None, st.st_dev, st.st_ino, str(exc))


def discover_roots(root: Path) -> tuple[list[Path], int, int]:
    try:
        resolved_root = root.resolve(strict=True)
    except OSError as exc:
        raise ScanError(f"clone root unavailable: {root}") from exc
    if not resolved_root.is_dir():
        raise ScanError(f"clone root is not a directory: {root}")

    roots: list[Path] = []
    linked_count = 0
    nonrepo_count = 0
    try:
        owners = sorted(resolved_root.iterdir())
    except OSError as exc:
        raise ScanError(f"cannot enumerate clone root: {resolved_root}") from exc
    for owner in owners:
        try:
            owner_mode = owner.lstat().st_mode
        except OSError as exc:
            raise ScanError(f"cannot inspect inventory entry: {owner}") from exc
        if stat.S_ISLNK(owner_mode):
            raise ScanError(f"symlinked owner entry: {owner}")
        if not stat.S_ISDIR(owner_mode):
            continue
        try:
            repos = sorted(owner.iterdir())
        except OSError as exc:
            raise ScanError(f"cannot enumerate owner directory: {owner}") from exc
        for repo in repos:
            try:
                repo_mode = repo.lstat().st_mode
            except OSError as exc:
                raise ScanError(f"cannot inspect inventory entry: {repo}") from exc
            if stat.S_ISLNK(repo_mode):
                raise ScanError(f"symlinked repo entry: {repo}")
            if not stat.S_ISDIR(repo_mode):
                continue
            git_path = repo / ".git"
            try:
                git_mode = git_path.lstat().st_mode
            except FileNotFoundError:
                nonrepo_count += 1
                continue
            except OSError as exc:
                raise ScanError(f"cannot inspect git marker: {git_path}") from exc
            if stat.S_ISLNK(git_mode):
                raise ScanError(f"symlinked .git marker: {git_path}")
            if stat.S_ISREG(git_mode):
                linked_count += 1
                continue
            if not stat.S_ISDIR(git_mode):
                nonrepo_count += 1
                continue
            if repo.resolve(strict=False).parent.parent != resolved_root:
                nonrepo_count += 1
                continue
            roots.append(repo)
    return roots, linked_count, nonrepo_count


def cache_load(path: Path) -> dict[str, dict]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    if not isinstance(data, dict) or data.get("version") != CACHE_VERSION or not isinstance(data.get("repos"), dict):
        return {}
    repos = {}
    for slug, item in data["repos"].items():
        if not isinstance(slug, str) or not isinstance(item, dict):
            continue
        fetched_at = item.get("fetchedAt")
        if not isinstance(fetched_at, int) or isinstance(fetched_at, bool) or fetched_at <= 0:
            continue
        if item.get("found") == "error":
            retry_after = item.get("retryAfter")
            if not isinstance(retry_after, int) or isinstance(retry_after, bool) or retry_after <= 0:
                continue
        elif item.get("found") is True:
            archived = item.get("archived")
            pushed_at = item.get("pushedAt")
            name = item.get("nameWithOwner")
            if (
                not isinstance(archived, bool)
                or (pushed_at is not None and (not isinstance(pushed_at, int) or isinstance(pushed_at, bool) or pushed_at <= 0))
                or not isinstance(name, str)
                or name.casefold() != slug.casefold()
            ):
                continue
        elif item.get("found") is not False:
            continue
        repos[slug.casefold()] = item
    return repos


def cache_save(path: Path, repos: dict[str, dict]) -> None:
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=".ghq-metadata-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump({"version": CACHE_VERSION, "repos": repos}, stream, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp_name, path)
    finally:
        try:
            os.unlink(temp_name)
        except FileNotFoundError:
            pass


def graphql_batch(slugs: list[str]) -> dict[str, dict | None]:
    fields = []
    aliases: dict[str, str] = {}
    for index, slug in enumerate(slugs):
        owner, name = slug.split("/", 1)
        alias = f"r{index}"
        aliases[alias] = slug.casefold()
        fields.append(f'{alias}: repository(owner: "{owner}", name: "{name}") {{ nameWithOwner isArchived pushedAt }}')
    query = "query {\n" + "\n".join(fields) + "\n}"
    output = command_text(["gh", "api", "graphql", "-f", f"query={query}"], timeout=45)
    try:
        payload = json.loads(output)
    except json.JSONDecodeError as exc:
        raise ScanError("GitHub returned invalid GraphQL JSON") from exc
    if not isinstance(payload, dict) or payload.get("errors"):
        raise ScanError("GitHub GraphQL metadata query failed")
    data = payload.get("data")
    if not isinstance(data, dict):
        raise ScanError("GitHub GraphQL response omitted data")
    result = {}
    for alias, slug_key in aliases.items():
        value = data.get(alias)
        if value is None:
            result[slug_key] = None
            continue
        if not isinstance(value, dict):
            raise ScanError("GitHub GraphQL response has invalid repository metadata")
        name_with_owner = value.get("nameWithOwner")
        archived = value.get("isArchived")
        pushed = value.get("pushedAt")
        if not isinstance(name_with_owner, str) or name_with_owner.casefold() != slug_key:
            raise ScanError("GitHub repository identity changed or is ambiguous")
        if not isinstance(archived, bool) or "pushedAt" not in value or (pushed is not None and not isinstance(pushed, str)):
            raise ScanError("GitHub GraphQL response omitted age metadata")
        result[slug_key] = {
            "found": True,
            "nameWithOwner": name_with_owner,
            "archived": archived,
            "pushedAt": parse_iso_timestamp(pushed) if pushed is not None else None,
        }
    return result


def parse_iso_timestamp(value: str) -> int:
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            raise ValueError
        return int(parsed.astimezone(dt.timezone.utc).timestamp())
    except (TypeError, ValueError, OverflowError) as exc:
        raise ScanError("GitHub returned an invalid pushedAt timestamp") from exc


def metadata_for(
    slugs: list[str],
    cache_path: Path,
    ttl_seconds: int,
    now: int,
    force: bool = False,
    refresh_stale: bool = True,
) -> dict[str, Metadata]:
    cache = cache_load(cache_path)
    unique = {slug.casefold(): slug for slug in slugs}
    result: dict[str, Metadata] = {}
    needed = []
    for key, display_slug in unique.items():
        item = cache.get(key)
        age = now - item["fetchedAt"] if item else None
        if not force and item and age is not None and 0 <= age <= ttl_seconds:
            if item.get("found") == "error":
                result[key] = Metadata("unknown", fetched_at=item["fetchedAt"], detail="metadata retry cooldown")
            elif item.get("found") is False:
                result[key] = Metadata("unknown", fetched_at=item["fetchedAt"], detail="remote missing or inaccessible")
            else:
                result[key] = Metadata("fresh", item["archived"], item["pushedAt"], item["fetchedAt"])
        elif (
            not force
            and item
            and isinstance(item.get("retryAfter"), int)
            and not isinstance(item.get("retryAfter"), bool)
            and now < item["retryAfter"]
        ):
            if item.get("found") is True:
                result[key] = Metadata(
                    "stale",
                    item.get("archived"),
                    item.get("pushedAt"),
                    item.get("fetchedAt"),
                    "metadata retry cooldown",
                )
            else:
                result[key] = Metadata("unknown", fetched_at=item.get("fetchedAt"), detail="metadata retry cooldown")
        elif not force and not refresh_stale:
            if item:
                result[key] = Metadata(
                    "stale",
                    item.get("archived"),
                    item.get("pushedAt"),
                    item.get("fetchedAt"),
                    "metadata refresh failed",
                )
            else:
                result[key] = Metadata("unknown", detail="metadata refresh not attempted")
        else:
            needed.append(display_slug)

    updates: dict[str, dict] = {}
    for offset in range(0, len(needed), MAX_ALIASES):
        batch = needed[offset:offset + MAX_ALIASES]
        try:
            fetched = graphql_batch(batch)
        except ScanError as exc:
            for slug in batch:
                key = slug.casefold()
                cached = cache.get(key)
                if cached:
                    failure = dict(cached)
                else:
                    failure = {"fetchedAt": now, "found": "error"}
                failure["retryAfter"] = now + max(ttl_seconds, 3600)
                updates[key] = failure
                if cached:
                    result[key] = Metadata("stale", cached.get("archived"), cached.get("pushedAt"), cached.get("fetchedAt"), str(exc))
                else:
                    result[key] = Metadata("unknown", detail=str(exc))
            continue
        for slug in batch:
            key = slug.casefold()
            value = fetched.get(key)
            stored = {"fetchedAt": now, "found": value is not None}
            if value is not None:
                stored.update(value)
            updates[key] = stored

    if updates:
        try:
            cache.update(updates)
            cache_save(cache_path, cache)
        except OSError:
            for key in updates:
                result[key] = Metadata("unknown", detail="cannot persist metadata cache")
        else:
            for key, item in updates.items():
                if item.get("retryAfter", 0) > now:
                    continue
                if item["found"] == "error":
                    continue
                if item["found"] is False:
                    # A null GraphQL node can be a deleted or an inaccessible private repository.
                    result[key] = Metadata("unknown", fetched_at=now, detail="remote missing or inaccessible")
                else:
                    result[key] = Metadata("fresh", item["archived"], item["pushedAt"], now)
    return result


def read_extension_targets(directory: Path = GH_EXTENSION_DIR) -> frozenset[str]:
    try:
        return gh_extensions.symlink_targets(directory)
    except OSError as exc:
        raise ScanError(f"cannot enumerate gh extension directory: {directory}") from exc


def inspect_row(
    local: LocalState,
    metadata: Metadata | None,
    days: int,
    now: int,
    extension_targets: frozenset[str] | None = frozenset(),
    allow_unpushed: bool = False,
) -> Row:
    if local.error:
        return Row(local, metadata, "unknown", local.error)
    if extension_targets is None:
        return Row(local, metadata, "unknown", "gh extension inventory unavailable")
    if str(local.path.resolve(strict=False)) in extension_targets:
        return Row(local, metadata, "protected", "gh extension target")
    reasons = []
    if local.dirty:
        reasons.append("dirty")
    if local.linked_worktrees:
        reasons.append(f"linked_worktrees={len(local.linked_worktrees)}")
    if not allow_unpushed:
        if local.local_only_commits is None:
            return Row(local, metadata, "unknown", "local-only commit count unavailable")
        if local.local_only_commits > 0:
            reasons.append(f"local_only_commits={local.local_only_commits}")
        if local.upstreamless_branches:
            reasons.append(f"upstreamless_branches={len(local.upstreamless_branches)}")
    if reasons:
        return Row(local, metadata, "protected", ",".join(reasons))
    if local.slug is None:
        return Row(local, metadata, "unknown", "unsupported or missing origin")
    if metadata is None or metadata.state != "fresh":
        detail = metadata.detail if metadata and metadata.detail else "metadata unavailable"
        return Row(local, metadata, "unknown", detail)
    activity = max(local.latest_commit or 0, metadata.pushed_at or 0)
    age_seconds = now - activity
    age_days = max(0, age_seconds // 86400)
    if metadata.archived:
        return Row(local, metadata, "candidate", "remote archived")
    if age_seconds >= days * 86400:
        return Row(local, metadata, "candidate", f"no local commit or remote push for {age_days}d")
    return Row(local, metadata, "retained", f"recent activity ({age_days}d)")


def inspect(
    root: Path,
    days: int,
    ttl_seconds: int,
    cache_path: Path,
    force: bool = False,
    refresh_stale: bool = True,
    metadata_override: dict[str, Metadata] | None = None,
    allow_unpushed: bool = False,
) -> tuple[list[Row], int, int]:
    paths, linked_count, nonrepo_count = discover_roots(root)
    local = [snapshot_repo(path) for path in paths]
    slugs = [repo.slug for repo in local if repo.slug]
    if metadata_override is None:
        metadata = metadata_for(
            slugs, cache_path, ttl_seconds, int(time.time()), force=force, refresh_stale=refresh_stale
        )
    else:
        remaining = [slug for slug in slugs if slug.casefold() not in metadata_override]
        metadata = metadata_for(
            remaining, cache_path, ttl_seconds, int(time.time()), refresh_stale=False
        )
        metadata.update(metadata_override)
    try:
        extension_targets = read_extension_targets()
    except ScanError:
        extension_targets = None
    rows = [
        inspect_row(
            repo,
            metadata.get(repo.slug.casefold()) if repo.slug else None,
            days,
            int(time.time()),
            extension_targets,
            allow_unpushed,
        )
        for repo in local
    ]
    return rows, linked_count, nonrepo_count


def fingerprint(local: LocalState) -> tuple:
    return (
        str(local.path),
        local.slug,
        local.dirty,
        local.linked_worktrees,
        local.local_only_commits,
        local.upstreamless_branches,
        local.latest_commit,
        local.head_oid,
        local.ref_oids,
        local.device,
        local.inode,
        local.error,
    )


def print_rows(rows: list[Row], linked_count: int, nonrepo_count: int) -> None:
    for row in rows:
        local = row.local
        branches = ",".join(local.upstreamless_branches) or "-"
        commits = str(local.local_only_commits) if local.local_only_commits is not None else "unknown"
        print(
            f"{row.state}: {local.slug or 'origin-unknown'} path={local.path} "
            f"reason={row.reason} local_only_commits={commits} "
            f"upstreamless_branches={branches}"
        )
    counts = {state: sum(row.state == state for row in rows) for state in ("candidate", "retained", "protected", "unknown")}
    print(
        f"summary: clone_roots={len(rows)} linked_worktrees_excluded={linked_count} "
        f"non_git_dirs_excluded={nonrepo_count} candidates={counts['candidate']} "
        f"retained={counts['retained']} protected={counts['protected']} unknown={counts['unknown']}"
    )


def apply_rows(
    rows: list[Row],
    root: Path,
    days: int,
    ttl_seconds: int,
    cache_path: Path,
    allow_unpushed: bool = False,
) -> int:
    initial = {str(row.local.path): row for row in rows if row.state == "candidate"}
    if not initial:
        print("apply: no fresh safe candidates")
        return 0
    print("apply candidates:")
    for path, row in sorted(initial.items()):
        print(
            f"  {row.local.slug} reason={row.reason} "
            f"local_only_commits={row.local.local_only_commits} path={path}"
        )
    if not sys.stdin.isatty():
        print("apply refused: interactive confirmation required", file=sys.stderr)
        return 2
    expected = f"REMOVE {len(initial)}"
    if input(f"Type {expected} to continue: ").strip() != expected:
        print("apply cancelled")
        return 0

    candidate_slugs = [row.local.slug for row in initial.values() if row.local.slug]
    refreshed_metadata = metadata_for(candidate_slugs, cache_path, ttl_seconds, int(time.time()), force=True)
    if any(
        refreshed_metadata.get(slug.casefold()) is None
        or refreshed_metadata[slug.casefold()].state != "fresh"
        for slug in candidate_slugs
    ):
        print("apply aborted: forced remote metadata refresh was incomplete", file=sys.stderr)
        return 2
    fresh_rows, linked_count, nonrepo_count = inspect(
        root,
        days,
        ttl_seconds,
        cache_path,
        refresh_stale=False,
        metadata_override=refreshed_metadata,
        allow_unpushed=allow_unpushed,
    )
    refreshed = {str(row.local.path): row for row in fresh_rows if row.state == "candidate"}
    if set(refreshed) != set(initial):
        print_rows(fresh_rows, linked_count, nonrepo_count)
        print("apply aborted: candidate set changed during confirmation", file=sys.stderr)
        return 2
    for path, old in initial.items():
        current = refreshed[path]
        old_metadata = old.metadata
        new_metadata = current.metadata
        metadata_changed = (
            old_metadata is None
            or new_metadata is None
            or (old_metadata.archived, old_metadata.pushed_at) != (new_metadata.archived, new_metadata.pushed_at)
        )
        if (
            fingerprint(current.local) != fingerprint(old.local)
            or current.reason != old.reason
            or metadata_changed
        ):
            print(f"apply aborted: candidate changed during confirmation ({path})", file=sys.stderr)
            return 2

    result = 0
    for path, old in sorted(initial.items()):
        current = refreshed[path]
        if fingerprint(current.local) != fingerprint(old.local):
            print(f"skip {current.local.slug}: local state changed after review")
            result = 1
            continue
        if current.metadata is None or current.metadata.state != "fresh" or current.metadata.fetched_at is None:
            print(f"skip {current.local.slug}: fresh remote metadata unavailable")
            result = 1
            continue
        if int(time.time()) - current.metadata.fetched_at > APPLY_METADATA_MAX_AGE:
            print(f"skip {current.local.slug}: remote metadata exceeded apply freshness window")
            result = 1
            continue

        latest_local = snapshot_repo(current.local.path)
        if fingerprint(latest_local) != fingerprint(current.local):
            print(f"partial {current.local.slug}: local state changed; clone retained")
            result = 1
            continue
        if not current.local.path.is_dir() or current.local.path.is_symlink():
            print(f"skip {current.local.slug}: clone path changed")
            result = 1
            continue
        try:
            resolved_root = root.resolve(strict=True)
            resolved_path = current.local.path.resolve(strict=True)
            if resolved_path.parent.parent != resolved_root or resolved_path == resolved_root:
                raise ScanError("clone path escaped ghq root")
            st = resolved_path.stat()
            if (st.st_dev, st.st_ino) != (current.local.device, current.local.inode):
                raise ScanError("clone directory identity changed")
            if (resolved_path / ".git").is_symlink() or not (resolved_path / ".git").is_dir():
                raise ScanError("clone is no longer a canonical clone")
            shutil.rmtree(resolved_path)
        except (OSError, ScanError) as exc:
            print(f"partial {current.local.slug}: clone retained or partially removed ({exc})")
            result = 1
            continue
        print(
            f"removed {current.local.slug} local_only_commits={current.local.local_only_commits} "
            f"upstreamless_branches={len(current.local.upstreamless_branches)}"
        )
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Inventory and explicitly retire stale ghq clone roots.")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true", help="report only (default)")
    mode.add_argument("--apply", action="store_true", help="interactively remove reviewed candidates")
    parser.add_argument("--days", type=int, default=DEFAULT_DAYS)
    parser.add_argument("--cache-ttl-hours", type=int, default=24)
    parser.add_argument("--ghq-root", type=Path, default=Path.home() / "ghq" / "github.com")
    parser.add_argument("--cache", type=Path, default=Path.home() / ".cache" / "ghq-clean" / "metadata.json")
    parser.add_argument(
        "--allow-unpushed",
        action="store_true",
        help="treat clones with local-only commits or upstreamless branches as candidates",
    )
    args = parser.parse_args(argv)
    if args.days < 1 or args.cache_ttl_hours < 1:
        parser.error("--days and --cache-ttl-hours must be positive integers")
    try:
        rows, linked_count, nonrepo_count = inspect(
            args.ghq_root, args.days, args.cache_ttl_hours * 3600, args.cache, allow_unpushed=args.allow_unpushed
        )
    except ScanError as exc:
        print(f"ghq-clean: {exc}", file=sys.stderr)
        return 2
    print_rows(rows, linked_count, nonrepo_count)
    if args.apply:
        return apply_rows(
            rows, args.ghq_root, args.days, args.cache_ttl_hours * 3600, args.cache, allow_unpushed=args.allow_unpushed
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

