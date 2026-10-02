#!/usr/bin/env python3
"""Run a PS Vita VPK in Vita3K and report the evidence as one JSON document.

Standard library only. Runs on Python 3.9 or newer.
"""
from __future__ import annotations

import argparse
import hashlib
import math
import os
import re
import shutil
import stat
import struct
import sys
import zipfile
import zlib
from typing import Dict, Iterable, List, Optional, Tuple

EXIT_PASS = 0
EXIT_FAIL = 1
EXIT_USAGE = 2
EXIT_ENVIRONMENT = 3
EXIT_INCONCLUSIVE = 4

SCHEMA_VERSION = 1

# Values measured against the real emulator. They are constants on purpose:
# the script never reads them from a file.
DEFAULT_TIMEOUT = 60.0
DEFAULT_SETTLE = 5.0
INSTALL_TIMEOUT = 30.0
KILL_GRACE = 2.0
INSTALL_MARKER = "installed successfully!"
HEADLESS_RENDERER = "OpenGL"
HEADLESS_ENV = {"LIBGL_ALWAYS_SOFTWARE": "1", "__GLX_VENDOR_LIBRARY_NAME": "mesa"}

HASH_LIMIT = 16 * 1024 * 1024
KEEP_RUNS = 20

TITLE_ID_RE = re.compile(r"[A-Z0-9]{9}")
RUN_DIR_RE = re.compile(r"\d{8}T\d{6}Z-[A-Z0-9]{9}(-\d+)?")
ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]")
LOG_LINE_RE = re.compile(r"^\[\d{2}:\d{2}:\d{2}\.\d{3}\] \|([TDIWEC])\| \[[^\]]*\]: ")
LOG_LEVELS = ("T", "D", "I", "W", "E", "C", "?")
TTY_MARKER = "*** TTY: "
# Files that Vita3K writes by itself. They are not app evidence.
EMULATOR_OWNED_RES = (
    re.compile(r"ux0/user/time\.xml"),
    re.compile(r"ux0/user/\d{2}/user\.xml"),
)

DISPLAY_MODES = ("auto", "xvfb", "host")
EXPECT_KINDS = ("expect-file", "expect-file-contains", "expect-log")
REJECT_KINDS = ("reject-log", "reject-file")


class UsageError(Exception):
    """A bad argument, an unreadable VPK, or a rejected path. Exit code 2."""


class XwdError(ValueError):
    """The XWD dump has a format that the converter does not support."""


# --- Host and instance layout -------------------------------------------------


def detect_host(env: Dict[str, str]) -> str:
    override = env.get("VITA3K_VPK_HOST")
    if override:
        if override not in ("linux", "darwin"):
            raise UsageError("VITA3K_VPK_HOST must be linux or darwin")
        return override
    return "darwin" if sys.platform == "darwin" else "linux"


def home_dir(env: Dict[str, str]) -> str:
    return env.get("HOME") or os.path.expanduser("~")


def instance_root(env: Dict[str, str]) -> str:
    return os.path.abspath(env.get("VITA3K_AGENT_HOME") or os.path.join(home_dir(env), ".vita3k-agent"))


class InstancePaths:
    """Where the dedicated Vita3K instance keeps its files on one host."""

    def __init__(self, root: str, host: str) -> None:
        self.root = os.path.abspath(root)
        self.host = host
        self.emulator_dir = os.path.join(self.root, "emulator")
        if host == "darwin":
            # Portable layout: Vita3K uses a portable/ directory beside its app bundle.
            self.portable_dir: Optional[str] = os.path.join(self.emulator_dir, "portable")
            self.config_file = os.path.join(self.portable_dir, "config.yml")
            self.log_file = os.path.join(self.portable_dir, "vita3k.log")
            self.vita_fs = os.path.join(self.portable_dir, "fs")
        else:
            self.portable_dir = None
            xdg = os.path.join(self.root, "xdg")
            self.config_file = os.path.join(xdg, "config", "Vita3K", "config.yml")
            self.log_file = os.path.join(xdg, "cache", "Vita3K", "vita3k.log")
            self.vita_fs = os.path.join(xdg, "data", "Vita3K", "Vita3K")
        self.runs_dir = os.path.join(self.root, "runs")
        self.lock_file = os.path.join(self.root, "run.lock")
        self.state_file = os.path.join(self.root, "run-state.json")
        self.version_cache = os.path.join(self.root, "emulator-version.json")

    def xdg_env(self) -> Dict[str, str]:
        """Isolation environment for the emulator. Empty on macOS."""
        if self.host == "darwin":
            return {}
        xdg = os.path.join(self.root, "xdg")
        return {
            "XDG_CONFIG_HOME": os.path.join(xdg, "config"),
            "XDG_CACHE_HOME": os.path.join(xdg, "cache"),
            "XDG_DATA_HOME": os.path.join(xdg, "data"),
        }

    def as_dict(self) -> Dict[str, str]:
        return {
            "config_file": self.config_file,
            "log_file": self.log_file,
            "vita_fs": self.vita_fs,
            "runs_dir": self.runs_dir,
            "lock_file": self.lock_file,
            "state_file": self.state_file,
            "version_cache": self.version_cache,
        }


def personal_vita3k_paths(host: str, home: str) -> List[str]:
    """A personal Vita3K install's paths. Only inspected, never written."""
    if host == "darwin":
        return [os.path.join(home, "Library", "Application Support", "Vita3K")]
    return [
        os.path.join(home, ".config", "Vita3K"),
        os.path.join(home, ".cache", "Vita3K"),
        os.path.join(home, ".local", "share", "Vita3K"),
    ]


# --- Binary discovery and privilege check ---------------------------------------


def _is_executable_file(path: str) -> bool:
    return os.path.isfile(path) and os.access(path, os.X_OK)


def macos_bundle_is_isolated(binary: str, paths: InstancePaths) -> bool:
    """True when the binary is <emulator_dir>/<name>.app/Contents/MacOS/<file>
    and <emulator_dir>/portable/ exists."""
    real = os.path.realpath(binary)
    macos_dir = os.path.dirname(real)
    contents_dir = os.path.dirname(macos_dir)
    bundle = os.path.dirname(contents_dir)
    parent = os.path.dirname(bundle)
    return (
        os.path.basename(macos_dir) == "MacOS"
        and os.path.basename(contents_dir) == "Contents"
        and bundle.endswith(".app")
        and parent == os.path.realpath(paths.emulator_dir)
        and os.path.isdir(os.path.join(parent, "portable"))
    )


def discover_binary(paths: InstancePaths, env: Dict[str, str]) -> Tuple[Optional[str], Optional[str]]:
    """Return (binary, reason). reason is None, emulator_missing, or isolation_unavailable."""
    override = env.get("VITA3K_BIN")
    if override:
        candidates = [override]
    elif paths.host == "darwin":
        candidates = [os.path.join(paths.emulator_dir, "Vita3K.app", "Contents", "MacOS", "Vita3K")]
    else:
        candidates = [
            os.path.join(paths.emulator_dir, "squashfs-root", "AppRun"),
            os.path.join(paths.emulator_dir, "Vita3K.AppImage"),
            os.path.join(paths.emulator_dir, "Vita3K-aarch64.AppImage"),
            os.path.join(paths.emulator_dir, "Vita3K-x86_64.AppImage"),
        ]
        on_path = shutil.which("Vita3K", path=env.get("PATH"))
        if on_path:
            candidates.append(on_path)
    binary = None
    for candidate in candidates:
        if _is_executable_file(candidate):
            binary = os.path.abspath(candidate)
            break
    if binary is None:
        return None, "emulator_missing"
    if paths.host == "darwin" and not macos_bundle_is_isolated(binary, paths):
        return binary, "isolation_unavailable"
    return binary, None


def is_privileged(uid: int, euid: int) -> bool:
    """Vita3K shows a dialog that config.yml cannot suppress for these users."""
    return euid == 0 or uid != euid


# --- VPK inspection -----------------------------------------------------------------


def sha256_file(path: str, length: Optional[int] = None) -> str:
    """SHA-256 of the file, or of its first `length` bytes."""
    digest = hashlib.sha256()
    remaining = length
    with open(path, "rb") as handle:
        while remaining is None or remaining > 0:
            chunk = handle.read(1024 * 1024 if remaining is None else min(1024 * 1024, remaining))
            if not chunk:
                break
            digest.update(chunk)
            if remaining is not None:
                remaining -= len(chunk)
    return digest.hexdigest()


def parse_sfo_title_id(data: bytes) -> str:
    """Read the TITLE_ID string from a param.sfo image."""
    if len(data) < 20 or data[:4] != b"\x00PSF":
        raise UsageError("param.sfo: wrong magic")
    _version, key_table, data_table, count = struct.unpack_from("<4I", data, 4)
    if 20 + count * 16 > len(data):
        raise UsageError("param.sfo: truncated index")
    for index in range(count):
        key_offset, fmt, length, _max_length, data_offset = struct.unpack_from("<HHIII", data, 20 + index * 16)
        key_start = key_table + key_offset
        key_end = data.find(b"\x00", key_start) if key_start < len(data) else -1
        if key_end < 0:
            raise UsageError("param.sfo: key offset beyond the file")
        if data[key_start:key_end] != b"TITLE_ID":
            continue
        start = data_table + data_offset
        if fmt not in (0x0004, 0x0204) or start + length > len(data):
            raise UsageError("param.sfo: TITLE_ID entry beyond the file or not a string")
        try:
            return data[start:start + length].split(b"\x00", 1)[0].decode("ascii")
        except UnicodeDecodeError:
            raise UsageError("param.sfo: TITLE_ID is not ASCII")
    raise UsageError("param.sfo: no TITLE_ID entry")


class VpkInfo:
    def __init__(self, path: str, sha256: str, title_id: str, eboot_sha256: str) -> None:
        self.path = path
        self.sha256 = sha256
        self.title_id = title_id
        self.eboot_sha256 = eboot_sha256

    def as_dict(self) -> Dict[str, str]:
        return {
            "path": self.path,
            "sha256": self.sha256,
            "title_id": self.title_id,
            "eboot_sha256": self.eboot_sha256,
        }


def inspect_vpk(path: str) -> VpkInfo:
    """Validate the archive and read what identifies it. Any file name is accepted."""
    path = os.path.abspath(path)
    if not os.path.isfile(path):
        raise UsageError("VPK not found or not a regular file: %s" % path)
    try:
        with zipfile.ZipFile(path) as archive:
            names = set(archive.namelist())
            for member in ("eboot.bin", "sce_sys/param.sfo"):
                if member not in names:
                    raise UsageError("VPK has no %s: %s" % (member, path))
            if archive.getinfo("sce_sys/param.sfo").file_size > 1024 * 1024:
                raise UsageError("VPK param.sfo is too large: %s" % path)
            title_id = parse_sfo_title_id(archive.read("sce_sys/param.sfo"))
            # The title ID becomes a path segment, so its form is checked here.
            if not TITLE_ID_RE.fullmatch(title_id):
                raise UsageError("VPK TITLE_ID %r is not nine characters of A-Z and 0-9" % title_id)
            digest = hashlib.sha256()
            with archive.open("eboot.bin") as member_file:
                for chunk in iter(lambda: member_file.read(1024 * 1024), b""):
                    digest.update(chunk)
        return VpkInfo(path, sha256_file(path), title_id, digest.hexdigest())
    except (zipfile.BadZipFile, zipfile.LargeZipFile, OSError, EOFError, zlib.error, RuntimeError, NotImplementedError) as error:
        raise UsageError("unreadable VPK %s: %s" % (path, error))


# --- Vita path mapping ------------------------------------------------------------


def split_vita_path(spec: str) -> List[str]:
    """Split `ux0:a/b` into ["a", "b"]. Only the ux0: device is accepted."""
    if not spec.startswith("ux0:"):
        raise UsageError("only ux0: paths are accepted: %r" % spec)
    segments = spec[4:].split("/")
    if len(segments) > 1 and segments[-1] == "":
        segments.pop()
    if "\x00" in spec or any(segment in ("", ".", "..") for segment in segments):
        raise UsageError("empty, absolute, or parent-relative ux0: path: %r" % spec)
    return segments


def map_vita_path(vita_fs: str, spec: str) -> Tuple[str, str]:
    """Map `ux0:PATH` to (host path, relative path such as "ux0/PATH").

    The path must stay inside <vita_fs>/ux0/ after symlinks are resolved.
    """
    segments = split_vita_path(spec)
    ux0 = os.path.join(vita_fs, "ux0")
    host_path = os.path.join(ux0, *segments)
    real_root = os.path.realpath(ux0)
    if not os.path.realpath(host_path).startswith(real_root + os.sep):
        raise UsageError("path leaves the emulated ux0: %r" % spec)
    return host_path, "/".join(["ux0"] + segments)


def map_clean_path(vita_fs: str, spec: str, title_id: str) -> str:
    """Validate a --clean target and return its host path.

    The target's parent directories must be real directories. Otherwise a link such
    as ux0/data/link -> ux0/app/OTHER would pass the textual rule and delete elsewhere.
    The target itself may be a symlink: it is unlinked, not followed.
    """
    validate_clean_path(spec, title_id)
    segments = split_vita_path(spec)
    real_ux0 = os.path.realpath(os.path.join(vita_fs, "ux0"))
    host_path = os.path.join(real_ux0, *segments)
    if os.path.realpath(os.path.dirname(host_path)) != os.path.dirname(host_path):
        raise UsageError("--clean path passes through a symlink: %r" % spec)
    return host_path


def validate_clean_path(spec: str, title_id: str) -> None:
    """--clean may only remove app data and the VPK's own save data."""
    segments = split_vita_path(spec)
    in_data = segments[0] == "data" and len(segments) >= 2
    in_own_savedata = segments[:3] == ["user", "00", "savedata"] and len(segments) >= 4 and segments[3] == title_id
    if not (in_data or in_own_savedata):
        raise UsageError(
            "--clean accepts only ux0:data/<name>... and ux0:user/00/savedata/%s...: %r" % (title_id, spec)
        )


def remove_no_follow(path: str) -> None:
    """Delete a file or a tree. A symlink is unlinked, never followed."""
    try:
        info = os.lstat(path)
    except FileNotFoundError:
        return
    if stat.S_ISDIR(info.st_mode):
        for name in os.listdir(path):
            remove_no_follow(os.path.join(path, name))
        os.rmdir(path)
    else:
        os.unlink(path)


def split_contains_arg(arg: str) -> Tuple[str, str]:
    """`ux0:PATH=TEXT` splits at the first `=`."""
    path, separator, text = arg.partition("=")
    if not separator or not text:
        raise UsageError("--expect-file-contains needs ux0:PATH=TEXT: %r" % arg)
    return path, text


def split_seed_arg(arg: str) -> Tuple[str, str]:
    """`HOST_FILE=ux0:PATH` splits at the last `=ux0:`."""
    index = arg.rfind("=ux0:")
    if index <= 0:
        raise UsageError("--seed needs HOST_FILE=ux0:PATH: %r" % arg)
    return arg[:index], arg[index + 1:]


# --- Config seeding -----------------------------------------------------------------


def split_lines(text: str) -> List[str]:
    """Split on newlines only. str.splitlines also splits on form feeds and other separators."""
    lines = [line[:-1] if line.endswith("\r") else line for line in text.split("\n")]
    if lines and lines[-1] == "":
        lines.pop()
    return lines


def config_seed_pairs(display_mode: str) -> List[Tuple[str, str]]:
    pairs = [
        ("show-welcome", "false"),
        ("warn-missing-firmware", "false"),
        ("check-for-updates", "false"),
        ("check-for-updates-mode", "0"),
        ("log-level", "0"),
    ]
    if display_mode == "xvfb":
        pairs.append(("backend-renderer", HEADLESS_RENDERER))
    return pairs


def upsert_config_text(text: str, pairs: Iterable[Tuple[str, str]]) -> str:
    """Set top-level scalar keys. Every other line stays as it is."""
    lines = split_lines(text)
    pending = dict(pairs)
    seen = set()
    for index, line in enumerate(lines):
        key, separator, _rest = line.partition(":")
        if separator and key in pending:
            lines[index] = "%s: %s" % (key, pending[key])
            seen.add(key)
    for key, value in pending.items():
        if key not in seen:
            lines.append("%s: %s" % (key, value))
    return "\n".join(lines) + "\n"


def seed_config(config_file: str, display_mode: str) -> None:
    try:
        with open(config_file, "r", encoding="utf-8", errors="surrogateescape") as handle:
            text = handle.read()
    except FileNotFoundError:
        text = ""
    os.makedirs(os.path.dirname(config_file), exist_ok=True)
    with open(config_file + ".tmp", "w", encoding="utf-8", errors="surrogateescape") as handle:
        handle.write(upsert_config_text(text, config_seed_pairs(display_mode)))
    os.replace(config_file + ".tmp", config_file)


# --- Snapshot, diff, and fresh content ----------------------------------------


def _file_entry(path: str) -> Optional[Dict[str, object]]:
    try:
        info = os.lstat(path)
    except OSError:
        return None
    sha: Optional[str] = None
    try:
        if stat.S_ISLNK(info.st_mode):
            sha = hashlib.sha256(os.fsencode(os.readlink(path))).hexdigest()
        elif stat.S_ISREG(info.st_mode):
            sha = sha256_file(path) if info.st_size <= HASH_LIMIT else None
        else:
            return None
    except OSError:
        pass  # an unreadable file stays in the snapshot without a hash
    return {"size": info.st_size, "mtime_ns": info.st_mtime_ns, "sha256": sha}


def snapshot_paths(vita_fs: str, rel_paths: Iterable[str]) -> Dict[str, Dict[str, object]]:
    snapshot = {}
    for rel in rel_paths:
        entry = _file_entry(os.path.join(vita_fs, *rel.split("/")))
        if entry is not None:
            snapshot[rel] = entry
    return snapshot


def take_snapshot(vita_fs: str, extra_rel_paths: Iterable[str] = ()) -> Dict[str, Dict[str, object]]:
    """Record every file under ux0/ except ux0/app/, plus the named paths.

    ux0/app/ is left out because every run reinstalls the title there.
    Symlinks are recorded and never followed.
    """
    snapshot = {}
    ux0 = os.path.join(vita_fs, "ux0")
    for directory, subdirs, files in os.walk(ux0):
        if directory == ux0 and "app" in subdirs:
            subdirs.remove("app")
        links = [name for name in subdirs if os.path.islink(os.path.join(directory, name))]
        for name in files + links:
            path = os.path.join(directory, name)
            entry = _file_entry(path)
            if entry is not None:
                snapshot[os.path.relpath(path, vita_fs).replace(os.sep, "/")] = entry
    snapshot.update(snapshot_paths(vita_fs, extra_rel_paths))
    return snapshot


def change_kind(before: Optional[Dict[str, object]], after: Optional[Dict[str, object]]) -> Optional[str]:
    """created, modified, deleted, or None. A file is fresh when created or modified."""
    if before is None:
        return None if after is None else "created"
    if after is None:
        return "deleted"
    return None if before == after else "modified"


def is_emulator_owned(rel: str) -> bool:
    return any(pattern.fullmatch(rel) for pattern in EMULATOR_OWNED_RES)


def diff_snapshots(
    before: Dict[str, Dict[str, object]], after: Dict[str, Dict[str, object]]
) -> Dict[str, List[Dict[str, object]]]:
    """The fs_diff object of the result. Emulator-owned paths get their own list."""
    diff: Dict[str, List[Dict[str, object]]] = {"created": [], "modified": [], "deleted": [], "emulator_owned": []}
    for rel in sorted(set(before) | set(after)):
        kind = change_kind(before.get(rel), after.get(rel))
        if kind is None:
            continue
        if is_emulator_owned(rel):
            diff["emulator_owned"].append({"path": rel, "change": kind})
        elif kind == "deleted":
            diff["deleted"].append({"path": rel})
        else:
            entry = after[rel]
            diff[kind].append({"path": rel, "size": entry["size"], "sha256": entry["sha256"]})
    return diff


def has_unhashed_change(before: Dict[str, Dict[str, object]], after: Dict[str, Dict[str, object]]) -> bool:
    """True when a fresh file was too large to hash on either side."""
    for rel, entry in after.items():
        old = before.get(rel)
        if change_kind(old, entry) is not None and (entry["sha256"] is None or (old and old["sha256"] is None)):
            return True
    return False


def fresh_offset(path: str, before: Optional[Dict[str, object]], after: Dict[str, object]) -> int:
    """Where the fresh content of a fresh file starts.

    A file that grew and still starts with its old bytes was appended to, so
    only the new bytes are fresh. Every other fresh file is fresh as a whole.
    """
    if before is None or before["sha256"] is None:
        return 0
    old_size = int(before["size"])  # type: ignore[arg-type]
    if int(after["size"]) > old_size:  # type: ignore[arg-type]
        try:
            if sha256_file(path, old_size) == before["sha256"]:
                return old_size
        except OSError:
            return 0
    return 0


def file_contains(path: str, offset: int, needle: bytes) -> bool:
    """Search the file from `offset` without loading it as a whole."""
    overlap = b""
    with open(path, "rb") as handle:
        handle.seek(offset)
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            window = overlap + chunk
            if needle in window:
                return True
            overlap = window[-(len(needle) - 1):] if len(needle) > 1 else b""
    return False


# --- Log parsing --------------------------------------------------------------------


def clean_log_lines(text: str) -> List[str]:
    return [ANSI_RE.sub("", line) for line in split_lines(text)]


def read_log_lines(path: str) -> List[str]:
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            return clean_log_lines(handle.read())
    except OSError:
        return []


def log_level(line: str) -> str:
    """The level letter of a Vita3K log line, or `?` for any other line."""
    match = LOG_LINE_RE.match(line)
    return match.group(1) if match else "?"


def summarize_log(lines: List[str], source: str) -> Dict[str, object]:
    levels = dict((level, 0) for level in LOG_LEVELS)
    errors: List[str] = []
    tty: List[str] = []
    for line in lines:
        level = log_level(line)
        levels[level] += 1
        if level in ("E", "C") and len(errors) < 20:
            errors.append(line)
        if TTY_MARKER in line and len(tty) < 200:
            tty.append(line)
    return {
        "source": source,
        "line_count": len(lines),
        "levels": levels,
        "errors": errors,
        "tty": tty,
        "tail": lines[-40:],
    }


# --- XWD conversion -----------------------------------------------------------------


def _mask_shift(mask: int) -> int:
    shift = 0
    while mask and not mask & 1:
        mask >>= 1
        shift += 1
    return shift


def xwd_to_png(xwd_bytes: bytes) -> bytes:
    """Convert an XWD version-7 ZPixmap dump of 24 or 32 bits per pixel to an 8-bit RGB PNG.

    Row length comes from bytes_per_line and pixel size from bits_per_pixel.
    They are independent: Xvfb pads rows of 3-byte pixels.
    """
    if len(xwd_bytes) < 100:
        raise XwdError("truncated XWD header")
    fields = struct.unpack(">25I", xwd_bytes[:100])
    header_size, version, pixmap_format, _depth, width, height = fields[:6]
    byte_order = fields[7]
    bits_per_pixel, bytes_per_line = fields[11], fields[12]
    masks = fields[14:17]
    ncolors = fields[19]
    if version != 7:
        raise XwdError("unsupported XWD version %d" % version)
    if pixmap_format != 2 or bits_per_pixel not in (24, 32):
        raise XwdError("unsupported XWD pixmap format")
    pixel_size = bits_per_pixel // 8
    if header_size < 100 or width < 1 or height < 1 or bytes_per_line < width * pixel_size:
        raise XwdError("inconsistent XWD header")
    offset = header_size + ncolors * 12
    if len(xwd_bytes) < offset + bytes_per_line * height:
        raise XwdError("truncated XWD pixel data")
    shifts = [_mask_shift(mask) for mask in masks]
    if not all(mask == 0xFF << shift and shift % 8 == 0 and shift // 8 < pixel_size for mask, shift in zip(masks, shifts)):
        raise XwdError("unsupported XWD channel masks")
    # Byte position of each channel inside a pixel. Every mask covers one whole byte.
    channel_index = [shift // 8 if byte_order == 0 else pixel_size - 1 - shift // 8 for shift in shifts]
    rows = []
    for y in range(height):
        start = offset + y * bytes_per_line
        line = xwd_bytes[start:start + width * pixel_size]
        out = bytearray(1 + width * 3)
        for channel in range(3):
            out[1 + channel::3] = line[channel_index[channel]::pixel_size]
        rows.append(bytes(out))

    def chunk(kind: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(b"".join(rows), 6))
        + chunk(b"IEND", b"")
    )


# --- Expectations and verdict ---------------------------------------------------


class Expectation:
    """One --expect-* or --reject-* condition."""

    def __init__(
        self,
        kind: str,
        target: str,
        rel: Optional[str] = None,
        host_path: Optional[str] = None,
        text: Optional[str] = None,
        regex: Optional["re.Pattern[str]"] = None,
    ) -> None:
        self.kind = kind
        self.target = target
        self.rel = rel
        self.host_path = host_path
        self.text = text
        self.regex = regex

    def unevaluated(self) -> Dict[str, object]:
        return {"kind": self.kind, "target": self.target, "satisfied": False, "detail": "not_evaluated"}


def _first_match(regex: "re.Pattern[str]", lines: List[str]) -> Optional[str]:
    for number, line in enumerate(lines, 1):
        if regex.search(line):
            return "line %d: %s" % (number, line[:200])
    return None


def evaluate_expectation(
    expectation: Expectation,
    before: Dict[str, Dict[str, object]],
    after: Dict[str, Dict[str, object]],
    log_lines: List[str],
) -> Dict[str, object]:
    """`satisfied` is true when the condition supports a pass: an expectation
    that holds, or a reject condition that did not occur."""
    kind = expectation.kind
    if kind in ("expect-log", "reject-log"):
        match = _first_match(expectation.regex, log_lines)  # type: ignore[arg-type]
        satisfied = (match is not None) == (kind == "expect-log")
        detail = match or "no line matched"
    else:
        old, new = before.get(expectation.rel), after.get(expectation.rel)  # type: ignore[arg-type]
        change = change_kind(old, new)
        fresh = change in ("created", "modified")
        if new is None:
            detail = "missing"
        elif not fresh:
            detail = "stale: unchanged since the boot launch started"
        else:
            detail = str(change)
        satisfied = fresh
        if kind == "reject-file":
            satisfied = not fresh
        elif kind == "expect-file-contains" and fresh:
            offset = fresh_offset(expectation.host_path, old, new)  # type: ignore[arg-type]
            scope = "appended bytes" if offset else "whole file"
            try:
                satisfied = file_contains(expectation.host_path, offset, expectation.text.encode("utf-8", "surrogateescape"))  # type: ignore[arg-type,union-attr]
            except OSError:
                satisfied = False
            detail = "%s, text %s in fresh content (%s)" % (change, "found" if satisfied else "not found", scope)
    return {"kind": kind, "target": expectation.target, "satisfied": satisfied, "detail": detail}


def decide_verdict(
    lifecycle_reason: Optional[str], crashed: bool, expectations: List[Dict[str, object]]
) -> Tuple[str, Optional[str]]:
    """Apply the verdict rules in order. The first match wins. Log severity is never a rule."""
    if lifecycle_reason:
        return "environment_error", lifecycle_reason
    if crashed:
        return "fail", "emulator_crashed"
    if any(not item["satisfied"] for item in expectations if item["kind"] in REJECT_KINDS):
        return "fail", "reject_matched"
    expects = [item for item in expectations if item["kind"] in EXPECT_KINDS]
    if any(not item["satisfied"] for item in expects):
        return "fail", "expectation_unmet"
    if expects:
        return "pass", None
    return "inconclusive", "no_expectations"


def exit_code_for(verdict: str) -> int:
    return {"pass": EXIT_PASS, "fail": EXIT_FAIL, "inconclusive": EXIT_INCONCLUSIVE}.get(verdict, EXIT_ENVIRONMENT)


def exit_signal(return_code: Optional[int]) -> Optional[int]:
    """The signal behind a process-group leader's return code, if any.

    A signalled leader has a negative code. A shell wrapper, as in the Linux
    AppImage, reports its signalled child as 128 + signal.
    """
    if return_code is None:
        return None
    if return_code < 0:
        return -return_code
    return return_code - 128 if 128 < return_code <= 128 + 64 else None


# --- Run directories ----------------------------------------------------------------


def create_run_dir(runs_dir: str, stamp: str, title_id: str) -> str:
    """Create runs/<stamp>-<TITLE_ID>[-N]/. A run directory is never reused.

    Name order is creation order, except from the tenth directory of one second
    and title on: the suffix -10 sorts before -2.
    """
    os.makedirs(runs_dir, exist_ok=True)
    base = os.path.join(runs_dir, "%s-%s" % (stamp, title_id))
    suffix = 1
    while True:
        path = base if suffix == 1 else "%s-%d" % (base, suffix)
        try:
            os.mkdir(path)
            return path
        except FileExistsError:
            suffix += 1


def prune_run_dirs(runs_dir: str, current: str, keep: int = KEEP_RUNS) -> List[str]:
    """Delete the oldest run directories, by name order, beyond the newest `keep`."""
    try:
        names = sorted(os.listdir(runs_dir))
    except OSError:
        return []
    matching = []
    for name in names:
        path = os.path.join(runs_dir, name)
        try:
            if RUN_DIR_RE.fullmatch(name) and stat.S_ISDIR(os.lstat(path).st_mode):
                matching.append(path)
        except OSError:
            continue
    removed = []
    for path in matching[:max(0, len(matching) - keep)]:
        if os.path.abspath(path) == os.path.abspath(current):
            continue
        try:
            remove_no_follow(path)
            removed.append(path)
        except OSError:
            continue  # housekeeping must not fail a finished run
    return removed


# --- Command line -------------------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="vita3k_vpk.py",
        description="Run a PS Vita VPK in a dedicated Vita3K instance and report the evidence as JSON.",
        allow_abbrev=False,
    )
    commands = parser.add_subparsers(dest="command", required=True)

    doctor = commands.add_parser("doctor", allow_abbrev=False, help="report whether the host is ready to run a VPK")
    doctor.add_argument("--display", choices=DISPLAY_MODES, default="auto")

    run = commands.add_parser("run", allow_abbrev=False, help="install and boot one VPK, then report the evidence")
    run.add_argument("vpk", help="path of the built VPK")
    run.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT, metavar="SECS")
    run.add_argument("--stop-when-satisfied", action="store_true")
    run.add_argument("--settle", type=float, default=DEFAULT_SETTLE, metavar="SECS")
    run.add_argument("--seed", action="append", default=[], metavar="HOST_FILE=ux0:PATH")
    run.add_argument("--clean", action="append", default=[], metavar="ux0:PATH")
    run.add_argument("--expect-file", action="append", default=[], metavar="ux0:PATH")
    run.add_argument("--expect-file-contains", action="append", default=[], metavar="ux0:PATH=TEXT")
    run.add_argument("--expect-log", action="append", default=[], metavar="REGEX")
    run.add_argument("--reject-log", action="append", default=[], metavar="REGEX")
    run.add_argument("--reject-file", action="append", default=[], metavar="ux0:PATH")
    run.add_argument("--display", choices=DISPLAY_MODES, default="auto")
    run.add_argument("--no-screenshot", action="store_true")
    return parser


def resolve_display_mode(requested: str, host: str, env: Dict[str, str]) -> str:
    if requested != "auto":
        return requested
    if host == "darwin" or env.get("DISPLAY") or env.get("WAYLAND_DISPLAY"):
        return "host"
    return "xvfb"


class RunPlan:
    """The validated arguments of one `run`."""

    def __init__(self) -> None:
        self.expectations: List[Expectation] = []
        self.seeds: List[Tuple[str, str]] = []
        self.cleans: List[str] = []


def build_run_plan(args: argparse.Namespace, paths: InstancePaths, vpk: VpkInfo) -> RunPlan:
    """Validate every path and pattern before anything is changed."""
    plan = RunPlan()
    if not (math.isfinite(args.timeout) and args.timeout > 0 and math.isfinite(args.settle) and args.settle >= 0):
        raise UsageError("--timeout must be a positive number and --settle must not be negative")

    def file_expectation(kind: str, target: str, spec: str, text: Optional[str] = None) -> None:
        host_path, rel = map_vita_path(paths.vita_fs, spec)
        plan.expectations.append(Expectation(kind, target, rel=rel, host_path=host_path, text=text))

    def log_expectation(kind: str, pattern: str) -> None:
        try:
            plan.expectations.append(Expectation(kind, pattern, regex=re.compile(pattern)))
        except re.error as error:
            raise UsageError("--%s: invalid regular expression %r: %s" % (kind, pattern, error))

    for spec in args.expect_file:
        file_expectation("expect-file", spec, spec)
    for arg in args.expect_file_contains:
        spec, text = split_contains_arg(arg)
        file_expectation("expect-file-contains", arg, spec, text)
    for pattern in args.expect_log:
        log_expectation("expect-log", pattern)
    for pattern in args.reject_log:
        log_expectation("reject-log", pattern)
    for spec in args.reject_file:
        file_expectation("reject-file", spec, spec)
    if args.stop_when_satisfied and not any(item.kind in EXPECT_KINDS for item in plan.expectations):
        raise UsageError("--stop-when-satisfied needs at least one --expect-* option")

    for arg in args.seed:
        host_file, spec = split_seed_arg(arg)
        if not os.path.isfile(host_file):
            raise UsageError("--seed host file not found or not a regular file: %s" % host_file)
        plan.seeds.append((os.path.abspath(host_file), map_vita_path(paths.vita_fs, spec)[0]))
    for spec in args.clean:
        plan.cleans.append(map_clean_path(paths.vita_fs, spec, vpk.title_id))
    return plan
