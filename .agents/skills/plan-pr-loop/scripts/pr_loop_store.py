from __future__ import annotations

import argparse
import fcntl
import json
import os
import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator

from pr_loop_model import HelperError, require, validate_state


def read_json(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            value = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        raise HelperError(f"cannot read {path}: {exc}", 5) from exc
    require(isinstance(value, dict), f"{path} must contain a JSON object")
    return value


def fsync_directory(path: Path) -> None:
    try:
        descriptor = os.open(path, os.O_RDONLY)
        try:
            os.fsync(descriptor)
        finally:
            os.close(descriptor)
    except OSError:
        # Some filesystems do not permit directory fsync. The file fsync and
        # atomic replace still preserve the helper's primary guarantee.
        pass


def atomic_write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary_name: str | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=path.parent,
            prefix=f".{path.name}.",
            suffix=".tmp",
            delete=False,
        ) as handle:
            temporary_name = handle.name
            json.dump(value, handle, sort_keys=True, indent=2)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary_name, 0o600)
        os.replace(temporary_name, path)
        fsync_directory(path.parent)
    except OSError as exc:
        if temporary_name:
            try:
                os.unlink(temporary_name)
            except OSError:
                pass
        raise HelperError(f"cannot atomically write {path}: {exc}", 5) from exc


@contextmanager
def exclusive_file_lock(path: Path, *, create_parent: bool = True) -> Iterator[None]:
    if create_parent:
        path.parent.mkdir(parents=True, exist_ok=True)
    else:
        require(path.parent.is_dir(), f"lock directory does not exist: {path.parent}", 5)
    try:
        with path.open("a+", encoding="utf-8") as handle:
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
            try:
                yield
            finally:
                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
    except OSError as exc:
        raise HelperError(f"cannot acquire local transaction lock {path}: {exc}", 5) from exc

def load_state(args: argparse.Namespace) -> tuple[Path, dict[str, Any]]:
    require(args.state is not None, "--state is required")
    path = Path(args.state).expanduser().resolve()
    state = read_json(path)
    validate_state(state)
    return path, state

def check_cas(state: dict[str, Any], args: argparse.Namespace, *, bind: bool = False) -> None:
    require(args.expected_revision is not None, "--expected-revision is required")
    require(state["state_revision"] == args.expected_revision, "state revision conflict", 3)
    if args.expected_phase is not None:
        require(state["phase"] == args.expected_phase, "phase conflict", 3)
    require(args.fencing_token is not None, "--fencing-token is required")
    if bind:
        require(args.fencing_token > state["executor_fencing_token"], "new fencing token is not newer", 3)
    else:
        require(state["executor_fencing_token"] == args.fencing_token, "fencing token conflict", 3)


def commit_mutation(path: Path, state: dict[str, Any]) -> dict[str, Any]:
    state["state_revision"] += 1
    validate_state(state)
    atomic_write_json(path, state)
    return {
        "ok": True,
        "state_revision": state["state_revision"],
        "phase": state["phase"],
        "executor_fencing_token": state["executor_fencing_token"],
    }
