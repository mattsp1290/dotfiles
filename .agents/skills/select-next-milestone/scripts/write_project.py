#!/usr/bin/env python3
"""Exclusively create confirmed canonical next-milestone metadata."""

from __future__ import annotations

import hashlib
import os
from pathlib import Path
import stat
import sys

from validate_project import (
    MALFORMED,
    MAX_FILE_BYTES,
    UNSAFE,
    ValidationFailure,
    metadata_path,
    parse_and_validate,
    validate_repository,
    validate_root,
)

CONFLICT = 7


def _read_candidate(path_arg: str) -> bytes:
    path = Path(path_arg)
    try:
        info = path.stat()
    except OSError as exc:
        raise ValidationFailure(MALFORMED, [f"candidate: cannot read file: {exc}"]) from exc
    if not stat.S_ISREG(info.st_mode):
        raise ValidationFailure(MALFORMED, ["candidate: expected a regular file"])
    if info.st_size > MAX_FILE_BYTES:
        raise ValidationFailure(MALFORMED, [f"candidate: exceeds {MAX_FILE_BYTES} bytes"])
    try:
        return path.read_bytes()
    except OSError as exc:
        raise ValidationFailure(MALFORMED, [f"candidate: cannot read file: {exc}"]) from exc


def create(root_arg: str, candidate_arg: str, expected_digest: str) -> None:
    root = validate_root(root_arg)
    metadata_path(root, require_file=False)
    data = _read_candidate(candidate_arg)
    _, canonical = parse_and_validate(data)
    actual_digest = hashlib.sha256(canonical).hexdigest()
    if expected_digest != actual_digest or not all(char in "0123456789abcdef" for char in expected_digest) or len(expected_digest) != 64:
        raise ValidationFailure(CONFLICT, ["candidate: SHA-256 does not match confirmed canonical bytes"])

    directory_flags = os.O_RDONLY
    if hasattr(os, "O_DIRECTORY"):
        directory_flags |= os.O_DIRECTORY
    if hasattr(os, "O_NOFOLLOW"):
        directory_flags |= os.O_NOFOLLOW
    root_fd = os.open(root, directory_flags)
    agents_created = False
    agents_fd = None
    target_fd = None
    try:
        try:
            os.mkdir(".agents", mode=0o755, dir_fd=root_fd)
            agents_created = True
        except FileExistsError:
            pass
        try:
            agents_fd = os.open(".agents", directory_flags, dir_fd=root_fd)
        except OSError as exc:
            raise ValidationFailure(UNSAFE, [f".agents: unsafe directory: {exc}"]) from exc
        flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
        if hasattr(os, "O_NOFOLLOW"):
            flags |= os.O_NOFOLLOW
        try:
            target_fd = os.open("next-milestone.json", flags, 0o644, dir_fd=agents_fd)
        except FileExistsError as exc:
            raise ValidationFailure(CONFLICT, [".agents/next-milestone.json: destination already exists"]) from exc
        view = memoryview(canonical)
        while view:
            written = os.write(target_fd, view)
            view = view[written:]
        os.fsync(target_fd)
        os.close(target_fd)
        target_fd = None
        os.fsync(agents_fd)
    except Exception:
        if target_fd is not None:
            os.close(target_fd)
            try:
                os.unlink("next-milestone.json", dir_fd=agents_fd)
            except OSError:
                pass
        if agents_created and agents_fd is not None:
            try:
                os.rmdir(".agents", dir_fd=root_fd)
            except OSError:
                pass
        raise
    finally:
        if agents_fd is not None:
            os.close(agents_fd)
        os.close(root_fd)

    _, committed = validate_repository(os.fspath(root))
    if hashlib.sha256(committed).hexdigest() != actual_digest:
        raise ValidationFailure(CONFLICT, [".agents/next-milestone.json: committed digest changed"])
    print(f"created .agents/next-milestone.json sha256={actual_digest}")


def main(argv: list[str]) -> int:
    if len(argv) != 5 or argv[1] != "create":
        print("usage: write_project.py create <absolute-git-root> <canonical-json-file> <sha256>", file=sys.stderr)
        return UNSAFE
    try:
        create(argv[2], argv[3], argv[4])
    except ValidationFailure as exc:
        for error in exc.errors:
            print(error, file=sys.stderr)
        return exc.code
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
