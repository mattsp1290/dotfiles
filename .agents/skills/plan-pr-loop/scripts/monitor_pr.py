#!/usr/bin/env python3
"""Poll one GitHub PR at a fixed cadence and exit when its canonical fingerprint changes."""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import subprocess
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, TextIO


PR_FIELDS = (
    "number,state,url,title,isDraft,baseRefName,baseRefOid,headRefName,headRefOid,"
    "mergeable,mergeStateStatus,reviewDecision,statusCheckRollup,reviewRequests,updatedAt,mergedAt,mergeCommit"
)


def run_json(command: list[str]) -> Any:
    result = subprocess.run(command, text=True, capture_output=True, check=False)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"command failed: {command[0]}")
    return json.loads(result.stdout)


def body_digest(item: dict[str, Any]) -> str:
    return hashlib.sha256(str(item.get("body", "")).encode("utf-8")).hexdigest()


def paginated_items(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list):
        raise RuntimeError("paginated GitHub response is not a list")
    flattened: list[Any] = []
    for item in value:
        flattened.extend(item if isinstance(item, list) else [item])
    if not all(isinstance(item, dict) for item in flattened):
        raise RuntimeError("paginated GitHub response contains a non-object")
    return flattened


def normalized_comments(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(
        (
            {
                "id": item.get("id"),
                "updated_at": item.get("updated_at"),
                "body_digest": body_digest(item),
            }
            for item in items
        ),
        key=lambda item: str(item["id"]),
    )


def normalized_reviews(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(
        (
            {
                "id": item.get("id"),
                "submitted_at": item.get("submitted_at"),
                "state": item.get("state"),
                "body_digest": body_digest(item),
            }
            for item in items
        ),
        key=lambda item: str(item["id"]),
    )


def snapshot(gh: str, repository: str, pr_number: int) -> dict[str, Any]:
    prefix = [gh]
    pr = run_json(prefix + ["pr", "view", str(pr_number), "--repo", repository, "--json", PR_FIELDS])
    issue_comments = paginated_items(
        run_json(prefix + ["api", "--paginate", "--slurp", f"repos/{repository}/issues/{pr_number}/comments"])
    )
    reviews = paginated_items(
        run_json(prefix + ["api", "--paginate", "--slurp", f"repos/{repository}/pulls/{pr_number}/reviews"])
    )
    review_comments = paginated_items(
        run_json(prefix + ["api", "--paginate", "--slurp", f"repos/{repository}/pulls/{pr_number}/comments"])
    )
    return {
        "pr": pr,
        "issue_comments": normalized_comments(issue_comments),
        "reviews": normalized_reviews(reviews),
        "review_comments": normalized_comments(review_comments),
    }


def fingerprint(value: dict[str, Any]) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def emit(event: str, **fields: Any) -> None:
    print(json.dumps({"event": event, **fields}, sort_keys=True), flush=True)


def write_monitor_owner(path: Path, value: dict[str, Any]) -> None:
    temporary_name: str | None = None
    try:
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path, delete=False) as handle:
            temporary_name = handle.name
            json.dump(value, handle, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_name, path / "owner.json")
    finally:
        if temporary_name and os.path.exists(temporary_name):
            os.unlink(temporary_name)


def claim_monitor_lock(
    monitor_lock: Path,
    repository: str,
    pr_number: int,
    recovery_evidence_digest: str | None,
) -> TextIO | None:
    coordinator = monitor_lock.with_name(f".{monitor_lock.name}.coord")
    with coordinator.open("a+", encoding="utf-8") as handle:
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
        if monitor_lock.exists():
            owner_path = monitor_lock / "owner.json"
            lease_path = monitor_lock / "lease.lock"
            try:
                owner = json.loads(owner_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                owner = {}
            stale_lease = lease_path.open("a+", encoding="utf-8")
            try:
                fcntl.flock(stale_lease.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                stale_lease.close()
                emit("monitor-overlap", lock=str(monitor_lock), owner_pid=owner.get("pid"))
                return None
            if not recovery_evidence_digest:
                stale_lease.close()
                emit("monitor-stale", lock=str(monitor_lock), owner_pid=owner.get("pid"))
                return None
            if owner:
                if owner.get("repo") != repository or owner.get("pr_number") != pr_number:
                    stale_lease.close()
                    emit("monitor-recovery-target-mismatch", lock=str(monitor_lock))
                    return None
            try:
                if owner_path.exists():
                    os.unlink(owner_path)
                os.unlink(lease_path)
                os.rmdir(monitor_lock)
            except OSError:
                stale_lease.close()
                emit("monitor-stale-cleanup-failed", lock=str(monitor_lock))
                return None
            stale_lease.close()
        os.mkdir(monitor_lock, 0o700)
        lease = (monitor_lock / "lease.lock").open("a+", encoding="utf-8")
        fcntl.flock(lease.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        write_monitor_owner(
            monitor_lock,
            {
                "pid": os.getpid(),
                "repo": repository,
                "pr_number": pr_number,
                "started_at": datetime.now(timezone.utc).isoformat(),
                "stale_recovery_evidence_digest": recovery_evidence_digest,
            },
        )
        return lease


def release_monitor_lock(monitor_lock: Path, lease: TextIO) -> None:
    coordinator = monitor_lock.with_name(f".{monitor_lock.name}.coord")
    try:
        with coordinator.open("a+", encoding="utf-8") as handle:
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
            owner = json.loads((monitor_lock / "owner.json").read_text(encoding="utf-8"))
            if owner.get("pid") == os.getpid():
                os.unlink(monitor_lock / "owner.json")
                os.unlink(monitor_lock / "lease.lock")
                os.rmdir(monitor_lock)
    except (OSError, json.JSONDecodeError):
        pass
    finally:
        fcntl.flock(lease.fileno(), fcntl.LOCK_UN)
        lease.close()


def is_terminal(value: dict[str, Any]) -> bool:
    pr = value["pr"]
    return pr.get("state") != "OPEN" or pr.get("mergedAt") is not None or pr.get("mergeCommit") is not None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--pr-number", required=True, type=int)
    parser.add_argument("--monitor-lock")
    parser.add_argument("--gh", default="gh")
    parser.add_argument("--interval-seconds", type=float, default=300.0)
    parser.add_argument("--max-ticks", type=int)
    parser.add_argument("--expected-fingerprint")
    parser.add_argument("--snapshot-only", action="store_true")
    parser.add_argument("--stale-monitor-recovery-evidence-digest")
    args = parser.parse_args()
    if args.pr_number < 1 or args.interval_seconds <= 0:
        parser.error("pr-number and interval-seconds must be positive")

    if args.snapshot_only:
        try:
            current = snapshot(args.gh, args.repo, args.pr_number)
        except (OSError, RuntimeError, json.JSONDecodeError) as exc:
            emit(
                "monitor-provider-failure",
                count=1,
                error_digest=hashlib.sha256(str(exc).encode()).hexdigest(),
            )
            return 3
        emit(
            "monitor-snapshot",
            repo=args.repo,
            pr_number=args.pr_number,
            fingerprint=fingerprint(current),
            terminal=is_terminal(current),
        )
        return 0
    if not args.monitor_lock:
        parser.error("--monitor-lock is required unless --snapshot-only is used")

    monitor_lock = Path(args.monitor_lock).expanduser().resolve()
    monitor_lock.parent.mkdir(parents=True, exist_ok=True)
    monitor_lease = claim_monitor_lock(
        monitor_lock,
        args.repo,
        args.pr_number,
        args.stale_monitor_recovery_evidence_digest,
    )
    if monitor_lease is None:
        return 4

    try:
        baseline_fingerprint = args.expected_fingerprint
        failures = 0
        ticks = 0
        while True:
            try:
                current = snapshot(args.gh, args.repo, args.pr_number)
            except (OSError, RuntimeError, json.JSONDecodeError) as exc:
                failures += 1
                emit(
                    "monitor-provider-failure",
                    count=failures,
                    error_digest=hashlib.sha256(str(exc).encode()).hexdigest(),
                )
                if failures >= 3:
                    return 3
                time.sleep(args.interval_seconds)
                ticks += 1
                continue
            current_fingerprint = fingerprint(current)
            if baseline_fingerprint is not None and current_fingerprint != baseline_fingerprint:
                emit(
                    "monitor-change",
                    old_fingerprint=baseline_fingerprint,
                    new_fingerprint=current_fingerprint,
                    ticks=ticks,
                    reason="changed-before-monitor-start",
                )
                return 0
            if is_terminal(current):
                emit(
                    "monitor-change",
                    old_fingerprint=baseline_fingerprint or current_fingerprint,
                    new_fingerprint=current_fingerprint,
                    ticks=ticks,
                    reason="terminal-at-monitor-start",
                )
                return 0
            baseline_fingerprint = current_fingerprint
            emit(
                "monitor-started",
                repo=args.repo,
                pr_number=args.pr_number,
                cadence_seconds=args.interval_seconds,
                fingerprint=baseline_fingerprint,
            )
            break
        while args.max_ticks is None or ticks < args.max_ticks:
            time.sleep(args.interval_seconds)
            ticks += 1
            try:
                current_fingerprint = fingerprint(snapshot(args.gh, args.repo, args.pr_number))
            except (OSError, RuntimeError, json.JSONDecodeError) as exc:
                failures += 1
                emit("monitor-provider-failure", count=failures, error_digest=hashlib.sha256(str(exc).encode()).hexdigest())
                if failures >= 3:
                    return 3
                continue
            failures = 0
            if current_fingerprint != baseline_fingerprint:
                emit(
                    "monitor-change",
                    old_fingerprint=baseline_fingerprint,
                    new_fingerprint=current_fingerprint,
                    ticks=ticks,
                )
                return 0
            emit("monitor-unchanged", fingerprint=current_fingerprint, ticks=ticks)
        return 5
    finally:
        release_monitor_lock(monitor_lock, monitor_lease)


if __name__ == "__main__":
    raise SystemExit(main())
