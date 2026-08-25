from __future__ import annotations

import argparse
import os
import tempfile
import uuid
from pathlib import Path
from typing import Any, cast

from pr_loop_model import (
    HelperError,
    require,
    utc_now,
    validate_state,
)
from pr_loop_store import atomic_write_json, exclusive_file_lock, fsync_directory, read_json

def require_lock_args(args: argparse.Namespace) -> Path:
    require(args.lock is not None, "--lock is required")
    return Path(args.lock).expanduser().resolve()


def verify_owner(lock_path: Path, owner_token: str | None) -> dict[str, Any]:
    require(owner_token is not None and owner_token, "--owner-token is required")
    owner = read_json(lock_path / "owner.json")
    require(owner.get("owner_token") == owner_token, "repository lock owner mismatch", 3)
    return owner


def verify_live_lease_locked(lock_path: Path, args: argparse.Namespace) -> dict[str, Any]:
    require(args.executor_id is not None and args.executor_id, "--executor-id is required")
    require(args.fencing_token is not None, "--fencing-token is required")
    verify_owner(lock_path, args.owner_token)
    lease_path = lock_path / "executor" / "lease.json"
    require(lease_path.is_file(), "live executor lease required", 3)
    lease = read_json(lease_path)
    require(lease.get("owner_token") == args.owner_token, "lease owner mismatch", 3)
    require(lease.get("executor_id") == args.executor_id, "executor ID mismatch", 3)
    require(lease.get("fencing_token") == args.fencing_token, "fencing token mismatch", 3)
    return lease


def command_lock_init(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    lock_path = require_lock_args(args)
    for name, value in (
        ("owner-token", args.owner_token),
        ("repository-id", args.repository_id),
        ("stable-plan-id", args.stable_plan_id),
        ("plan-digest", args.plan_digest),
    ):
        require(isinstance(value, str) and value, f"--{name} is required")
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    owner = {
        "owner_token": args.owner_token,
        "repository_id": args.repository_id,
        "stable_plan_id": args.stable_plan_id,
        "plan_digest": args.plan_digest,
        "goal_id": args.goal_id,
        "created_at": utc_now(),
    }
    if not lock_path.exists():
        temporary_path = Path(tempfile.mkdtemp(prefix=f".{lock_path.name}.init-", dir=lock_path.parent))
        try:
            atomic_write_json(temporary_path / "owner.json", owner)
            atomic_write_json(temporary_path / "fence.json", {"last_token": 0})
            fsync_directory(temporary_path)
            try:
                os.rename(temporary_path, lock_path)
                fsync_directory(lock_path.parent)
                return {"ok": True, "created": True, "plan_digest_matches": True}
            except OSError as exc:
                if not lock_path.exists():
                    raise HelperError(f"cannot publish repository owner lock: {exc}", 5) from exc
        finally:
            if temporary_path.exists():
                for child in temporary_path.iterdir():
                    if child.is_file():
                        os.unlink(child)
                os.rmdir(temporary_path)

    owner_path = lock_path / "owner.json"
    fence_path = lock_path / "fence.json"
    if not owner_path.is_file() or not fence_path.is_file():
        recovery_digest = payload.get("incomplete_lock_recovery_evidence_digest")
        require(
            isinstance(recovery_digest, str) and recovery_digest,
            "incomplete owner lock requires recovery evidence",
            3,
        )
        with exclusive_file_lock(lock_path / ".mutex", create_parent=False):
            if owner_path.is_file() and fence_path.is_file():
                current_owner = verify_owner(lock_path, args.owner_token)
                require(current_owner.get("repository_id") == args.repository_id, "repository identity mismatch", 3)
                require(current_owner.get("stable_plan_id") == args.stable_plan_id, "another plan owns this repository", 3)
                return {
                    "ok": True,
                    "created": False,
                    "plan_digest_matches": current_owner.get("plan_digest") == args.plan_digest,
                    "stored_plan_digest": current_owner.get("plan_digest"),
                }
            require(not (lock_path / "executor").exists(), "incomplete owner lock has executor state", 3)
            unexpected = {child.name for child in lock_path.iterdir()} - {".mutex", "owner.json", "fence.json"}
            require(not unexpected, "incomplete owner lock has unexpected contents", 3)
            if owner_path.is_file():
                partial_owner = read_json(owner_path)
                require(partial_owner.get("owner_token") == args.owner_token, "incomplete lock owner mismatch", 3)
                require(partial_owner.get("repository_id") == args.repository_id, "repository identity mismatch", 3)
                require(partial_owner.get("stable_plan_id") == args.stable_plan_id, "another plan owns this repository", 3)
                owner = partial_owner
            else:
                atomic_write_json(owner_path, owner)
            if fence_path.is_file():
                partial_fence = read_json(fence_path)
                require(partial_fence.get("last_token") == 0, "incomplete owner lock has an advanced fence", 3)
            else:
                atomic_write_json(fence_path, {"last_token": 0})
        return {
            "ok": True,
            "created": False,
            "recovered": True,
            "plan_digest_matches": owner.get("plan_digest") == args.plan_digest,
            "stored_plan_digest": owner.get("plan_digest"),
        }

    with exclusive_file_lock(lock_path / ".mutex", create_parent=False):
        owner = verify_owner(lock_path, args.owner_token)
        require(owner.get("repository_id") == args.repository_id, "repository identity mismatch", 3)
        require(owner.get("stable_plan_id") == args.stable_plan_id, "another plan owns this repository", 3)
        return {
            "ok": True,
            "created": False,
            "plan_digest_matches": owner.get("plan_digest") == args.plan_digest,
            "stored_plan_digest": owner.get("plan_digest"),
        }


def command_lease_acquire(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    lock_path = require_lock_args(args)
    require(args.executor_id is not None and args.executor_id, "--executor-id is required")
    with exclusive_file_lock(lock_path / ".mutex", create_parent=False):
        verify_owner(lock_path, args.owner_token)
        executor_path = lock_path / "executor"
        try:
            os.mkdir(executor_path, 0o700)
        except FileExistsError as exc:
            raise HelperError("executor lease already held", 3) from exc
        except OSError as exc:
            raise HelperError(f"cannot acquire executor lease: {exc}", 5) from exc

        fence = read_json(lock_path / "fence.json")
        last_token = fence.get("last_token")
        require(isinstance(last_token, int) and last_token >= 0, "invalid fence counter")
        last_token = cast(int, last_token)
        token = last_token + 1
        atomic_write_json(lock_path / "fence.json", {"last_token": token})
        atomic_write_json(
            executor_path / "lease.json",
            {
                "owner_token": args.owner_token,
                "executor_id": args.executor_id,
                "fencing_token": token,
                "acquired_at": utc_now(),
            },
        )
    return {"ok": True, "fencing_token": token, "executor_id": args.executor_id}


def command_lease_release(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    lock_path = require_lock_args(args)
    require(args.executor_id is not None and args.executor_id, "--executor-id is required")
    require(args.fencing_token is not None, "--fencing-token is required")
    with exclusive_file_lock(lock_path / ".mutex", create_parent=False):
        verify_owner(lock_path, args.owner_token)
        executor_path = lock_path / "executor"
        lease = read_json(executor_path / "lease.json")
        require(lease.get("owner_token") == args.owner_token, "lease owner mismatch", 3)
        require(lease.get("executor_id") == args.executor_id, "executor ID mismatch", 3)
        require(lease.get("fencing_token") == args.fencing_token, "fencing token mismatch", 3)
        try:
            os.unlink(executor_path / "lease.json")
            os.rmdir(executor_path)
            fsync_directory(lock_path)
        except OSError as exc:
            raise HelperError(f"cannot release executor lease: {exc}", 5) from exc
    return {"ok": True, "released": True}


def command_lease_takeover(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    lock_path = require_lock_args(args)
    require(args.executor_id is not None and args.executor_id, "--executor-id is required")
    evidence_digest = payload.get("takeover_evidence_digest")
    require(isinstance(evidence_digest, str) and evidence_digest, "takeover_evidence_digest required")
    with exclusive_file_lock(lock_path / ".mutex", create_parent=False):
        verify_owner(lock_path, args.owner_token)
        executor_path = lock_path / "executor"
        require(executor_path.is_dir(), "no executor lease exists to take over", 3)
        lease_path = executor_path / "lease.json"
        prior: dict[str, Any] | None = None
        if lease_path.exists():
            prior = read_json(lease_path)
            expected_prior = payload.get("prior_executor_id")
            require(isinstance(expected_prior, str) and expected_prior, "prior_executor_id required for an existing lease")
            require(prior.get("executor_id") == expected_prior, "prior executor ID mismatch", 3)
            require(prior.get("owner_token") == args.owner_token, "prior lease owner mismatch", 3)
            try:
                os.unlink(lease_path)
            except OSError as exc:
                raise HelperError(f"cannot clear prior executor lease: {exc}", 5) from exc
        fence = read_json(lock_path / "fence.json")
        last_token = fence.get("last_token")
        require(isinstance(last_token, int) and last_token >= 0, "invalid fence counter")
        token = cast(int, last_token) + 1
        atomic_write_json(lock_path / "fence.json", {"last_token": token})
        atomic_write_json(
            lease_path,
            {
                "owner_token": args.owner_token,
                "executor_id": args.executor_id,
                "fencing_token": token,
                "acquired_at": utc_now(),
                "takeover_evidence_digest": evidence_digest,
                "prior_executor_id": (prior or {}).get("executor_id"),
                "prior_fencing_token": (prior or {}).get("fencing_token"),
            },
        )
    return {"ok": True, "fencing_token": token, "executor_id": args.executor_id, "taken_over": True}


def command_lock_release(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    lock_path = require_lock_args(args)
    require(args.state is not None, "--state is required")
    state_path = Path(args.state).expanduser().resolve()
    mutex_path = lock_path / ".mutex"
    retired_path = lock_path.parent / f".{lock_path.name}.released-{uuid.uuid4().hex}"
    with exclusive_file_lock(mutex_path, create_parent=False):
        owner = verify_owner(lock_path, args.owner_token)
        require(not (lock_path / "executor").exists(), "cannot release owner lock while executor lease exists", 3)
        expected_state_path = lock_path.parent / "runs" / owner["stable_plan_id"] / "state.json"
        require(state_path == expected_state_path.resolve(), "owner lock state path mismatch", 3)
        state = read_json(state_path)
        validate_state(state)
        require(state["repository"]["repository_id"] == owner["repository_id"], "owner lock repository mismatch", 3)
        require(state["plan"]["stable_id"] == owner["stable_plan_id"], "owner lock plan mismatch", 3)
        require(state["phase"] == "complete", "owner lock release requires complete state", 4)
        unexpected = {child.name for child in lock_path.iterdir()} - {".mutex", "owner.json", "fence.json"}
        require(not unexpected, "owner lock has unexpected contents", 3)
        try:
            os.rename(lock_path, retired_path)
            fsync_directory(lock_path.parent)
        except OSError as exc:
            raise HelperError(f"cannot release repository owner lock: {exc}", 5) from exc
    try:
        os.unlink(retired_path / "owner.json")
        os.unlink(retired_path / "fence.json")
        os.unlink(retired_path / ".mutex")
        os.rmdir(retired_path)
        fsync_directory(retired_path.parent)
    except OSError as exc:
        raise HelperError(f"repository owner lock released but tombstone cleanup failed at {retired_path}: {exc}", 5) from exc
    return {"ok": True, "released": True}


def command_lock_update_plan(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    lock_path = require_lock_args(args)
    require(args.executor_id is not None and args.executor_id, "--executor-id is required")
    require(args.fencing_token is not None, "--fencing-token is required")
    require(args.plan_digest is not None and args.plan_digest, "--plan-digest is required")
    with exclusive_file_lock(lock_path / ".mutex", create_parent=False):
        owner = verify_owner(lock_path, args.owner_token)
        lease = read_json(lock_path / "executor" / "lease.json")
        require(lease.get("owner_token") == args.owner_token, "lease owner mismatch", 3)
        require(lease.get("executor_id") == args.executor_id, "executor ID mismatch", 3)
        require(lease.get("fencing_token") == args.fencing_token, "fencing token mismatch", 3)
        owner["plan_digest"] = args.plan_digest
        owner["plan_digest_updated_at"] = utc_now()
        atomic_write_json(lock_path / "owner.json", owner)
    return {"ok": True, "plan_digest": args.plan_digest}
