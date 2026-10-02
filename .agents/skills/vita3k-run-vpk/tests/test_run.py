from __future__ import annotations

import json
import os
import contextlib
import io
from pathlib import Path
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

SKILL_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = SKILL_ROOT / "scripts" / "vita3k_vpk.py"
TESTS = Path(__file__).resolve().parent
STUB = TESTS / "stub_vita3k.py"
FIXTURES = TESTS / "fixtures"
sys.path.insert(0, str(SKILL_ROOT / "scripts"))
sys.path.insert(0, str(TESTS))

import test_core  # noqa: E402
import vita3k_vpk as v  # noqa: E402

TITLE = "STUB00001"
OUT = "ux0:data/stub/out.txt"
OUT_TEXT = "stub evidence for " + TITLE
HAS_XVFB = shutil.which("Xvfb") is not None and shutil.which("xwd") is not None


def alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    # A zombie still answers. `ps` tells it apart.
    state = subprocess.run(["ps", "-o", "stat=", "-p", str(pid)], stdout=subprocess.PIPE).stdout.decode().strip()
    return bool(state) and not state.startswith("Z")


def wait_for(condition, seconds: float = 15.0):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        value = condition()
        if value:
            return value
        time.sleep(0.02)
    raise AssertionError("condition not met within %s seconds" % seconds)


class RunCase(unittest.TestCase):
    """Runs the script as a subprocess against the stub emulator in a temporary instance."""

    def setUp(self) -> None:
        self._temp = tempfile.TemporaryDirectory()
        self.addCleanup(self._temp.cleanup)
        self.tmp = Path(self._temp.name).resolve()
        self.home = self.tmp / "home"
        self.home.mkdir()
        self.inst = self.tmp / "inst"
        self.record_file = self.tmp / "record.jsonl"
        self.vpk = test_core.make_vpk(self.tmp / "game.vpk", TITLE, b"stub eboot", (("assets/a.txt", b"asset"),))
        self.layout = "linux"
        self.addCleanup(self.kill_recorded)

    def kill_recorded(self) -> None:
        """Kill a stub that a failed test left behind. A recorded ID may have been reused since."""
        for entry in self.records():
            command = subprocess.run(
                ["ps", "-o", "command=", "-p", str(entry["pid"])], stdout=subprocess.PIPE,
            ).stdout.decode()
            if str(STUB) in command or str(self.tmp) in command:
                try:
                    os.kill(entry["pid"], signal.SIGKILL)
                except OSError:
                    pass

    def env(self, layout: str = "linux", mode: str = "", **extra: str) -> dict:
        """Build the instance for one host layout and return the environment to run with."""
        self.layout = layout
        env = {
            # The stub's shebang resolves python3 through PATH. Keep it the interpreter under test.
            "PATH": os.path.dirname(sys.executable) + os.pathsep + os.environ.get("PATH", ""),
            "HOME": str(self.home),
            "VITA3K_AGENT_HOME": str(self.inst),
            "VITA3K_VPK_HOST": layout,
            "VITA3K_VPK_INSTALL_TIMEOUT": "3",
            "STUB_RECORD": str(self.record_file),
            "STUB_SIGNALS": str(self.tmp / "signals.jsonl"),
            "STUB_MODE": mode,
        }
        if layout == "darwin":
            binary = self.inst / "emulator" / "Vita3K.app" / "Contents" / "MacOS" / "Vita3K"
            if not binary.exists():
                binary.parent.mkdir(parents=True)
                shutil.copy(STUB, binary)
                binary.chmod(0o755)
                (self.inst / "emulator" / "portable").mkdir()
        else:
            env["VITA3K_BIN"] = str(STUB)
        env.update(extra)
        return env

    @property
    def paths(self) -> v.InstancePaths:
        return v.InstancePaths(str(self.inst), self.layout)

    @property
    def ux0(self) -> Path:
        return Path(self.paths.vita_fs) / "ux0"

    def command(self, *arguments: str) -> list:
        return [sys.executable, str(SCRIPT), *arguments]

    def script(self, env: dict, *arguments: str, timeout: float = 60.0) -> tuple:
        done = subprocess.run(
            self.command(*arguments), env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout,
        )
        stdout = done.stdout.decode()
        return done.returncode, (json.loads(stdout) if stdout.strip() else None), done.stderr.decode()

    def run_vpk(self, env: dict, *arguments: str, vpk: Path | None = None) -> tuple:
        code, result, stderr = self.script(env, "run", str(vpk or self.vpk), "--display", "host", *arguments)
        self.assertIsNotNone(result, stderr)
        return code, result

    def quick(self, env: dict, *arguments: str, vpk: Path | None = None) -> tuple:
        """A run that stops as soon as its expectations hold."""
        return self.run_vpk(env, "--timeout", "10", "--stop-when-satisfied", "--settle", "0", *arguments, vpk=vpk)

    def spawn(self, command: list, **options) -> subprocess.Popen:
        """Start a process that is killed and reaped when the test ends."""
        process = subprocess.Popen(command, **options)

        def reap() -> None:
            if process.poll() is None:
                process.kill()
            process.communicate()

        self.addCleanup(reap)
        return process

    def start(self, env: dict, *arguments: str, display: str = "host") -> subprocess.Popen:
        return self.spawn(
            self.command("run", str(self.vpk), "--display", display, *arguments),
            env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )

    def reset(self) -> None:
        """Start over with an empty instance and an empty launch record."""
        if self.record_file.exists():
            self.record_file.unlink()
        shutil.rmtree(self.inst, ignore_errors=True)

    def records(self) -> list:
        try:
            return [json.loads(line) for line in self.record_file.read_text().splitlines()]
        except FileNotFoundError:
            return []

    def launches(self) -> list:
        return [entry["launch"] for entry in self.records()]

    def wait_for_launch(self, launch: str) -> dict:
        return wait_for(lambda: next((entry for entry in self.records() if entry["launch"] == launch), None))

    def assert_no_stub_left(self) -> None:
        for entry in self.records():
            wait_for(lambda: not alive(entry["pid"]), 5.0)
        self.assertFalse(os.path.exists(self.paths.state_file))

    def created(self, result: dict) -> list:
        return [item["path"] for item in result["fs_diff"]["created"]]


class VerdictRunTests(RunCase):
    def both_layouts(self):
        for layout in ("linux", "darwin"):
            self.reset()
            with self.subTest(layout=layout):
                yield self.env(layout)

    def test_pass_with_fresh_file(self) -> None:
        for env in self.both_layouts():
            code, result = self.quick(env, "--expect-file-contains", "%s=%s" % (OUT, OUT_TEXT))
            self.assertEqual((code, result["verdict"], result["reason"]), (0, "pass", None))
            self.assertIn("ux0/data/stub/out.txt", self.created(result))
            self.assertIn("stopped_early", result["warnings"])
            run_dir = Path(result["paths"]["run_dir"])
            self.assertEqual(json.loads((run_dir / "result.json").read_text()), result)
            self.assertEqual((run_dir / "evidence" / "data" / "stub" / "out.txt").read_text(), OUT_TEXT + "\n")
            self.assertEqual(result["paths"]["vita_fs"], self.paths.vita_fs)
            self.assertTrue(os.path.samefile(result["paths"]["log_copy"], run_dir / "vita3k.log"))
            self.assertIsNone(result["paths"]["screenshot"])
            self.assertEqual(result["host"], {"os": self.layout, "arch": v.platform.machine(), "display_mode": "host"})
            self.assertEqual(result["emulator"]["version"], "Vita3K v0.0.0 stub")
            self.assertEqual(result["emulator"]["sha256"], v.sha256_file(result["emulator"]["path"]))
            self.assertEqual(result["vpk"]["title_id"], TITLE)
            stages = result["stages"]
            self.assertEqual((stages["installed"], stages["install_logged"], stages["eboot_matches"]), (True, True, True))
            # SIGTERM is enough for an install launch, where no app runs.
            self.assertEqual(stages["install_exit_code"], -signal.SIGTERM)
            self.assertEqual(result["schema_version"], 1)
            self.assertTrue(os.path.isfile(self.paths.config_file))
            self.assert_no_stub_left()

    def test_inconclusive_without_expectation(self) -> None:
        for env in self.both_layouts():
            code, result = self.run_vpk(env, "--timeout", "1")
            self.assertEqual((code, result["verdict"], result["reason"]), (4, "inconclusive", "no_expectations"))
            self.assertEqual(result["warnings"], [])
            self.assertEqual(result["log_summary"]["source"], "emulator-stdout.log")
            self.assertTrue(any("*** TTY: stub ready" in line for line in result["log_summary"]["tty"]))

    def test_fail_without_evidence(self) -> None:
        for env in self.both_layouts():
            code, result = self.run_vpk(dict(env, STUB_MODE="no_evidence"), "--timeout", "1", "--expect-file", OUT)
            self.assertEqual((code, result["verdict"], result["reason"]), (1, "fail", "expectation_unmet"))
            self.assertEqual(result["expectations"], [
                {"kind": "expect-file", "target": OUT, "satisfied": False, "detail": "missing"},
            ])

    def test_stale_file_is_not_evidence(self) -> None:
        for env in self.both_layouts():
            stale = self.ux0 / "data" / "stub" / "out.txt"
            stale.parent.mkdir(parents=True)
            stale.write_text(OUT_TEXT + "\n")
            code, result = self.run_vpk(
                dict(env, STUB_MODE="no_evidence"), "--timeout", "1", "--expect-file-contains", "%s=%s" % (OUT, OUT_TEXT),
            )
            self.assertEqual((code, result["verdict"]), (1, "fail"))
            self.assertIn("stale", result["expectations"][0]["detail"])
            self.assertEqual(self.created(result), ["ux0/temp/stub.tmp"])
            every_path = [item["path"] for kind in ("created", "modified", "deleted") for item in result["fs_diff"][kind]]
            self.assertFalse(any(path.startswith("ux0/app/") for path in every_path))
            self.assertEqual(result["fs_diff"]["emulator_owned"], [{"path": "ux0/user/time.xml", "change": "created"}])
            self.assertTrue((self.ux0 / "app" / TITLE / "assets" / "a.txt").is_file())

    def test_stale_appended_line_is_not_evidence(self) -> None:
        env = self.env(mode="append", STUB_APPEND_LINE="sha-new booted")
        log = self.ux0 / "data" / "stub" / "startup.log"
        log.parent.mkdir(parents=True)
        log.write_text("sha-old booted\n")
        code, result = self.run_vpk(env, "--timeout", "1", "--expect-file-contains", "ux0:data/stub/startup.log=sha-old booted")
        self.assertEqual((code, result["verdict"]), (1, "fail"))
        self.assertIn("appended bytes", result["expectations"][0]["detail"])
        code, result = self.quick(env, "--expect-file-contains", "ux0:data/stub/startup.log=sha-new booted")
        self.assertEqual((code, result["verdict"]), (0, "pass"))
        self.assertEqual([item["path"] for item in result["fs_diff"]["modified"]][:1], ["ux0/data/stub/out.txt"])

    def test_log_expectations_read_the_boot_launch_only(self) -> None:
        env = self.env()
        code, result = self.run_vpk(env, "--timeout", "1", "--expect-file", OUT, "--reject-log", r"\*\*\* TTY: stub ready")
        self.assertEqual((code, result["verdict"], result["reason"]), (1, "fail", "reject_matched"))
        code, result = self.run_vpk(env, "--timeout", "1", "--expect-log", "installed successfully!")
        self.assertEqual((code, result["verdict"], result["reason"]), (1, "fail", "expectation_unmet"))
        code, result = self.quick(env, "--expect-log", "Game started: stub")
        self.assertEqual((code, result["verdict"]), (0, "pass"))

    def test_early_stop_observes_only_the_time_before_it(self) -> None:
        env = self.env(mode="late_error")
        arguments = ("--timeout", "20", "--stop-when-satisfied", "--expect-file", OUT, "--reject-log", "late error")
        code, result = self.run_vpk(env, *arguments, "--settle", "5")
        self.assertEqual((code, result["verdict"], result["reason"]), (1, "fail", "reject_matched"))
        code, result = self.run_vpk(env, *arguments, "--settle", "0")
        self.assertEqual((code, result["verdict"]), (0, "pass"))
        self.assertIn("stopped_early", result["warnings"])

    def test_reject_file(self) -> None:
        code, result = self.run_vpk(self.env(), "--timeout", "1", "--reject-file", OUT)
        self.assertEqual((code, result["verdict"], result["reason"]), (1, "fail", "reject_matched"))
        code, result = self.quick(self.env(mode="no_evidence"), "--reject-file", OUT, "--expect-log", "Game started")
        self.assertEqual((code, result["verdict"]), (0, "pass"))

    def test_large_changed_file_is_flagged(self) -> None:
        code, result = self.run_vpk(self.env(mode="big_file"), "--timeout", "1")
        big = [item for item in result["fs_diff"]["created"] if item["path"] == "ux0/data/stub/big.bin"]
        self.assertEqual(big, [{"path": "ux0/data/stub/big.bin", "size": 17 * 1024 * 1024, "sha256": None}])
        self.assertIn("large_file_unhashed", result["warnings"])
        self.assertFalse((Path(result["paths"]["run_dir"]) / "evidence" / "data" / "stub" / "big.bin").exists())

    def test_usage_errors_print_nothing_on_stdout(self) -> None:
        cases = [
            ("run", str(self.vpk), "--stop-when-satisfied"),
            ("run", str(self.vpk), "--expect-file", "app0:x"),
            ("run", str(self.tmp / "absent.vpk")),
            ("run", str(self.vpk), "--unknown-option"),
        ]
        for arguments in cases:
            with self.subTest(arguments=arguments[1:]):
                done = subprocess.run(self.command(*arguments), env=self.env(), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                self.assertEqual((done.returncode, done.stdout), (2, b""))
                self.assertTrue(done.stderr)
        self.assertFalse(self.inst.exists())


class InstallStageTests(RunCase):
    def test_install_failure_is_reported_at_once(self) -> None:
        started = time.monotonic()
        env = self.env(mode="install_fail", VITA3K_VPK_INSTALL_TIMEOUT="30")
        code, result = self.run_vpk(env, "--timeout", "1", "--expect-file", OUT)
        self.assertLess(time.monotonic() - started, 10)  # well below the install timeout
        self.assertEqual((code, result["verdict"], result["reason"]), (3, "environment_error", "install_failed"))
        self.assertEqual(result["stages"]["install_exit_code"], 1)
        self.assertEqual(result["stages"]["installed"], False)
        self.assertEqual(result["log_summary"]["source"], "install-stdout.log")
        self.assertTrue(any("stub install failed" in line for line in result["log_summary"]["tail"]))
        self.assertEqual(self.launches(), ["version", "install"])
        self.assertEqual(result["expectations"][0]["detail"], "not_evaluated")
        self.assertEqual(result["paths"]["boot_stdout"], None)
        self.assertTrue((Path(result["paths"]["run_dir"]) / "result.json").is_file())

    def test_stale_install_cannot_fake_the_install_stage(self) -> None:
        env = self.env(mode="install_silent")
        stale = self.ux0 / "app" / TITLE / "eboot.bin"
        stale.parent.mkdir(parents=True)
        stale.write_bytes(b"stub eboot")
        code, result = self.run_vpk(env, "--timeout", "1")
        self.assertEqual((code, result["reason"]), (3, "install_failed"))
        self.assertEqual((result["stages"]["eboot_matches"], result["stages"]["install_logged"]), (False, True))
        self.assertFalse(stale.exists())
        self.assert_no_stub_left()

    def test_wrong_eboot_fails_the_install_stage(self) -> None:
        code, result = self.run_vpk(self.env(mode="install_wrong_eboot"), "--timeout", "1")
        self.assertEqual((code, result["reason"]), (3, "install_failed"))
        self.assertEqual((result["stages"]["eboot_matches"], result["stages"]["install_logged"]), (False, True))

    def test_hanging_install_launch_is_killed(self) -> None:
        code, result = self.quick(self.env(mode="install_hang"), "--expect-file", OUT)
        self.assertEqual((code, result["verdict"]), (0, "pass"))
        self.assertEqual(result["stages"]["install_exit_code"], -signal.SIGKILL)
        self.assertEqual(self.launches(), ["version", "install", "boot"])
        self.assert_no_stub_left()

    def test_emulator_that_cannot_load_is_an_install_failure(self) -> None:
        code, result = self.run_vpk(self.env(mode="install_noload"), "--timeout", "1")
        self.assertEqual((code, result["reason"]), (3, "install_failed"))
        self.assertEqual(result["stages"]["install_exit_code"], 127)

    def test_unusable_binary_is_a_start_failure(self) -> None:
        broken = self.tmp / "broken-emulator"
        broken.write_bytes(b"\x00\x01\x02 not a program")
        broken.chmod(0o755)
        code, result = self.run_vpk(self.env(VITA3K_BIN=str(broken)), "--timeout", "1")
        self.assertEqual((code, result["reason"]), (3, "emulator_start_failed"))
        self.assertIsNone(result["emulator"]["version"])
        self.assertTrue((Path(result["paths"]["run_dir"]) / "result.json").is_file())

    def test_seed_and_clean_are_applied_before_the_launches(self) -> None:
        seed = self.tmp / "server=local.txt"
        seed.write_text("127.0.0.1:3000\n")
        env = self.env(mode="install_fail")
        code, result = self.run_vpk(env, "--timeout", "1", "--seed", "%s=ux0:data/stub/server.txt" % seed)
        self.assertEqual(result["reason"], "install_failed")
        # The install launch failed, so the seeded file was placed before it.
        self.assertEqual((self.ux0 / "data" / "stub" / "server.txt").read_text(), "127.0.0.1:3000\n")

        # --clean runs before --seed: a directory is emptied, then seeded.
        (self.ux0 / "data" / "stub" / "old.txt").write_text("old")
        seed.write_text("10.0.0.1:3000\n")
        code, result = self.quick(
            self.env(), "--clean", "ux0:data/stub", "--seed", "%s=ux0:data/stub/server.txt" % seed, "--expect-file", OUT,
        )
        self.assertEqual((code, result["verdict"]), (0, "pass"))
        self.assertFalse((self.ux0 / "data" / "stub" / "old.txt").exists())
        self.assertEqual((self.ux0 / "data" / "stub" / "server.txt").read_text(), "10.0.0.1:3000\n")
        self.assertEqual(self.created(result), ["ux0/data/stub/out.txt", "ux0/temp/stub.tmp"])
        self.assertEqual(result["fs_diff"]["deleted"], [])
        self.assertNotIn("10.0.0.1", json.dumps(result))

    def test_boot_launch_that_cannot_start(self) -> None:
        # The emulator installs and then cannot be started again, as when its file is replaced.
        real_start = v.Session.start

        def start(session, role, *arguments, **options):
            if role == "boot":
                raise OSError(8, "Exec format error")
            return real_start(session, role, *arguments, **options)

        handlers = [(signum, signal.getsignal(signum)) for signum in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP)]
        self.addCleanup(lambda: [signal.signal(signum, handler) for signum, handler in handlers])
        stdout = io.StringIO()
        with mock.patch.dict(os.environ, self.env(), clear=True), mock.patch.object(v.Session, "start", start), \
                contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(io.StringIO()):
            code = v.main(["run", str(self.vpk), "--display", "host", "--timeout", "1", "--expect-file", OUT])
        result = json.loads(stdout.getvalue())
        self.assertEqual((code, result["verdict"], result["reason"]), (3, "environment_error", "emulator_start_failed"))
        self.assertEqual(result["expectations"][0]["detail"], "not_evaluated")
        self.assertEqual(result["fs_diff"], {"created": [], "modified": [], "deleted": [], "emulator_owned": []})
        self.assertEqual(result["log_summary"]["source"], "install-stdout.log")
        self.assertIsNone(result["paths"]["boot_stdout"])
        self.assertTrue(result["stages"]["installed"])
        self.assert_no_stub_left()

    def test_any_file_name_is_launched_as_a_title_named_copy(self) -> None:
        odd = self.tmp / "build output.bin"
        shutil.copy(self.vpk, odd)
        code, result = self.quick(self.env(), "--expect-file", OUT, vpk=odd)
        self.assertEqual((code, result["verdict"]), (0, "pass"))
        _version, install, boot = self.records()
        copy = os.path.join(result["paths"]["run_dir"], TITLE + ".vpk")
        self.assertEqual(install["argv"], ["--", copy])
        self.assertEqual(boot["argv"], ["-r", TITLE])
        self.assertEqual(result["vpk"]["path"], str(odd))
        self.assertEqual(v.sha256_file(copy), result["vpk"]["sha256"])
        # Both launches run inside the instance (Linux layout).
        xdg = self.paths.xdg_env()
        for entry in (install, boot):
            self.assertEqual({name: entry["env"][name] for name in xdg}, xdg)


class EmulatorEndTests(RunCase):
    def test_early_exit_with_status_zero_is_a_warning(self) -> None:
        code, result = self.run_vpk(self.env(mode="exit_early"), "--timeout", "10", "--expect-file", OUT)
        self.assertEqual((code, result["verdict"]), (0, "pass"))
        self.assertIn("emulator_exited_early", result["warnings"])
        self.assertEqual((result["stages"]["emulator_exit_code"], result["stages"]["emulator_signal"]), (0, None))
        self.assertLess(result["stages"]["seconds_running"], 5)

    def test_crash_overrides_expectations(self) -> None:
        # The Linux AppImage runs Vita3K under a shell, so a crash arrives as 128 + signal.
        wrapper = self.tmp / "wrapper.sh"
        wrapper.write_text('#!/bin/sh\n"%s" "%s" "$@"\ncode=$?\nexit $code\n' % (sys.executable, STUB))
        wrapper.chmod(0o755)
        env = self.env(mode="crash", VITA3K_BIN=str(wrapper))
        code, result = self.run_vpk(env, "--timeout", "10", "--expect-file", OUT)
        self.assertEqual((code, result["verdict"], result["reason"]), (1, "fail", "emulator_crashed"))
        self.assertEqual((result["stages"]["emulator_exit_code"], result["stages"]["emulator_signal"]), (139, 11))
        self.assertTrue(result["expectations"][0]["satisfied"])
        code, result = self.run_vpk(env, "--timeout", "10")
        self.assertEqual((code, result["verdict"], result["reason"]), (1, "fail", "emulator_crashed"))

    def test_running_app_is_killed_after_the_grace_period(self) -> None:
        started_wall = time.time()
        started = time.monotonic()
        code, result = self.run_vpk(self.env(), "--timeout", "1", "--expect-file", OUT)
        elapsed = time.monotonic() - started
        self.assertEqual((code, result["verdict"], result["reason"]), (0, "pass", None))
        # Install, one second of boot, SIGTERM, the 2-second grace period, then SIGKILL.
        self.assertGreaterEqual(elapsed, 1 + v.KILL_GRACE)
        self.assertLess(elapsed, 1 + v.KILL_GRACE + 6)
        self.assertEqual((result["stages"]["emulator_exit_code"], result["stages"]["emulator_signal"]), (-9, 9))
        self.assertGreaterEqual(result["stages"]["seconds_running"], 1.0)
        boot = self.records()[-1]
        signals = [json.loads(line) for line in (self.tmp / "signals.jsonl").read_text().splitlines()]
        self.assertEqual([(entry["launch"], entry["pid"]) for entry in signals], [("sigterm", boot["pid"])])
        # The app got SIGTERM after the timeout, and the result came at least the grace period later.
        self.assertGreaterEqual(signals[0]["time"] - boot["time"], 0.7)  # the stub records itself after its start-up
        self.assertGreaterEqual(started_wall + elapsed - signals[0]["time"], v.KILL_GRACE - 0.2)
        self.assert_no_stub_left()

    def test_version_probe_failure_does_not_stop_a_run(self) -> None:
        code, result = self.quick(self.env(mode="version_fail"), "--expect-file", OUT)
        self.assertEqual((code, result["verdict"]), (0, "pass"))
        self.assertIsNone(result["emulator"]["version"])
        self.assertFalse(os.path.exists(self.paths.version_cache))


class IsolationTests(RunCase):
    def test_log_outside_the_instance_is_unverified_isolation(self) -> None:
        code, result = self.quick(self.env(mode="wrong_paths"), "--expect-file", OUT)
        self.assertEqual((code, result["verdict"], result["reason"]), (3, "environment_error", "isolation_unverified"))
        self.assertTrue(result["stages"]["installed"])

    def test_touched_personal_path_is_violated_isolation(self) -> None:
        for layout in ("linux", "darwin"):
            with self.subTest(layout=layout):
                code, result = self.quick(self.env(layout, mode="touch_personal"), "--expect-file", OUT)
                self.assertEqual((code, result["verdict"], result["reason"]), (3, "environment_error", "isolation_violated"))
                self.assertTrue(result["expectations"][0]["satisfied"])

    def test_missing_emulator(self) -> None:
        env = self.env(VITA3K_BIN=str(self.tmp / "absent"))
        code, result = self.run_vpk(env, "--timeout", "1", "--expect-file", OUT)
        self.assertEqual((code, result["verdict"], result["reason"]), (3, "environment_error", "emulator_missing"))
        self.assertEqual(result["paths"], dict.fromkeys(result["paths"]))
        self.assertEqual(result["stages"], dict.fromkeys(result["stages"]))
        self.assertIsNone(result["log_summary"])
        self.assertFalse(self.inst.exists())
        code, doctor, _stderr = self.script(env, "doctor", "--display", "host")
        self.assertEqual((code, doctor["ready"], doctor["emulator"]), (3, False, None))
        self.assertEqual([item["code"] for item in doctor["problems"]][:1], ["emulator_missing"])
        self.assertIn("references/install.md", doctor["problems"][0]["fix"])

    def test_macos_layout_without_portable_directory(self) -> None:
        env = self.env("darwin")
        (self.inst / "emulator" / "portable").rmdir()
        code, result = self.run_vpk(env, "--timeout", "1")
        self.assertEqual((code, result["reason"]), (3, "isolation_unavailable"))
        self.assertEqual(self.launches(), [])
        code, doctor, _stderr = self.script(env, "doctor")
        self.assertEqual((code, doctor["ready"]), (3, False))
        self.assertEqual(doctor["problems"][0]["code"], "isolation_unavailable")
        self.assertIn("macOS", doctor["problems"][0]["fix"])
        self.assertEqual(self.launches(), [])

    def test_missing_xvfb_is_a_display_failure(self) -> None:
        empty = self.tmp / "empty-bin"
        empty.mkdir()
        env = self.env(PATH=str(empty))
        code, result, stderr = self.script(env, "run", str(self.vpk), "--display", "xvfb", "--timeout", "1")
        self.assertEqual((code, result["verdict"], result["reason"]), (3, "environment_error", "display_failed"))
        self.assertEqual(result["host"]["display_mode"], "xvfb")
        self.assertIsNotNone(result["paths"]["run_dir"])
        self.assertIn("backend-renderer: OpenGL", Path(self.paths.config_file).read_text())
        self.assertEqual(self.launches(), [])
        code, doctor, _stderr = self.script(env, "doctor", "--display", "xvfb")
        self.assertEqual((code, doctor["ready"], doctor["headless"]), (3, False, {"needed": True, "xvfb": False, "xwd": False}))
        self.assertEqual([item["code"] for item in doctor["problems"]][:2], ["xvfb_missing", "xwd_missing"])


class ConcurrencyTests(RunCase):
    def state(self) -> list:
        return v.read_state(self.paths.state_file)

    def entry(self, role: str) -> dict:
        return wait_for(lambda: next((item for item in self.state() if item.get("role") == role and item.get("lstart")), None))

    def test_second_run_is_refused_while_the_first_holds_the_lock(self) -> None:
        env = self.env()
        first = self.start(env, "--timeout", "4", "--expect-file", OUT)
        self.wait_for_launch("boot")
        code, result = self.run_vpk(env, "--timeout", "1", "--expect-file", OUT)
        self.assertEqual((code, result["verdict"], result["reason"]), (3, "environment_error", "instance_busy"))
        # The run stopped before a run directory existed.
        self.assertEqual(result["paths"], dict.fromkeys(result["paths"]))
        self.assertEqual(result["expectations"][0]["detail"], "not_evaluated")
        self.assertEqual(result["fs_diff"], {"created": [], "modified": [], "deleted": [], "emulator_owned": []})
        self.assertEqual(len(os.listdir(self.paths.runs_dir)), 1)
        stdout, _stderr = first.communicate(timeout=30)
        self.assertEqual((first.returncode, json.loads(stdout)["verdict"]), (0, "pass"))
        self.assert_no_stub_left()

    def orphan_scenario(self, mode: str, role: str) -> None:
        first = self.start(self.env(mode=mode), "--timeout", "30")
        orphan = self.entry(role)
        first.kill()
        first.wait()
        time.sleep(0.2)
        self.assertTrue(alive(orphan["pid"]), "the stub must survive its script")
        code, result = self.quick(self.env(), "--expect-file", OUT)
        self.assertEqual((code, result["verdict"]), (0, "pass"))
        self.assertIn("orphan_cleaned", result["warnings"])
        self.assertFalse(alive(orphan["pid"]))
        self.assert_no_stub_left()

    def test_orphaned_boot_launch_is_cleaned(self) -> None:
        self.orphan_scenario("ok", "boot")

    def test_orphaned_install_launch_is_cleaned(self) -> None:
        self.orphan_scenario("install_hang", "install")

    def test_unrelated_processes_are_never_signalled(self) -> None:
        env = self.env()
        os.makedirs(self.inst)
        # A live process whose start time does not match the record: the ID was reused.
        reused = self.spawn(["sleep", "60"], start_new_session=True)
        # A process in the script's own group. The script inherits this test's group.
        own_group = self.spawn(["sleep", "60"])
        v.write_state(self.paths.state_file, [
            {"role": "boot", "pid": reused.pid, "pgid": reused.pid, "lstart": "Thu Jan  1 00:00:00 1970"},
            {"role": "boot", "pid": own_group.pid, "pgid": os.getpgrp(), "lstart": v.ps_lstart(own_group.pid)},
            {"role": "xvfb", "pid": "not a pid", "pgid": 1, "lstart": None},
        ])
        self.assertEqual(os.getpgid(own_group.pid), os.getpgrp())
        code, result = self.quick(env, "--expect-file", OUT)
        self.assertEqual((code, result["verdict"]), (0, "pass"))
        self.assertNotIn("orphan_cleaned", result["warnings"])
        self.assertIsNone(reused.poll())
        self.assertIsNone(own_group.poll())

    def test_group_of_zombies_counts_as_ended(self) -> None:
        child = self.spawn(["true"], start_new_session=True)
        wait_for(lambda: not alive(child.pid))  # exited and not yet reaped
        self.assertTrue(v.group_alive(child.pid))
        self.assertTrue(v.group_is_defunct(child.pid))
        child.wait()
        self.assertFalse(v.group_is_defunct(child.pid))
        self.assertFalse(v.group_is_defunct(os.getpgrp()))

    def test_interrupt_tears_down_and_reports(self) -> None:
        for signum in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
            with self.subTest(signal=signum):
                self.reset()
                running = self.start(self.env(), "--timeout", "30", "--expect-file", OUT)
                self.wait_for_launch("boot")
                time.sleep(0.3)
                running.send_signal(signum)
                stdout, _stderr = running.communicate(timeout=30)
                result = json.loads(stdout)
                self.assertEqual((running.returncode, result["verdict"], result["reason"]), (3, "environment_error", "interrupted"))
                self.assertIsNotNone(result["paths"]["run_dir"])
                self.assert_no_stub_left()

    def test_old_run_directories_are_pruned(self) -> None:
        env = self.env()
        runs = Path(self.paths.runs_dir)
        runs.mkdir(parents=True)
        old = ["202001%02dT000000Z-%s" % (day, TITLE) for day in range(1, 21)]
        for name in old:
            (runs / name).mkdir()
        (runs / "keep-me").mkdir()
        target = self.tmp / "link-target"
        target.mkdir()
        os.symlink(target, runs / ("20190101T000000Z-" + TITLE))
        code, result = self.run_vpk(env, "--timeout", "1")
        names = set(os.listdir(runs))
        current = os.path.basename(result["paths"]["run_dir"])
        self.assertEqual(names, set(old[1:]) | {current, "keep-me", "20190101T000000Z-" + TITLE})
        self.assertTrue(target.is_dir())


class DoctorTests(RunCase):
    def test_ready_with_cached_version(self) -> None:
        for layout in ("linux", "darwin"):
            with self.subTest(layout=layout):
                self.reset()
                env = self.env(layout)
                code, doctor, stderr = self.script(env, "doctor", "--display", "host")
                self.assertEqual((code, doctor["ready"]), (0, True), stderr)
                self.assertEqual(doctor["headless"]["needed"], False)
                self.assertEqual(doctor["paths"], self.paths.as_dict())
                self.assertEqual(doctor["instance_root"], str(self.inst))
                self.assertEqual(doctor["emulator"]["version"], "Vita3K v0.0.0 stub")
                self.assertEqual(doctor["emulator"]["sha256"], v.sha256_file(doctor["emulator"]["path"]))
                self.assertEqual(doctor["firmware"], {"main": False, "font": False})
                self.assertEqual([item["code"] for item in doctor["problems"]], ["firmware_missing"])
                self.assertEqual(doctor["host"]["os"], layout)
                code, again, _stderr = self.script(env, "doctor", "--display", "host")
                self.assertEqual(again, doctor)
                self.assertEqual(self.launches(), ["version"])
                self.assertFalse(os.path.exists(self.paths.state_file))

    def test_changed_binary_is_probed_again(self) -> None:
        binary = self.tmp / "emulator-copy"
        shutil.copy(STUB, binary)
        binary.chmod(0o755)
        env = self.env(VITA3K_BIN=str(binary))
        for _ in range(2):
            code, doctor, _stderr = self.script(env, "doctor", "--display", "host")
            self.assertEqual((code, doctor["emulator"]["version"]), (0, "Vita3K v0.0.0 stub"))
        self.assertEqual(self.launches(), ["version"])
        info = os.stat(binary)
        os.utime(binary, ns=(info.st_atime_ns, info.st_mtime_ns + 1_000_000_000))
        code, doctor, _stderr = self.script(env, "doctor", "--display", "host")
        self.assertEqual(self.launches(), ["version", "version"])

    def test_firmware_state(self) -> None:
        env = self.env()
        for name in ("vs0", "sa0"):
            (Path(self.paths.vita_fs) / name / "data").mkdir(parents=True)
        code, doctor, _stderr = self.script(env, "doctor", "--display", "host")
        self.assertEqual((code, doctor["firmware"], doctor["problems"]), (0, {"main": True, "font": True}, []))

    def test_failed_version_probe_clears_ready(self) -> None:
        code, doctor, _stderr = self.script(self.env(mode="version_fail"), "doctor", "--display", "host")
        self.assertEqual((code, doctor["ready"], doctor["emulator"]["version"]), (3, False, None))
        problem = doctor["problems"][0]
        self.assertEqual(problem["code"], "version_probe_failed")
        self.assertIn("libstub.so.1", problem["detail"])

    def test_busy_instance_skips_the_probe(self) -> None:
        env = self.env()
        os.makedirs(self.inst)
        holder = v.Session(self.paths, env)
        self.assertTrue(holder.acquire_lock())
        self.addCleanup(holder.release_lock)
        code, doctor, _stderr = self.script(env, "doctor", "--display", "host")
        self.assertEqual((code, doctor["ready"], doctor["emulator"]["version"]), (0, True, None))
        self.assertIn("instance_busy", [item["code"] for item in doctor["problems"]])
        self.assertEqual(self.launches(), [])


class SampleLogTests(unittest.TestCase):
    def test_gate_constants(self) -> None:
        # Measured against the real emulator. A change here needs a new measurement.
        self.assertEqual((v.KILL_GRACE, v.INSTALL_TIMEOUT, v.DEFAULT_TIMEOUT, v.DEFAULT_SETTLE), (2.0, 30.0, 60.0, 5.0))
        self.assertEqual(v.INSTALL_MARKER, "installed successfully!")
        self.assertEqual(v.HEADLESS_RENDERER, "OpenGL")
        self.assertEqual(v.HEADLESS_ENV, {"LIBGL_ALWAYS_SOFTWARE": "1", "__GLX_VENDOR_LIBRARY_NAME": "mesa"})
        self.assertEqual(v.XVFB_SCREEN, "1280x800x24")

    def test_real_boot_log_is_parsed(self) -> None:
        lines = v.read_log_lines(str(FIXTURES / "vita3k-sample.log"))
        summary = v.summarize_log(lines, "emulator-stdout.log")
        self.assertEqual(summary["line_count"], 133)
        self.assertEqual(summary["levels"], {"T": 43, "D": 11, "I": 49, "W": 4, "E": 6, "C": 0, "?": 20})
        self.assertEqual(len(summary["tty"]), 36)
        self.assertEqual(summary["tty"][1], "[19:29:08.946] |T| [write_file]: *** TTY: 81930e738b4b0973db47275d0a1a0e2e27df42a3")
        self.assertIn("[19:29:08.822] |I| [boot_game_once]: Game started: Bevy DB Value (BEVYPOC01)", lines)
        self.assertEqual(len(summary["errors"]), 6)
        self.assertTrue(all("skprx" in line or "Missing file at" in line for line in summary["errors"]))
        self.assertFalse(any(v.INSTALL_MARKER in line for line in lines))
        # One eprintln! arrives as several TTY lines, so a pattern must match one fragment.
        sha = v.Expectation("expect-log", "sha", regex=v.re.compile(r"\*\*\* TTY: 81930e738b4b0973db47275d0a1a0e2e27df42a3"))
        self.assertTrue(v.evaluate_expectation(sha, {}, {}, lines)["satisfied"])
        whole = v.Expectation("expect-log", "whole", regex=v.re.compile("bevypoc source commit: 81930e73"))
        self.assertFalse(v.evaluate_expectation(whole, {}, {}, lines)["satisfied"])


@unittest.skipUnless(HAS_XVFB, "Xvfb and xwd are needed for the headless display tests")
class XvfbTests(RunCase):
    def xvfb_pids(self) -> set:
        listing = subprocess.run(["pgrep", "-x", "Xvfb"], stdout=subprocess.PIPE).stdout.decode().split()
        return {int(pid) for pid in listing if alive(int(pid))}  # a zombie is not a running server

    def setUp(self) -> None:
        super().setUp()
        before = self.xvfb_pids()

        def kill_new_servers() -> None:
            # Left behind by a failed test. Only servers with the script's own arguments are killed.
            for pid in self.xvfb_pids() - before:
                command = subprocess.run(["ps", "-o", "command=", "-p", str(pid)], stdout=subprocess.PIPE).stdout.decode()
                if "-displayfd" in command and v.XVFB_SCREEN in command:
                    os.kill(pid, signal.SIGKILL)

        self.addCleanup(kill_new_servers)

    def test_screenshot_of_the_owned_display(self) -> None:
        before = self.xvfb_pids()
        code, result, stderr = self.script(
            self.env(), "run", str(self.vpk), "--display", "xvfb", "--timeout", "10",
            "--stop-when-satisfied", "--settle", "0", "--expect-file", OUT,
        )
        self.assertEqual((code, result["verdict"]), (0, "pass"), stderr)
        self.assertEqual(result["host"]["display_mode"], "xvfb")
        self.assertNotIn("screenshot_failed", result["warnings"])
        png = Path(result["paths"]["screenshot"]).read_bytes()
        self.assertEqual(png[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(struct.unpack(">II", png[16:24]), (1280, 800))
        boot = self.records()[-1]
        self.assertEqual(boot["launch"], "boot")
        self.assertTrue(boot["env"]["DISPLAY"].startswith(":"))
        self.assertEqual(boot["env"]["LIBGL_ALWAYS_SOFTWARE"], "1")
        self.assertEqual(boot["env"]["__GLX_VENDOR_LIBRARY_NAME"], "mesa")
        self.assertIn("backend-renderer: OpenGL", Path(self.paths.config_file).read_text())
        self.assert_no_stub_left()
        self.assertEqual(self.xvfb_pids(), before)

    def test_orphaned_xvfb_is_cleaned(self) -> None:
        before = self.xvfb_pids()
        first = self.start(self.env(), "--timeout", "30", display="xvfb")
        boot = self.wait_for_launch("boot")
        orphan_xvfb = wait_for(lambda: self.xvfb_pids() - before)
        first.kill()
        first.wait()
        time.sleep(0.2)
        self.assertTrue(alive(boot["pid"]))
        code, result, stderr = self.script(
            self.env(), "run", str(self.vpk), "--display", "xvfb", "--timeout", "10",
            "--stop-when-satisfied", "--settle", "0", "--expect-file", OUT,
        )
        self.assertEqual((code, result["verdict"]), (0, "pass"), stderr)
        self.assertIn("orphan_cleaned", result["warnings"])
        self.assertFalse(alive(boot["pid"]))
        for pid in orphan_xvfb:
            self.assertFalse(alive(pid))
        self.assertEqual(self.xvfb_pids(), before)

    def test_doctor_probes_under_its_own_display(self) -> None:
        before = self.xvfb_pids()
        code, doctor, stderr = self.script(self.env(), "doctor", "--display", "xvfb")
        self.assertEqual((code, doctor["ready"]), (0, True), stderr)
        self.assertEqual(doctor["headless"], {"needed": True, "xvfb": True, "xwd": True})
        version = self.records()[0]
        self.assertEqual(version["launch"], "version")
        self.assertTrue(version["env"]["DISPLAY"].startswith(":"))
        self.assertEqual(self.xvfb_pids(), before)


if __name__ == "__main__":
    unittest.main()
