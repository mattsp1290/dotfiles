#!/usr/bin/env python3
"""Validate a repository's canonical .agents/next-milestone.json."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import unicodedata
from urllib.parse import unquote, urlsplit, urlunsplit

VALID = 0
ABSENT = 2
UNSAFE = 3
MALFORMED = 4
UNSUPPORTED = 5
INVALID = 6

MAX_FILE_BYTES = 65_536
MAX_STRING = 2_000
MAX_NAME = 200
MAX_ID = 128
MAX_URL_OR_PATH = 2_048
MAX_ITEMS = 32
MAX_SOURCES = 8
MAX_NON_GOALS = 64

ID_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
MODULE_RE = re.compile(
    r"^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?"
    r"(?:/[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?)+$"
)
CONTROL_RE = re.compile(r"[\x00-\x1f\x7f]")
GLOB_CHARS = set("*?[]{}")


class DuplicateKey(ValueError):
    pass


class ValidationFailure(Exception):
    def __init__(self, code: int, errors: list[str]):
        super().__init__("; ".join(errors))
        self.code = code
        self.errors = errors


def _pairs_no_duplicates(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateKey("duplicate object key")
        result[key] = value
    return result


def canonical_bytes(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def normalize_remote_url(value: str) -> str | None:
    candidate = value.strip()
    ssh = re.fullmatch(r"git@([^:]+):(.+)", candidate)
    if ssh:
        candidate = f"https://{ssh.group(1)}/{ssh.group(2)}"
    parsed = urlsplit(candidate)
    if parsed.scheme.lower() != "https" or not parsed.hostname:
        return None
    if parsed.username is not None or parsed.password is not None:
        return None
    if parsed.query or parsed.fragment:
        return None
    try:
        port = parsed.port
    except ValueError:
        return None
    if port not in (None, 443):
        return None
    host = parsed.hostname.lower()
    path = unquote(parsed.path).rstrip("/")
    if CONTROL_RE.search(path) or any(part in ("", ".", "..") for part in path.split("/")[1:]):
        return None
    if path.endswith(".git"):
        path = path[:-4]
    if not path or path == "/" or any(ch in path for ch in "?#"):
        return None
    return urlunsplit(("https", host, path, "", ""))


def _is_canonical_module(value: str) -> bool:
    if not MODULE_RE.fullmatch(value) or len(value) > MAX_URL_OR_PATH:
        return False
    host = value.split("/", 1)[0]
    return host == host.lower() and "." in host and ".." not in value


def validate_root(root_arg: str) -> Path:
    root = Path(root_arg)
    if not root.is_absolute():
        raise ValidationFailure(UNSAFE, ["repository: root must be absolute"])
    try:
        resolved = root.resolve(strict=True)
    except OSError as exc:
        raise ValidationFailure(UNSAFE, [f"repository: cannot resolve root: {exc}"]) from exc
    if not resolved.is_dir():
        raise ValidationFailure(UNSAFE, ["repository: root is not a directory"])
    result = subprocess.run(
        ["git", "-C", os.fspath(resolved), "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise ValidationFailure(UNSAFE, ["repository: root is not a Git worktree"])
    try:
        git_root = Path(result.stdout.strip()).resolve(strict=True)
    except OSError as exc:
        raise ValidationFailure(UNSAFE, [f"repository: cannot resolve Git root: {exc}"]) from exc
    if git_root != resolved:
        raise ValidationFailure(UNSAFE, ["repository: argument must be the Git worktree root"])
    return resolved


def metadata_path(root: Path, *, require_file: bool = True) -> Path:
    agents = root / ".agents"
    target = agents / "next-milestone.json"
    if not agents.exists():
        if agents.is_symlink():
            raise ValidationFailure(UNSAFE, [".agents: dangling symlink is unsafe"])
        if require_file:
            raise ValidationFailure(ABSENT, [".agents/next-milestone.json: file is absent"])
        return target
    if agents.is_symlink():
        raise ValidationFailure(UNSAFE, [".agents: symlink components are not allowed"])
    if not agents.is_dir():
        raise ValidationFailure(UNSAFE, [".agents: expected a directory"])
    if target.is_symlink():
        raise ValidationFailure(UNSAFE, [".agents/next-milestone.json: symlinks are not allowed"])
    if require_file and not target.exists():
        raise ValidationFailure(ABSENT, [".agents/next-milestone.json: file is absent"])
    return target


def read_limited(path: Path) -> bytes:
    flags = os.O_RDONLY
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        fd = os.open(path, flags)
    except FileNotFoundError as exc:
        raise ValidationFailure(ABSENT, [".agents/next-milestone.json: file is absent"]) from exc
    except OSError as exc:
        raise ValidationFailure(UNSAFE, [f".agents/next-milestone.json: unsafe file: {exc}"]) from exc
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode):
            raise ValidationFailure(UNSAFE, [".agents/next-milestone.json: expected a regular file"])
        if info.st_size > MAX_FILE_BYTES:
            raise ValidationFailure(MALFORMED, [f".agents/next-milestone.json: exceeds {MAX_FILE_BYTES} bytes"])
        data = b""
        while len(data) <= MAX_FILE_BYTES:
            chunk = os.read(fd, min(8192, MAX_FILE_BYTES + 1 - len(data)))
            if not chunk:
                break
            data += chunk
        if len(data) > MAX_FILE_BYTES:
            raise ValidationFailure(MALFORMED, [f".agents/next-milestone.json: exceeds {MAX_FILE_BYTES} bytes"])
        return data
    finally:
        os.close(fd)


def _expect_object(value: object, path: str, keys: tuple[str, ...], errors: list[str]) -> dict[str, object] | None:
    if not isinstance(value, dict):
        errors.append(f"{path}: expected object")
        return None
    unknown = sorted(set(value) - set(keys))
    missing = [key for key in keys if key not in value]
    for key in unknown:
        errors.append(f"{path}.{key}: unknown field")
    for key in missing:
        errors.append(f"{path}.{key}: required field is missing")
    if not unknown and not missing and tuple(value) != keys:
        errors.append(f"{path}: fields must use canonical schema order")
    return value


def _string(value: object, path: str, errors: list[str], *, maximum: int = MAX_STRING) -> str | None:
    if not isinstance(value, str):
        errors.append(f"{path}: expected string")
        return None
    if value != value.strip() or not value:
        errors.append(f"{path}: must be non-empty with no surrounding whitespace")
    if len(value) > maximum:
        errors.append(f"{path}: exceeds {maximum} Unicode code points")
    if CONTROL_RE.search(value):
        errors.append(f"{path}: control characters are not allowed")
    return value


def _list(value: object, path: str, errors: list[str], *, minimum: int, maximum: int) -> list[object] | None:
    if not isinstance(value, list):
        errors.append(f"{path}: expected array")
        return None
    if not minimum <= len(value) <= maximum:
        errors.append(f"{path}: expected {minimum}..{maximum} items")
    return value


def _unique(values: list[str], path: str, errors: list[str]) -> None:
    seen: set[str] = set()
    for index, value in enumerate(values):
        normalized = unicodedata.normalize("NFKC", value.strip()).casefold()
        if normalized in seen:
            errors.append(f"{path}[{index}]: duplicate normalized value")
        seen.add(normalized)


def _validate_https(value: object, path: str, errors: list[str]) -> str | None:
    text = _string(value, path, errors, maximum=MAX_URL_OR_PATH)
    if text is None:
        return None
    parsed = urlsplit(text)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username is not None or parsed.password is not None:
        errors.append(f"{path}: expected absolute HTTPS URL without embedded credentials")
    if CONTROL_RE.search(text):
        errors.append(f"{path}: control characters are not allowed")
    return text


def _validate_path_hint(value: object, path: str, errors: list[str]) -> None:
    text = _string(value, path, errors, maximum=MAX_URL_OR_PATH)
    if text is None:
        return
    suffix = text
    if text.startswith("${HOME}/"):
        suffix = text[len("${HOME}/") :]
        parts = suffix.split("/")
    elif not text.startswith("/"):
        errors.append(f"{path}: expected an absolute path or literal ${{HOME}}/ prefix")
        return
    else:
        suffix = text[1:]
        parts = suffix.split("/")
    if not suffix or any(part in ("", ".", "..") for part in parts):
        errors.append(f"{path}: empty and dot path segments are not allowed")
    if any(char in suffix for char in GLOB_CHARS) or "$" in suffix:
        errors.append(f"{path}: globs and other environment variables are not allowed")


def parse_and_validate(data: bytes, *, require_canonical: bool = True) -> tuple[dict[str, object], bytes]:
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ValidationFailure(MALFORMED, [f"$: invalid UTF-8: {exc}"]) from exc
    try:
        value = json.loads(text, object_pairs_hook=_pairs_no_duplicates)
    except (json.JSONDecodeError, DuplicateKey) as exc:
        raise ValidationFailure(MALFORMED, [f"$: malformed JSON: {exc}"]) from exc
    if isinstance(value, dict) and isinstance(value.get("schema_version"), int) and value["schema_version"] != 1:
        raise ValidationFailure(UNSUPPORTED, [f"schema_version: unsupported version {value['schema_version']}"])

    errors: list[str] = []
    root = _expect_object(
        value,
        "$",
        ("schema_version", "project", "comparators", "evaluation_lenses", "acceptance_journey", "non_goals", "ecosystem"),
        errors,
    )
    if root is None:
        raise ValidationFailure(INVALID, errors)
    if root.get("schema_version") != 1 or isinstance(root.get("schema_version"), bool):
        errors.append("schema_version: expected integer 1")

    project = _expect_object(root.get("project"), "project", ("id", "name", "vision", "repository_identity"), errors)
    project_id = None
    if project is not None:
        project_id = _string(project.get("id"), "project.id", errors, maximum=MAX_ID)
        if project_id is not None and not ID_RE.fullmatch(project_id):
            errors.append("project.id: expected lowercase kebab-case")
        _string(project.get("name"), "project.name", errors, maximum=MAX_NAME)
        _string(project.get("vision"), "project.vision", errors)
        identity = _expect_object(project.get("repository_identity"), "project.repository_identity", ("kind", "value"), errors)
        if identity is not None:
            kind = _string(identity.get("kind"), "project.repository_identity.kind", errors, maximum=32)
            identity_value = _string(identity.get("value"), "project.repository_identity.value", errors, maximum=MAX_URL_OR_PATH)
            if kind not in ("remote-url", "module"):
                errors.append("project.repository_identity.kind: expected remote-url or module")
            elif identity_value is not None and kind == "remote-url":
                if normalize_remote_url(identity_value) != identity_value:
                    errors.append("project.repository_identity.value: expected canonical HTTPS remote URL")
            elif identity_value is not None and kind == "module" and not _is_canonical_module(identity_value):
                errors.append("project.repository_identity.value: expected canonical module identifier")

    comparators = _list(root.get("comparators"), "comparators", errors, minimum=1, maximum=MAX_ITEMS)
    comparator_names: list[str] = []
    if comparators is not None:
        for index, item in enumerate(comparators):
            base = f"comparators[{index}]"
            comparator = _expect_object(item, base, ("name", "official_sources", "relevance"), errors)
            if comparator is None:
                continue
            name = _string(comparator.get("name"), f"{base}.name", errors, maximum=MAX_NAME)
            if name is not None:
                comparator_names.append(name)
            sources = _list(comparator.get("official_sources"), f"{base}.official_sources", errors, minimum=1, maximum=MAX_SOURCES)
            source_values: list[str] = []
            if sources is not None:
                for source_index, source in enumerate(sources):
                    checked = _validate_https(source, f"{base}.official_sources[{source_index}]", errors)
                    if checked is not None:
                        source_values.append(checked)
                _unique(source_values, f"{base}.official_sources", errors)
            _string(comparator.get("relevance"), f"{base}.relevance", errors)
        _unique(comparator_names, "comparators", errors)

    lenses = _list(root.get("evaluation_lenses"), "evaluation_lenses", errors, minimum=1, maximum=MAX_ITEMS)
    lens_names: list[str] = []
    if lenses is not None:
        for index, item in enumerate(lenses):
            base = f"evaluation_lenses[{index}]"
            lens = _expect_object(item, base, ("name", "question"), errors)
            if lens is None:
                continue
            name = _string(lens.get("name"), f"{base}.name", errors, maximum=MAX_NAME)
            if name is not None:
                lens_names.append(name)
            _string(lens.get("question"), f"{base}.question", errors)
        _unique(lens_names, "evaluation_lenses", errors)

    _string(root.get("acceptance_journey"), "acceptance_journey", errors)
    non_goals = _list(root.get("non_goals"), "non_goals", errors, minimum=0, maximum=MAX_NON_GOALS)
    if non_goals is not None:
        values: list[str] = []
        for index, item in enumerate(non_goals):
            checked = _string(item, f"non_goals[{index}]", errors)
            if checked is not None:
                values.append(checked)
        _unique(values, "non_goals", errors)

    ecosystem = _expect_object(root.get("ecosystem"), "ecosystem", ("related_repositories",), errors)
    if ecosystem is not None:
        related = _list(ecosystem.get("related_repositories"), "ecosystem.related_repositories", errors, minimum=0, maximum=MAX_ITEMS)
        ids: list[str] = []
        if related is not None:
            for index, item in enumerate(related):
                base = f"ecosystem.related_repositories[{index}]"
                repository = _expect_object(item, base, ("id", "path_hint", "role"), errors)
                if repository is None:
                    continue
                repo_id = _string(repository.get("id"), f"{base}.id", errors, maximum=MAX_ID)
                if repo_id is not None:
                    if not ID_RE.fullmatch(repo_id):
                        errors.append(f"{base}.id: expected lowercase kebab-case")
                    ids.append(repo_id)
                _validate_path_hint(repository.get("path_hint"), f"{base}.path_hint", errors)
                _string(repository.get("role"), f"{base}.role", errors)
            _unique(ids, "ecosystem.related_repositories", errors)

    canonical = canonical_bytes(value)
    if require_canonical and canonical != data:
        errors.append("$: metadata must use canonical two-space JSON with one trailing newline")
    if errors:
        raise ValidationFailure(INVALID, errors)
    return value, canonical


def validate_repository(root_arg: str) -> tuple[dict[str, object], bytes]:
    root = validate_root(root_arg)
    path = metadata_path(root)
    data = read_limited(path)
    return parse_and_validate(data)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: validate_project.py <absolute-git-root>", file=sys.stderr)
        return UNSAFE
    try:
        value, data = validate_repository(argv[1])
    except ValidationFailure as exc:
        for error in exc.errors:
            print(error, file=sys.stderr)
        return exc.code
    project = value["project"]
    identity = project["repository_identity"]
    digest = hashlib.sha256(data).hexdigest()
    print(
        f"valid schema_version=1 project_id={project['id']} "
        f"repository_identity={identity['kind']}:{identity['value']} sha256={digest}"
    )
    return VALID


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
