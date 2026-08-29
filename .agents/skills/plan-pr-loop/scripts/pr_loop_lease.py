from __future__ import annotations

import argparse
import os
import tempfile
import uuid
from pathlib import Path
from typing import Any, cast

from pr_loop_model import HelperError, require, utc_now, validate_state
from pr_loop_store import (
    atomic_write_json,
    exclusive_file_lock,
    fsync_directory,
    read_json,
)


LAYOUT_VERSION = 2
CHECKOUT_DIRECTORY = "plan-pr-loop-checkout"


def require_lock_args(args: argparse.Namespace) -> Path:
    require(args.lock is not None, "--lock is required")
    return Path(args.lock).expanduser().resolve()


def require_coordination_context(args: argparse.Namespace) -> tuple[Path, Path, str]:
    require(args.git_common_dir is not None, "--git-common-dir is required")
    require(args.git_dir is not None, "--git-dir is required")
    require(
        isinstance(args.checkout_incarnation, str) and args.checkout_incarnation,
        "--checkout-incarnation is required",
    )
    common_dir = Path(args.git_common_dir).expanduser().resolve()
    git_dir = Path(args.git_dir).expanduser().resolve()
    require(
        git_dir == common_dir or git_dir.is_relative_to(common_dir),
        "worktree Git dir is outside the common Git dir",
        3,
    )
    return common_dir, git_dir, args.checkout_incarnation


def coordination_root(args: argparse.Namespace) -> Path:
    common_dir, _, _ = require_coordination_context(args)
    return common_dir / "plan-pr-loop"


def canonical_lock_path(
    args: argparse.Namespace, stable_plan_id: str, *, legacy: bool = False
) -> Path:
    root = coordination_root(args)
    return root / "lock" if legacy else root / "runs" / stable_plan_id / "lock"


def checkout_claim_path(args: argparse.Namespace) -> Path:
    _, git_dir, _ = require_coordination_context(args)
    return git_dir / CHECKOUT_DIRECTORY


def expected_state_path(lock_path: Path, owner: dict[str, Any]) -> Path:
    if owner.get("layout_version") == LAYOUT_VERSION:
        return (lock_path.parent / "state.json").resolve()
    return (
        lock_path.parent / "runs" / owner["stable_plan_id"] / "state.json"
    ).resolve()


def validate_lock_path(
    lock_path: Path,
    args: argparse.Namespace,
    stable_plan_id: str,
    *,
    allow_legacy: bool = True,
) -> str:
    if lock_path == canonical_lock_path(args, stable_plan_id):
        return "plan-scoped"
    if allow_legacy and lock_path == canonical_lock_path(
        args, stable_plan_id, legacy=True
    ):
        return "legacy"
    raise HelperError("lock path is not canonical for this plan and Git common dir", 3)


def checkout_record(
    args: argparse.Namespace,
    owner: dict[str, Any],
    *,
    recovery_digest: str | None = None,
) -> dict[str, Any]:
    _, git_dir, incarnation = require_coordination_context(args)
    record = {
        "layout_version": LAYOUT_VERSION,
        "owner_token": owner["owner_token"],
        "repository_id": owner["repository_id"],
        "stable_plan_id": owner["stable_plan_id"],
        "git_dir": git_dir.as_posix(),
        "checkout_incarnation": incarnation,
        "claimed_at": utc_now(),
    }
    if recovery_digest:
        record["recovery_evidence_digest"] = recovery_digest
    return record


def create_checkout_claim(
    args: argparse.Namespace,
    owner: dict[str, Any],
    *,
    recovery_digest: str | None = None,
) -> bool:
    claim_path = checkout_claim_path(args)
    expected = checkout_record(args, owner, recovery_digest=recovery_digest)
    if claim_path.exists():
        current = read_json(claim_path / "owner.json")
        for key in (
            "owner_token",
            "repository_id",
            "stable_plan_id",
            "git_dir",
            "checkout_incarnation",
        ):
            require(
                current.get(key) == expected[key],
                "checkout is owned by another plan or incarnation",
                3,
            )
        return False
    claim_path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = Path(
        tempfile.mkdtemp(prefix=f".{claim_path.name}.init-", dir=claim_path.parent)
    )
    try:
        atomic_write_json(temporary_path / "owner.json", expected)
        fsync_directory(temporary_path)
        try:
            os.rename(temporary_path, claim_path)
            fsync_directory(claim_path.parent)
            return True
        except OSError as exc:
            if not claim_path.exists():
                raise HelperError(f"cannot publish checkout claim: {exc}", 5) from exc
            current = read_json(claim_path / "owner.json")
            for key in (
                "owner_token",
                "repository_id",
                "stable_plan_id",
                "git_dir",
                "checkout_incarnation",
            ):
                require(
                    current.get(key) == expected[key],
                    "checkout is owned by another plan or incarnation",
                    3,
                )
            return False
    finally:
        if temporary_path.exists():
            for child in temporary_path.iterdir():
                if child.is_file():
                    os.unlink(child)
            os.rmdir(temporary_path)


def remove_checkout_claim(args: argparse.Namespace, owner: dict[str, Any]) -> None:
    claim_path = checkout_claim_path(args)
    current = read_json(claim_path / "owner.json")
    expected = {
        "owner_token": owner.get("owner_token"),
        "repository_id": owner.get("repository_id"),
        "stable_plan_id": owner.get("stable_plan_id"),
        "git_dir": owner.get("checkout_git_dir"),
        "checkout_incarnation": owner.get("checkout_incarnation"),
    }
    for key, value in expected.items():
        require(current.get(key) == value, "checkout claim owner mismatch", 3)
    try:
        os.unlink(claim_path / "owner.json")
        os.rmdir(claim_path)
        fsync_directory(claim_path.parent)
    except OSError as exc:
        raise HelperError(f"cannot release checkout claim: {exc}", 5) from exc


def bind_checkout_fields(
    owner: dict[str, Any], args: argparse.Namespace
) -> dict[str, Any]:
    _, git_dir, incarnation = require_coordination_context(args)
    owner["checkout_git_dir"] = git_dir.as_posix()
    owner["checkout_incarnation"] = incarnation
    return owner


def verify_checkout_identity(owner: dict[str, Any], args: argparse.Namespace) -> None:
    _, git_dir, incarnation = require_coordination_context(args)
    require(
        owner.get("checkout_git_dir") == git_dir.as_posix(),
        "plan is bound to another checkout",
        3,
    )
    require(
        owner.get("checkout_incarnation") == incarnation,
        "checkout incarnation mismatch",
        3,
    )


def verify_checkout_claim(owner: dict[str, Any], args: argparse.Namespace) -> None:
    _, git_dir, incarnation = require_coordination_context(args)
    verify_checkout_identity(owner, args)
    claim = read_json(checkout_claim_path(args) / "owner.json")
    for key, value in (
        ("owner_token", owner.get("owner_token")),
        ("repository_id", owner.get("repository_id")),
        ("stable_plan_id", owner.get("stable_plan_id")),
        ("git_dir", git_dir.as_posix()),
        ("checkout_incarnation", incarnation),
    ):
        require(claim.get(key) == value, "checkout claim does not match plan owner", 3)


def verify_owner(
    lock_path: Path, owner_token: str | None, args: argparse.Namespace | None = None
) -> dict[str, Any]:
    require(owner_token is not None and owner_token, "--owner-token is required")
    owner = read_json(lock_path / "owner.json")
    require(
        not owner.get("layout_guard"), "plan-scoped layout guard is not a plan lock", 3
    )
    require(owner.get("owner_token") == owner_token, "plan lock owner mismatch", 3)
    if args is not None:
        validate_lock_path(lock_path, args, owner["stable_plan_id"])
        verify_checkout_claim(owner, args)
    return owner


def verify_live_lease_locked(
    lock_path: Path, args: argparse.Namespace
) -> dict[str, Any]:
    require(
        args.executor_id is not None and args.executor_id, "--executor-id is required"
    )
    require(args.fencing_token is not None, "--fencing-token is required")
    verify_owner(lock_path, args.owner_token, args)
    lease_path = lock_path / "executor" / "lease.json"
    require(lease_path.is_file(), "live executor lease required", 3)
    lease = read_json(lease_path)
    require(lease.get("owner_token") == args.owner_token, "lease owner mismatch", 3)
    require(lease.get("executor_id") == args.executor_id, "executor ID mismatch", 3)
    require(
        lease.get("fencing_token") == args.fencing_token, "fencing token mismatch", 3
    )
    require(
        lease.get("checkout_incarnation") == args.checkout_incarnation,
        "lease checkout mismatch",
        3,
    )
    return lease


def write_guard(root: Path, repository_id: str) -> None:
    guard_path = root / "lock"
    if guard_path.exists():
        guard = read_json(guard_path / "owner.json")
        require(
            guard.get("layout_guard") is True,
            "legacy repository lock blocks plan-scoped execution",
            3,
        )
        require(
            guard.get("repository_id") == repository_id,
            "repository identity mismatch",
            3,
        )
        return
    root.mkdir(parents=True, exist_ok=True)
    temporary_path = Path(tempfile.mkdtemp(prefix=".lock.guard-", dir=root))
    try:
        atomic_write_json(
            temporary_path / "owner.json",
            {
                "layout_version": LAYOUT_VERSION,
                "layout_guard": True,
                "repository_id": repository_id,
                "created_at": utc_now(),
            },
        )
        atomic_write_json(temporary_path / "fence.json", {"last_token": 0})
        (temporary_path / ".mutex").touch(mode=0o600)
        fsync_directory(temporary_path)
        try:
            os.rename(temporary_path, guard_path)
            fsync_directory(root)
        except OSError as exc:
            if not guard_path.exists():
                raise HelperError(
                    f"cannot publish plan-scoped layout guard: {exc}", 5
                ) from exc
            guard = read_json(guard_path / "owner.json")
            require(
                guard.get("layout_guard") is True,
                "legacy repository lock blocks plan-scoped execution",
                3,
            )
    finally:
        if temporary_path.exists():
            for child in temporary_path.iterdir():
                if child.is_file():
                    os.unlink(child)
            os.rmdir(temporary_path)


def publish_plan_lock(lock_path: Path, owner: dict[str, Any]) -> bool:
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    if lock_path.exists():
        return False
    temporary_path = Path(tempfile.mkdtemp(prefix=".lock.init-", dir=lock_path.parent))
    try:
        atomic_write_json(temporary_path / "owner.json", owner)
        atomic_write_json(temporary_path / "fence.json", {"last_token": 0})
        fsync_directory(temporary_path)
        try:
            os.rename(temporary_path, lock_path)
            fsync_directory(lock_path.parent)
            return True
        except OSError as exc:
            if not lock_path.exists():
                raise HelperError(f"cannot publish plan owner lock: {exc}", 5) from exc
            return False
    finally:
        if temporary_path.exists():
            for child in temporary_path.iterdir():
                if child.is_file():
                    os.unlink(child)
            os.rmdir(temporary_path)


def prepare_checkout_claim(
    lock_path: Path,
    args: argparse.Namespace,
    owner: dict[str, Any],
    payload: dict[str, Any],
) -> bool:
    owner_path = lock_path / "owner.json"
    if not owner_path.is_file():
        return create_checkout_claim(args, owner)
    current = read_json(owner_path)
    require(
        not current.get("layout_guard"),
        "plan-scoped layout guard is not a plan lock",
        3,
    )
    for key in ("owner_token", "repository_id", "stable_plan_id"):
        require(current.get(key) == owner[key], "existing plan lock owner mismatch", 3)
    verify_checkout_identity(current, args)
    if checkout_claim_path(args).exists():
        return create_checkout_claim(args, current)
    require(
        not (lock_path / "executor").exists(),
        "release the executor before checkout-claim recovery",
        3,
    )
    evidence = payload.get("checkout_recovery_evidence_digest")
    require(
        isinstance(evidence, str) and evidence,
        "missing checkout claim requires recovery evidence",
        3,
    )
    return create_checkout_claim(args, current, recovery_digest=evidence)


def recover_incomplete_plan_lock(
    lock_path: Path,
    args: argparse.Namespace,
    owner: dict[str, Any],
    payload: dict[str, Any],
) -> dict[str, Any] | None:
    owner_path = lock_path / "owner.json"
    fence_path = lock_path / "fence.json"
    if not lock_path.exists() or (owner_path.is_file() and fence_path.is_file()):
        return None
    evidence = payload.get("incomplete_lock_recovery_evidence_digest")
    require(
        isinstance(evidence, str) and evidence,
        "incomplete plan lock requires recovery evidence",
        3,
    )
    with exclusive_file_lock(lock_path / ".mutex", create_parent=False):
        require(
            not (lock_path / "executor").exists(),
            "incomplete plan lock has executor state",
            3,
        )
        unexpected = {child.name for child in lock_path.iterdir()} - {
            ".mutex",
            "owner.json",
            "fence.json",
        }
        require(not unexpected, "incomplete plan lock has unexpected contents", 3)
        recovered_owner = owner
        if owner_path.is_file():
            recovered_owner = read_json(owner_path)
            for key in ("owner_token", "repository_id", "stable_plan_id"):
                require(
                    recovered_owner.get(key) == owner[key],
                    "incomplete plan lock owner mismatch",
                    3,
                )
            bind_checkout_fields(recovered_owner, args)
        else:
            atomic_write_json(owner_path, recovered_owner)
        if fence_path.is_file():
            fence = read_json(fence_path)
            require(
                fence.get("last_token") == 0,
                "incomplete plan lock has an advanced fence",
                3,
            )
        else:
            atomic_write_json(fence_path, {"last_token": 0})
        recovered_owner["incomplete_lock_recovery_evidence_digest"] = evidence
        atomic_write_json(owner_path, recovered_owner)
    return recovered_owner


def recover_incomplete_legacy_lock(
    lock_path: Path,
    args: argparse.Namespace,
    owner: dict[str, Any],
    payload: dict[str, Any],
) -> None:
    owner_path = lock_path / "owner.json"
    fence_path = lock_path / "fence.json"
    if owner_path.is_file() and fence_path.is_file():
        return
    evidence = payload.get("incomplete_lock_recovery_evidence_digest")
    require(
        isinstance(evidence, str) and evidence,
        "incomplete legacy lock requires recovery evidence",
        3,
    )
    with exclusive_file_lock(lock_path / ".mutex", create_parent=False):
        require(
            not (lock_path / "executor").exists(),
            "incomplete legacy lock has executor state",
            3,
        )
        unexpected = {child.name for child in lock_path.iterdir()} - {
            ".mutex",
            "owner.json",
            "fence.json",
        }
        require(not unexpected, "incomplete legacy lock has unexpected contents", 3)
        if owner_path.is_file():
            current = read_json(owner_path)
            for key in ("owner_token", "repository_id", "stable_plan_id"):
                require(
                    current.get(key) == owner[key],
                    "incomplete legacy lock owner mismatch",
                    3,
                )
        else:
            legacy_owner = dict(owner)
            legacy_owner.pop("layout_version", None)
            legacy_owner.pop("checkout_git_dir", None)
            legacy_owner.pop("checkout_incarnation", None)
            legacy_owner["incomplete_lock_recovery_evidence_digest"] = evidence
            atomic_write_json(owner_path, legacy_owner)
        if fence_path.is_file():
            fence = read_json(fence_path)
            require(
                fence.get("last_token") == 0,
                "incomplete legacy lock has an advanced fence",
                3,
            )
        else:
            atomic_write_json(fence_path, {"last_token": 0})


def command_lock_init(
    args: argparse.Namespace, payload: dict[str, Any]
) -> dict[str, Any]:
    lock_path = require_lock_args(args)
    for name, value in (
        ("owner-token", args.owner_token),
        ("repository-id", args.repository_id),
        ("stable-plan-id", args.stable_plan_id),
        ("plan-digest", args.plan_digest),
    ):
        require(isinstance(value, str) and value, f"--{name} is required")
    layout = validate_lock_path(lock_path, args, args.stable_plan_id)
    root = coordination_root(args)
    root.mkdir(parents=True, exist_ok=True)
    owner = bind_checkout_fields(
        {
            "layout_version": LAYOUT_VERSION,
            "owner_token": args.owner_token,
            "repository_id": args.repository_id,
            "stable_plan_id": args.stable_plan_id,
            "plan_digest": args.plan_digest,
            "goal_id": args.goal_id,
            "created_at": utc_now(),
        },
        args,
    )
    with exclusive_file_lock(root / ".coordination.mutex"):
        if layout == "legacy":
            require(
                lock_path.exists(),
                "legacy lock does not exist; use the canonical plan-scoped lock",
                3,
            )
            recover_incomplete_legacy_lock(lock_path, args, owner, payload)
            current = read_json(lock_path / "owner.json")
            require(
                not current.get("layout_guard"),
                "legacy layout is retired; use the canonical plan-scoped lock",
                3,
            )
            require(
                current.get("owner_token") == args.owner_token,
                "plan lock owner mismatch",
                3,
            )
            require(
                current.get("repository_id") == args.repository_id,
                "repository identity mismatch",
                3,
            )
            require(
                current.get("stable_plan_id") == args.stable_plan_id,
                "another plan owns the legacy repository lock",
                3,
            )
            if current.get("checkout_incarnation") is None:
                require(
                    not (lock_path / "executor").exists(),
                    "release the legacy executor before checkout adoption",
                    3,
                )
                evidence = payload.get("legacy_checkout_adoption_evidence_digest")
                require(
                    isinstance(evidence, str) and evidence,
                    "legacy checkout adoption requires evidence",
                    3,
                )
                current = bind_checkout_fields(current, args)
                current["legacy_checkout_adoption_evidence_digest"] = evidence
                current["legacy_checkout_adopted_at"] = utc_now()
                created_claim = create_checkout_claim(
                    args, current, recovery_digest=evidence
                )
                try:
                    atomic_write_json(lock_path / "owner.json", current)
                except Exception:
                    if created_claim:
                        remove_checkout_claim(args, current)
                    raise
            else:
                verify_checkout_identity(current, args)
                if checkout_claim_path(args).exists():
                    verify_checkout_claim(current, args)
                else:
                    require(
                        not (lock_path / "executor").exists(),
                        "release the executor before checkout-claim recovery",
                        3,
                    )
                    evidence = payload.get("checkout_recovery_evidence_digest")
                    require(
                        isinstance(evidence, str) and evidence,
                        "missing checkout claim requires recovery evidence",
                        3,
                    )
                    create_checkout_claim(args, current, recovery_digest=evidence)
            return {
                "ok": True,
                "created": False,
                "legacy": True,
                "plan_digest_matches": current.get("plan_digest") == args.plan_digest,
                "stored_plan_digest": current.get("plan_digest"),
            }

        write_guard(root, args.repository_id)
        created_claim = prepare_checkout_claim(lock_path, args, owner, payload)
        created_lock = False
        try:
            recovered = recover_incomplete_plan_lock(lock_path, args, owner, payload)
            if recovered is not None:
                return {
                    "ok": True,
                    "created": False,
                    "recovered": True,
                    "plan_digest_matches": recovered.get("plan_digest")
                    == args.plan_digest,
                    "stored_plan_digest": recovered.get("plan_digest"),
                }
            created_lock = publish_plan_lock(lock_path, owner)
            if not created_lock:
                current = verify_owner(lock_path, args.owner_token, args)
                require(
                    current.get("repository_id") == args.repository_id,
                    "repository identity mismatch",
                    3,
                )
                return {
                    "ok": True,
                    "created": False,
                    "plan_digest_matches": current.get("plan_digest")
                    == args.plan_digest,
                    "stored_plan_digest": current.get("plan_digest"),
                }
            return {"ok": True, "created": True, "plan_digest_matches": True}
        except Exception:
            if created_claim and not created_lock:
                remove_checkout_claim(args, owner)
            raise


def command_lease_acquire(
    args: argparse.Namespace, payload: dict[str, Any]
) -> dict[str, Any]:
    lock_path = require_lock_args(args)
    require(
        args.executor_id is not None and args.executor_id, "--executor-id is required"
    )
    with exclusive_file_lock(lock_path / ".mutex", create_parent=False):
        verify_owner(lock_path, args.owner_token, args)
        executor_path = lock_path / "executor"
        try:
            os.mkdir(executor_path, 0o700)
        except FileExistsError as exc:
            raise HelperError("executor lease already held", 3) from exc
        except OSError as exc:
            raise HelperError(f"cannot acquire executor lease: {exc}", 5) from exc
        fence = read_json(lock_path / "fence.json")
        last_token = fence.get("last_token")
        require(
            isinstance(last_token, int) and last_token >= 0, "invalid fence counter"
        )
        token = cast(int, last_token) + 1
        atomic_write_json(lock_path / "fence.json", {"last_token": token})
        atomic_write_json(
            executor_path / "lease.json",
            {
                "owner_token": args.owner_token,
                "executor_id": args.executor_id,
                "fencing_token": token,
                "checkout_incarnation": args.checkout_incarnation,
                "acquired_at": utc_now(),
            },
        )
    return {"ok": True, "fencing_token": token, "executor_id": args.executor_id}


def command_lease_release(
    args: argparse.Namespace, payload: dict[str, Any]
) -> dict[str, Any]:
    lock_path = require_lock_args(args)
    require(
        args.executor_id is not None and args.executor_id, "--executor-id is required"
    )
    require(args.fencing_token is not None, "--fencing-token is required")
    with exclusive_file_lock(lock_path / ".mutex", create_parent=False):
        verify_owner(lock_path, args.owner_token, args)
        executor_path = lock_path / "executor"
        lease = read_json(executor_path / "lease.json")
        require(lease.get("owner_token") == args.owner_token, "lease owner mismatch", 3)
        require(lease.get("executor_id") == args.executor_id, "executor ID mismatch", 3)
        require(
            lease.get("fencing_token") == args.fencing_token,
            "fencing token mismatch",
            3,
        )
        require(
            lease.get("checkout_incarnation") == args.checkout_incarnation,
            "lease checkout mismatch",
            3,
        )
        try:
            os.unlink(executor_path / "lease.json")
            os.rmdir(executor_path)
            fsync_directory(lock_path)
        except OSError as exc:
            raise HelperError(f"cannot release executor lease: {exc}", 5) from exc
    return {"ok": True, "released": True}


def command_lease_takeover(
    args: argparse.Namespace, payload: dict[str, Any]
) -> dict[str, Any]:
    lock_path = require_lock_args(args)
    require(
        args.executor_id is not None and args.executor_id, "--executor-id is required"
    )
    evidence_digest = payload.get("takeover_evidence_digest")
    require(
        isinstance(evidence_digest, str) and evidence_digest,
        "takeover_evidence_digest required",
    )
    with exclusive_file_lock(lock_path / ".mutex", create_parent=False):
        verify_owner(lock_path, args.owner_token, args)
        executor_path = lock_path / "executor"
        require(executor_path.is_dir(), "no executor lease exists to take over", 3)
        lease_path = executor_path / "lease.json"
        prior: dict[str, Any] | None = None
        if lease_path.exists():
            prior = read_json(lease_path)
            expected_prior = payload.get("prior_executor_id")
            require(
                isinstance(expected_prior, str) and expected_prior,
                "prior_executor_id required for an existing lease",
            )
            require(
                prior.get("executor_id") == expected_prior,
                "prior executor ID mismatch",
                3,
            )
            require(
                prior.get("owner_token") == args.owner_token,
                "prior lease owner mismatch",
                3,
            )
            os.unlink(lease_path)
        fence = read_json(lock_path / "fence.json")
        last_token = fence.get("last_token")
        require(
            isinstance(last_token, int) and last_token >= 0, "invalid fence counter"
        )
        token = cast(int, last_token) + 1
        atomic_write_json(lock_path / "fence.json", {"last_token": token})
        atomic_write_json(
            lease_path,
            {
                "owner_token": args.owner_token,
                "executor_id": args.executor_id,
                "fencing_token": token,
                "checkout_incarnation": args.checkout_incarnation,
                "acquired_at": utc_now(),
                "takeover_evidence_digest": evidence_digest,
                "prior_executor_id": (prior or {}).get("executor_id"),
                "prior_fencing_token": (prior or {}).get("fencing_token"),
            },
        )
    return {
        "ok": True,
        "fencing_token": token,
        "executor_id": args.executor_id,
        "taken_over": True,
    }


def command_lock_release(
    args: argparse.Namespace, payload: dict[str, Any]
) -> dict[str, Any]:
    lock_path = require_lock_args(args)
    require(args.state is not None, "--state is required")
    state_path = Path(args.state).expanduser().resolve()
    retired_path: Path | None = (
        lock_path.parent / f".{lock_path.name}.released-{uuid.uuid4().hex}"
    )
    root = coordination_root(args)
    with exclusive_file_lock(root / ".coordination.mutex"):
        with exclusive_file_lock(lock_path / ".mutex", create_parent=False):
            owner = verify_owner(lock_path, args.owner_token, args)
            require(
                not (lock_path / "executor").exists(),
                "cannot release plan lock while executor lease exists",
                3,
            )
            require(
                state_path == expected_state_path(lock_path, owner),
                "plan lock state path mismatch",
                3,
            )
            state = read_json(state_path)
            validate_state(state)
            require(
                state["repository"]["repository_id"] == owner["repository_id"],
                "plan lock repository mismatch",
                3,
            )
            require(
                state["plan"]["stable_id"] == owner["stable_plan_id"],
                "plan lock plan mismatch",
                3,
            )
            require(
                state["phase"] == "complete",
                "plan lock release requires complete state",
                4,
            )
            unexpected = {child.name for child in lock_path.iterdir()} - {
                ".mutex",
                "owner.json",
                "fence.json",
            }
            require(not unexpected, "plan lock has unexpected contents", 3)
            if owner.get("layout_version") == LAYOUT_VERSION:
                os.rename(lock_path, retired_path)
                fsync_directory(lock_path.parent)
            else:
                atomic_write_json(
                    lock_path / "owner.json",
                    {
                        "layout_version": LAYOUT_VERSION,
                        "layout_guard": True,
                        "repository_id": owner["repository_id"],
                        "converted_from_plan": owner["stable_plan_id"],
                        "created_at": utc_now(),
                    },
                )
                retired_path = None
            remove_checkout_claim(args, owner)
    if retired_path is not None:
        try:
            os.unlink(retired_path / "owner.json")
            os.unlink(retired_path / "fence.json")
            os.unlink(retired_path / ".mutex")
            os.rmdir(retired_path)
            fsync_directory(retired_path.parent)
        except OSError as exc:
            raise HelperError(
                f"plan lock released but tombstone cleanup failed at {retired_path}: {exc}",
                5,
            ) from exc
    return {"ok": True, "released": True}


def command_lock_update_plan(
    args: argparse.Namespace, payload: dict[str, Any]
) -> dict[str, Any]:
    lock_path = require_lock_args(args)
    require(
        args.executor_id is not None and args.executor_id, "--executor-id is required"
    )
    require(args.fencing_token is not None, "--fencing-token is required")
    require(
        args.plan_digest is not None and args.plan_digest, "--plan-digest is required"
    )
    with exclusive_file_lock(lock_path / ".mutex", create_parent=False):
        owner = verify_owner(lock_path, args.owner_token, args)
        lease = read_json(lock_path / "executor" / "lease.json")
        require(lease.get("owner_token") == args.owner_token, "lease owner mismatch", 3)
        require(lease.get("executor_id") == args.executor_id, "executor ID mismatch", 3)
        require(
            lease.get("fencing_token") == args.fencing_token,
            "fencing token mismatch",
            3,
        )
        owner["plan_digest"] = args.plan_digest
        owner["plan_digest_updated_at"] = utc_now()
        atomic_write_json(lock_path / "owner.json", owner)
    return {"ok": True, "plan_digest": args.plan_digest}
