#!/usr/bin/env python3
"""Stub Vita3K for the skill tests.

It mimics the observable contract of the emulator and nothing else: the
argument forms, the paths it uses, the log lines the script reads, and how it
reacts to SIGTERM. STUB_MODE changes one launch. See the mode table in the
functions below.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import resource
import shutil
import signal
import struct
import sys
import time
import zipfile


def stamp() -> str:
    now = time.time()
    return "%s.%03d" % (time.strftime("%H:%M:%S", time.localtime(now)), int(now * 1000) % 1000)


def log(level: str, function: str, message: str) -> None:
    sys.stdout.write("[%s] |%s| [%s]: %s\n" % (stamp(), level, function, message))
    sys.stdout.flush()


def layout() -> dict:
    """Resolve paths the way Vita3K does: a portable/ directory beside the app
    bundle wins. Otherwise the XDG variables decide."""
    here = Path(__file__).resolve()
    home = Path(os.environ.get("HOME") or "~").expanduser()
    parents = here.parents
    if len(parents) >= 4 and parents[0].name == "MacOS" and parents[1].name == "Contents" and parents[2].name.endswith(".app"):
        portable = parents[3] / "portable"
        if portable.is_dir():
            return {
                "log": portable / "vita3k.log",
                "fs": portable / "fs",
                "personal": home / "Library" / "Application Support" / "Vita3K",
            }
    cache = Path(os.environ.get("XDG_CACHE_HOME") or home / ".cache")
    data = Path(os.environ.get("XDG_DATA_HOME") or home / ".local" / "share")
    return {
        "log": cache / "Vita3K" / "vita3k.log",
        "fs": data / "Vita3K" / "Vita3K",
        "personal": home / ".config" / "Vita3K",
    }


def record(launch: str, variable: str = "STUB_RECORD") -> None:
    target = os.environ.get(variable)
    if target:
        with open(target, "a", encoding="utf-8") as handle:
            entry = {
                "launch": launch, "argv": sys.argv[1:], "env": dict(os.environ), "pid": os.getpid(),
                "time": time.time(),
            }
            handle.write(json.dumps(entry) + "\n")


def open_log(paths: dict, mode: str) -> None:
    """Vita3K truncates its log file at every start."""
    target = paths["log"]
    if mode == "wrong_paths":
        target = Path(os.environ.get("HOME") or "~").expanduser() / "stub-wrong-paths.log"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("")


def title_id_of(vpk: str) -> str:
    with zipfile.ZipFile(vpk) as archive:
        sfo = archive.read("sce_sys/param.sfo")
    key_table, data_table, count = struct.unpack_from("<3I", sfo, 8)
    for index in range(count):
        key_offset, _fmt, length, _max, data_offset = struct.unpack_from("<HHIII", sfo, 20 + index * 16)
        key = sfo[key_table + key_offset:].split(b"\x00", 1)[0]
        if key == b"TITLE_ID":
            return sfo[data_table + data_offset:data_table + data_offset + length].split(b"\x00", 1)[0].decode("ascii")
    raise SystemExit("stub: no TITLE_ID")


def idle() -> None:
    while True:
        time.sleep(3600)


def install(paths: dict, mode: str, vpk: str) -> None:
    if mode == "install_noload":
        sys.exit(127)  # a binary that cannot load its libraries never opens its log
    if mode == "install_hang":
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
    open_log(paths, mode)
    if mode == "install_fail":
        log("E", "install_archive_content", "stub install failed")
        sys.exit(1)
    title_id = title_id_of(vpk)
    app_dir = paths["fs"] / "ux0" / "app" / title_id
    if mode != "install_silent":
        shutil.rmtree(app_dir, ignore_errors=True)
        app_dir.mkdir(parents=True)
        with zipfile.ZipFile(vpk) as archive:
            archive.extractall(app_dir)
        if mode == "install_wrong_eboot":
            (app_dir / "eboot.bin").write_bytes(b"different bytes")
    log("I", "install_archive_content", "stub (App) [%s] installed successfully!" % title_id)
    # The real emulator logs this and then stays idle in its window.
    log("I", "main", "Content installed, will auto-boot: %s" % title_id)
    idle()


def boot(paths: dict, mode: str, title_id: str) -> None:
    ux0 = paths["fs"] / "ux0"
    if not (ux0 / "app" / title_id).is_dir():
        sys.exit(1)
    # Vita3K ignores SIGTERM while an app runs. The stub notes that the signal arrived.
    signal.signal(signal.SIGTERM, lambda _signum, _frame: record("sigterm", "STUB_SIGNALS"))
    open_log(paths, mode)
    log("I", "stub", "Game started: stub (%s)" % title_id)
    log("T", "write_file", "*** TTY: stub ready")
    data = ux0 / "data" / "stub"
    data.mkdir(parents=True, exist_ok=True)
    if mode != "no_evidence":
        (data / "out.txt").write_text("stub evidence for %s\n" % title_id)
    (ux0 / "temp").mkdir(exist_ok=True)
    (ux0 / "temp" / "stub.tmp").write_text("tmp")
    (ux0 / "user").mkdir(exist_ok=True)
    (ux0 / "user" / "time.xml").write_text("<time/>")
    if mode == "append":
        with open(data / "startup.log", "a", encoding="utf-8") as handle:
            handle.write(os.environ.get("STUB_APPEND_LINE", "stub appended line") + "\n")
    if mode == "big_file":
        with open(data / "big.bin", "wb") as handle:
            handle.truncate(17 * 1024 * 1024)  # sparse, above the script's hashing limit
    if mode == "touch_personal":
        paths["personal"].mkdir(parents=True, exist_ok=True)
        (paths["personal"] / "touched").write_text("x")
    if mode == "late_error":
        # Later than a run that stops at once (one poll, then the 2-second kill grace)
        # and earlier than a 5-second settle period.
        time.sleep(4)
        log("E", "stub", "late error")
    if mode == "exit_early":
        time.sleep(1)
        sys.exit(0)
    if mode == "crash":
        time.sleep(1)
        if sys.platform == "darwin":
            # A real SIGSEGV makes macOS write a crash report for every test run.
            # The shell wrapper reports the same status either way.
            os._exit(128 + signal.SIGSEGV)
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
        os.kill(os.getpid(), signal.SIGSEGV)
    idle()


def main() -> None:
    argv = sys.argv[1:]
    mode = os.environ.get("STUB_MODE") or "ok"
    paths = layout()
    if "--version" in argv:
        record("version")
        open_log(paths, "ok")
        if mode == "version_fail":
            print("stub: error while loading shared libraries: libstub.so.1", flush=True)
            sys.exit(127)
        print("Vita3K v0.0.0 stub", flush=True)
        sys.exit(0)
    if "--" in argv and argv.index("--") + 1 < len(argv):
        record("install")
        install(paths, mode, argv[argv.index("--") + 1])
    if "-r" in argv and argv.index("-r") + 1 < len(argv):
        record("boot")
        boot(paths, mode, argv[argv.index("-r") + 1])
    # A VPK path without the `--` separator is ignored, as in Vita3K: the window stays idle.
    record("none")
    open_log(paths, mode)
    idle()


if __name__ == "__main__":
    main()
