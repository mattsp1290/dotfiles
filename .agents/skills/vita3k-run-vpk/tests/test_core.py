from __future__ import annotations

import ast
import os
from pathlib import Path
import re
import struct
import sys
import tempfile
import unittest
import zipfile
import zlib

SKILL_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = SKILL_ROOT / "scripts"
FIXTURES = Path(__file__).resolve().parent / "fixtures"
sys.path.insert(0, str(SCRIPTS))

import vita3k_vpk as v  # noqa: E402


def make_sfo(entries: list[tuple[str, bytes, int]]) -> bytes:
    """Build a param.sfo image from (key, data, format) entries."""
    keys = b""
    data = b""
    index = b""
    for key, value, fmt in entries:
        index += struct.pack("<HHIII", len(keys), fmt, len(value), len(value), len(data))
        keys += key.encode("ascii") + b"\x00"
        data += value
    key_table = 20 + len(index)
    data_table = key_table + len(keys)
    return b"\x00PSF" + struct.pack("<4I", 0x101, key_table, data_table, len(entries)) + index + keys + data


def title_sfo(title_id: str) -> bytes:
    return make_sfo(
        [
            ("APP_VER", b"01.00\x00", 0x0204),
            ("TITLE_ID", title_id.encode("ascii") + b"\x00", 0x0204),
            ("ATTRIBUTE", struct.pack("<I", 0), 0x0404),
        ]
    )


def make_vpk(path: Path, title_id: str = "STUB00001", eboot: bytes = b"eboot-bytes", members: tuple = ()) -> Path:
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr("eboot.bin", eboot)
        archive.writestr("sce_sys/param.sfo", title_sfo(title_id))
        for name, body in members:
            archive.writestr(name, body)
    return path


def decode_png(png: bytes) -> tuple[int, int, list[list[tuple[int, int, int]]]]:
    assert png[:8] == b"\x89PNG\r\n\x1a\n"
    position = 8
    idat = b""
    width = height = 0
    while position < len(png):
        (length,) = struct.unpack(">I", png[position:position + 4])
        kind = png[position + 4:position + 8]
        body = png[position + 8:position + 8 + length]
        position += 12 + length
        if kind == b"IHDR":
            width, height, depth, colour_type = struct.unpack(">IIBB", body[:10])
            assert (depth, colour_type) == (8, 2)
        elif kind == b"IDAT":
            idat += body
    raw = zlib.decompress(idat)
    stride = 1 + width * 3
    rows = []
    for y in range(height):
        line = raw[y * stride:(y + 1) * stride]
        assert line[0] == 0
        rows.append([tuple(line[1 + x * 3:4 + x * 3]) for x in range(width)])
    return width, height, rows


def make_xwd(
    width: int, height: int, pixels: bytes, bits_per_pixel: int, bytes_per_line: int, byte_order: int,
    masks: tuple = (0xFF0000, 0x00FF00, 0x0000FF),
) -> bytes:
    name = b"xwdump\x00"
    header = struct.pack(
        ">25I",
        100 + len(name), 7, 2, 24, width, height, 0, byte_order, 32, byte_order, 32, bits_per_pixel,
        bytes_per_line, 4, masks[0], masks[1], masks[2], 8, 256, 0, width, height, 0, 0, 0,
    )
    return header + name + pixels


class TempDirCase(unittest.TestCase):
    def setUp(self) -> None:
        self._temp = tempfile.TemporaryDirectory()
        self.addCleanup(self._temp.cleanup)
        self.tmp = Path(self._temp.name).resolve()


class SfoAndVpkTests(TempDirCase):
    def test_title_id_from_mixed_entries(self) -> None:
        self.assertEqual(v.parse_sfo_title_id(title_sfo("ABCD12345")), "ABCD12345")

    def test_sfo_rejects_wrong_magic(self) -> None:
        with self.assertRaises(v.UsageError):
            v.parse_sfo_title_id(b"\x01PSF" + title_sfo("ABCD12345")[4:])

    def test_sfo_rejects_truncated_index(self) -> None:
        with self.assertRaises(v.UsageError):
            v.parse_sfo_title_id(title_sfo("ABCD12345")[:40])

    def test_sfo_rejects_offset_beyond_file(self) -> None:
        sfo = bytearray(title_sfo("ABCD12345"))
        # Second index entry is TITLE_ID. Its data offset is the last field.
        struct.pack_into("<I", sfo, 20 + 16 + 12, 0xFFFF)
        with self.assertRaises(v.UsageError):
            v.parse_sfo_title_id(bytes(sfo))
        sfo = bytearray(title_sfo("ABCD12345"))
        struct.pack_into("<H", sfo, 20, 0xFFFF)
        with self.assertRaises(v.UsageError):
            v.parse_sfo_title_id(bytes(sfo))

    def test_inspect_reads_identity(self) -> None:
        vpk = make_vpk(self.tmp / "build output.bin", "ABCD12345", b"payload")
        info = v.inspect_vpk(str(vpk))
        self.assertEqual(info.title_id, "ABCD12345")
        self.assertEqual(info.eboot_sha256, v.hashlib.sha256(b"payload").hexdigest())
        self.assertEqual(info.sha256, v.sha256_file(str(vpk)))

    def test_inspect_rejects_missing_members_and_bad_title(self) -> None:
        no_eboot = self.tmp / "a.vpk"
        with zipfile.ZipFile(no_eboot, "w") as archive:
            archive.writestr("sce_sys/param.sfo", title_sfo("ABCD12345"))
        no_sfo = self.tmp / "b.vpk"
        with zipfile.ZipFile(no_sfo, "w") as archive:
            archive.writestr("eboot.bin", b"x")
        bad_title = self.tmp / "c.vpk"
        with zipfile.ZipFile(bad_title, "w") as archive:
            archive.writestr("eboot.bin", b"x")
            archive.writestr("sce_sys/param.sfo", make_sfo([("TITLE_ID", b"../../x\x00", 0x0204)]))
        not_zip = self.tmp / "d.vpk"
        not_zip.write_bytes(b"not a zip")
        for path in (no_eboot, no_sfo, bad_title, not_zip, self.tmp / "absent.vpk"):
            with self.subTest(path=path.name), self.assertRaises(v.UsageError):
                v.inspect_vpk(str(path))


class PathTests(TempDirCase):
    def setUp(self) -> None:
        super().setUp()
        self.vita_fs = self.tmp / "fs"
        (self.vita_fs / "ux0" / "data").mkdir(parents=True)

    def test_mapping_accepts_plain_path(self) -> None:
        host_path, rel = v.map_vita_path(str(self.vita_fs), "ux0:data/app/file.txt")
        self.assertEqual(host_path, str(self.vita_fs / "ux0" / "data" / "app" / "file.txt"))
        self.assertEqual(rel, "ux0/data/app/file.txt")

    def test_mapping_rejects_bad_paths(self) -> None:
        outside = self.tmp / "outside"
        outside.mkdir()
        os.symlink(outside, self.vita_fs / "ux0" / "data" / "link")
        for spec in ("app0:x", "ux0:../x", "ux0:data/../../x", "ux0:/abs", "ux0:", "ux0:data/link/file.txt", "data/x"):
            with self.subTest(spec=spec), self.assertRaises(v.UsageError):
                v.map_vita_path(str(self.vita_fs), spec)

    def test_clean_validation(self) -> None:
        for spec in ("ux0:data/bevypoc", "ux0:data/bevypoc/sub/file", "ux0:user/00/savedata/OWNTITLE1"):
            with self.subTest(spec=spec):
                v.validate_clean_path(spec, "OWNTITLE1")
        rejected = (
            "ux0:data", "ux0:app", "ux0:app/OTHERID01", "ux0:user", "ux0:user/00",
            "ux0:user/00/savedata", "ux0:user/00/savedata/OTHERID01",
        )
        for spec in rejected:
            with self.subTest(spec=spec), self.assertRaises(v.UsageError):
                v.validate_clean_path(spec, "OWNTITLE1")

    def test_clean_rejects_a_path_through_a_symlink(self) -> None:
        other = self.vita_fs / "ux0" / "app" / "OTHERID01"
        other.mkdir(parents=True)
        (other / "eboot.bin").write_text("other title")
        os.symlink(other, self.vita_fs / "ux0" / "data" / "link")
        with self.assertRaises(v.UsageError):
            v.map_clean_path(str(self.vita_fs), "ux0:data/link/eboot.bin", "OWNTITLE1")
        # The link itself is a valid target: it is unlinked, not followed.
        target = v.map_clean_path(str(self.vita_fs), "ux0:data/link", "OWNTITLE1")
        v.remove_no_follow(target)
        self.assertFalse(os.path.lexists(target))
        self.assertEqual((other / "eboot.bin").read_text(), "other title")
        self.assertEqual(
            v.map_clean_path(str(self.vita_fs), "ux0:data/app/sub", "OWNTITLE1"),
            str(self.vita_fs / "ux0" / "data" / "app" / "sub"),
        )
        with self.assertRaises(v.UsageError):
            v.map_clean_path(str(self.vita_fs), "ux0:app/OTHERID01", "OWNTITLE1")

    def test_clean_deletion_does_not_follow_symlinks(self) -> None:
        outside = self.tmp / "outside"
        outside.mkdir()
        (outside / "keep.txt").write_text("keep")
        target = self.vita_fs / "ux0" / "data" / "app"
        (target / "sub").mkdir(parents=True)
        (target / "sub" / "old.txt").write_text("old")
        os.symlink(outside, target / "dir-link")
        os.symlink(outside / "keep.txt", target / "file-link")
        v.remove_no_follow(str(target))
        self.assertFalse(target.exists())
        self.assertEqual((outside / "keep.txt").read_text(), "keep")
        v.remove_no_follow(str(target))  # an absent path is not an error

    def test_argument_splitting(self) -> None:
        self.assertEqual(v.split_contains_arg("ux0:data/a.txt=k=v"), ("ux0:data/a.txt", "k=v"))
        self.assertEqual(v.split_seed_arg("/tmp/a=b.txt=ux0:data/x.txt"), ("/tmp/a=b.txt", "ux0:data/x.txt"))
        for bad in ("ux0:data/a.txt", "ux0:data/a.txt="):
            with self.subTest(arg=bad), self.assertRaises(v.UsageError):
                v.split_contains_arg(bad)
        for bad in ("/tmp/a", "=ux0:data/x.txt", "/tmp/a=app0:x"):
            with self.subTest(arg=bad), self.assertRaises(v.UsageError):
                v.split_seed_arg(bad)


class ConfigTests(TempDirCase):
    def test_upsert_creates_replaces_appends_and_preserves(self) -> None:
        config = self.tmp / "portable" / "config.yml"
        v.seed_config(str(config), "host")
        created = config.read_text()
        self.assertIn("show-welcome: false\n", created)
        self.assertIn("log-level: 0\n", created)
        self.assertNotIn("backend-renderer", created)

        config.write_text("# comment\nshow-welcome: true\nlle-modules:\n  - show-welcome: nested\ncpu-backend: Dynarmic\n")
        v.seed_config(str(config), "xvfb")
        lines = config.read_text().splitlines()
        self.assertEqual(
            lines[:5],
            ["# comment", "show-welcome: false", "lle-modules:", "  - show-welcome: nested", "cpu-backend: Dynarmic"],
        )
        self.assertEqual(
            lines[5:],
            ["warn-missing-firmware: false", "check-for-updates: false", "check-for-updates-mode: 0",
             "log-level: 0", "backend-renderer: OpenGL"],
        )
        v.seed_config(str(config), "xvfb")
        self.assertEqual(config.read_text().splitlines(), lines)

    def test_upsert_adds_keys_inside_the_yaml_document(self) -> None:
        # Vita3K writes `---` first and the document-end line `...` last.
        text = v.upsert_config_text("---\nshow-welcome: true\npref-path: \"\"\n...\n\n", [("show-welcome", "false"), ("new-key", "1")])
        self.assertEqual(text, "---\nshow-welcome: false\npref-path: \"\"\nnew-key: 1\n...\n\n")
        self.assertEqual(v.upsert_config_text("...\n", [("a", "1")]), "a: 1\n...\n")
        self.assertEqual(v.upsert_config_text("b: 2\n...  \n", [("a", "1")]), "b: 2\na: 1\n...  \n")
        self.assertEqual(v.upsert_config_text("", [("a", "1")]), "a: 1\n")
        # Without a document-end line, and with one that is not last, keys go to the end.
        self.assertEqual(v.upsert_config_text("b: 2\n", [("a", "1")]), "b: 2\na: 1\n")
        self.assertEqual(v.upsert_config_text("b: 2\n...\nc: 3\n", [("a", "1")]), "b: 2\n...\nc: 3\na: 1\n")

    def test_upsert_keeps_odd_bytes_and_separators(self) -> None:
        config = self.tmp / "config.yml"
        config.write_bytes(b"name: caf\xe9\x0cpage\r\nshow-welcome: true\r\n")
        v.seed_config(str(config), "host")
        data = config.read_bytes()
        self.assertTrue(data.startswith(b"name: caf\xe9\x0cpage\nshow-welcome: false\n"))
        self.assertFalse((self.tmp / "config.yml.tmp").exists())

    def test_host_mode_keeps_persisted_renderer(self) -> None:
        text = v.upsert_config_text("backend-renderer: Vulkan\n", v.config_seed_pairs("host"))
        self.assertIn("backend-renderer: Vulkan\n", text)


class SnapshotTests(TempDirCase):
    def setUp(self) -> None:
        super().setUp()
        self.vita_fs = self.tmp / "fs"
        self.data = self.vita_fs / "ux0" / "data" / "app"
        self.data.mkdir(parents=True)

    def snap(self, extra: tuple = ()) -> dict:
        return v.take_snapshot(str(self.vita_fs), extra)

    def evaluate(self, kind: str, name: str, before: dict, after: dict, text: str | None = None) -> dict:
        host_path, rel = v.map_vita_path(str(self.vita_fs), "ux0:data/app/" + name)
        expectation = v.Expectation(kind, name, rel=rel, host_path=host_path, text=text)
        return v.evaluate_expectation(expectation, before, after, [])

    def test_diff_reports_each_change_kind(self) -> None:
        for name in ("same.txt", "content.txt", "touched.txt", "gone.txt"):
            (self.data / name).write_text("aaaa")
        (self.vita_fs / "ux0" / "app" / "TITLE0001").mkdir(parents=True)
        (self.vita_fs / "ux0" / "user" / "00").mkdir(parents=True)
        before = self.snap()
        (self.data / "new.txt").write_text("new")
        info = os.stat(self.data / "content.txt")
        (self.data / "content.txt").write_text("bbbb")
        os.utime(self.data / "content.txt", ns=(info.st_atime_ns, info.st_mtime_ns))
        os.utime(self.data / "touched.txt", ns=(info.st_atime_ns, info.st_mtime_ns + 1_000_000_000))
        (self.data / "gone.txt").unlink()
        (self.vita_fs / "ux0" / "app" / "TITLE0001" / "eboot.bin").write_text("installed")
        (self.vita_fs / "ux0" / "user" / "time.xml").write_text("t")
        (self.vita_fs / "ux0" / "user" / "00" / "user.xml").write_text("u")
        after = self.snap()
        diff = v.diff_snapshots(before, after)
        self.assertEqual([item["path"] for item in diff["created"]], ["ux0/data/app/new.txt"])
        self.assertEqual(
            [item["path"] for item in diff["modified"]], ["ux0/data/app/content.txt", "ux0/data/app/touched.txt"]
        )
        self.assertEqual(diff["deleted"], [{"path": "ux0/data/app/gone.txt"}])
        self.assertEqual(
            diff["emulator_owned"],
            [{"path": "ux0/user/00/user.xml", "change": "created"}, {"path": "ux0/user/time.xml", "change": "created"}],
        )
        self.assertNotIn("ux0/app/TITLE0001/eboot.bin", after)
        self.assertFalse(v.has_unhashed_change(before, after))

    def test_expectation_path_under_app_is_snapshotted(self) -> None:
        app = self.vita_fs / "ux0" / "app" / "TITLE0001"
        app.mkdir(parents=True)
        (app / "marker.txt").write_text("m")
        self.assertIn("ux0/app/TITLE0001/marker.txt", self.snap(("ux0/app/TITLE0001/marker.txt",)))
        self.assertEqual(self.snap(("ux0/app/TITLE0001/absent.txt",)), {})

    def test_snapshot_records_symlinks_without_following(self) -> None:
        outside = self.tmp / "outside"
        outside.mkdir()
        (outside / "secret.txt").write_text("secret")
        os.symlink(outside, self.data / "dir-link")
        os.symlink(outside / "secret.txt", self.data / "file-link")
        snapshot = self.snap()
        self.assertEqual(sorted(snapshot), ["ux0/data/app/dir-link", "ux0/data/app/file-link"])

    def test_unchanged_file_is_not_fresh(self) -> None:
        (self.data / "out.txt").write_text("evidence")
        before = self.snap()
        after = self.snap()
        self.assertEqual(v.diff_snapshots(before, after)["modified"], [])
        result = self.evaluate("expect-file", "out.txt", before, after)
        self.assertFalse(result["satisfied"])
        self.assertIn("stale", result["detail"])
        self.assertFalse(self.evaluate("expect-file-contains", "out.txt", before, after, "evidence")["satisfied"])
        self.assertTrue(self.evaluate("reject-file", "out.txt", before, after)["satisfied"])
        missing = self.evaluate("expect-file", "absent.txt", before, after)
        self.assertEqual((missing["satisfied"], missing["detail"]), (False, "missing"))

    def test_appended_file_exposes_only_appended_bytes(self) -> None:
        log = self.data / "startup.log"
        log.write_text("sha-old ready\n")
        before = self.snap()
        with open(log, "a") as handle:
            handle.write("sha-new booted\n")
        after = self.snap()
        stale = self.evaluate("expect-file-contains", "startup.log", before, after, "sha-old ready")
        self.assertFalse(stale["satisfied"])
        self.assertIn("appended bytes", stale["detail"])
        self.assertTrue(self.evaluate("expect-file-contains", "startup.log", before, after, "sha-new booted")["satisfied"])
        # Text that spans the old and the new part is not fresh.
        self.assertFalse(self.evaluate("expect-file-contains", "startup.log", before, after, "ready\nsha-new")["satisfied"])
        self.assertTrue(self.evaluate("expect-file", "startup.log", before, after)["satisfied"])
        self.assertFalse(self.evaluate("reject-file", "startup.log", before, after)["satisfied"])

    def test_rewritten_file_exposes_whole_file(self) -> None:
        build = self.data / "build.txt"
        build.write_text("abc")
        before = self.snap()
        build.write_text("xyz-longer")
        after = self.snap()
        result = self.evaluate("expect-file-contains", "build.txt", before, after, "xyz")
        self.assertTrue(result["satisfied"])
        self.assertIn("whole file", result["detail"])
        self.assertFalse(self.evaluate("expect-file-contains", "build.txt", before, after, "abc")["satisfied"])

    def test_identical_rewrite_with_new_mtime_exposes_whole_file(self) -> None:
        build = self.data / "build.txt"
        build.write_text("same-sha")
        before = self.snap()
        info = os.stat(build)
        build.write_text("same-sha")
        os.utime(build, ns=(info.st_atime_ns, info.st_mtime_ns + 2_000_000_000))
        after = self.snap()
        self.assertEqual([item["path"] for item in v.diff_snapshots(before, after)["modified"]], ["ux0/data/app/build.txt"])
        self.assertTrue(self.evaluate("expect-file-contains", "build.txt", before, after, "same-sha")["satisfied"])

    def test_created_file_exposes_whole_file(self) -> None:
        before = self.snap()
        (self.data / "out.txt").write_text("fresh evidence")
        after = self.snap()
        result = self.evaluate("expect-file-contains", "out.txt", before, after, "evidence")
        self.assertTrue(result["satisfied"])
        self.assertTrue(result["detail"].startswith("created"))

    @unittest.skipIf(os.geteuid() == 0, "root reads every file")
    def test_unreadable_file_stays_in_the_snapshot(self) -> None:
        locked = self.data / "locked.txt"
        locked.write_text("secret")
        locked.chmod(0)
        self.addCleanup(locked.chmod, 0o644)
        entry = self.snap()["ux0/data/app/locked.txt"]
        self.assertEqual((entry["size"], entry["sha256"]), (6, None))

    def test_large_file_is_unhashed_and_flagged(self) -> None:
        big = self.data / "big.bin"
        with open(big, "wb") as handle:
            handle.truncate(v.HASH_LIMIT + 1)
        before = self.snap()
        self.assertIsNone(before["ux0/data/app/big.bin"]["sha256"])
        with open(big, "r+b") as handle:
            handle.seek(v.HASH_LIMIT + 1)
            handle.write(b"tail-marker")
        after = self.snap()
        diff = v.diff_snapshots(before, after)
        self.assertEqual(diff["modified"], [{"path": "ux0/data/app/big.bin", "size": v.HASH_LIMIT + 12, "sha256": None}])
        self.assertTrue(v.has_unhashed_change(before, after))
        # Without a before-hash the fresh content is the whole file.
        self.assertTrue(self.evaluate("expect-file-contains", "big.bin", before, after, "tail-marker")["satisfied"])

    def test_file_contains_finds_text_across_chunk_boundary(self) -> None:
        path = self.data / "chunks.bin"
        path.write_bytes(b"a" * (1024 * 1024 - 3) + b"needle" + b"b" * 10)
        self.assertTrue(v.file_contains(str(path), 0, b"needle"))
        self.assertFalse(v.file_contains(str(path), 1024 * 1024, b"needle"))


class LogTests(unittest.TestCase):
    def test_summary_counts_levels_and_extracts_tty(self) -> None:
        text = "\n".join(
            [
                "[19:29:07.940] |I| [main]: Vita3K v0.2.1 4111-ab71f829",
                "qt.core.qmetaobject.connectslotsbyname: No matching signal",
                "\x1b[31m[19:29:08.755] |E| [load_module]: Missing file at kd/bootimage.skprx\x1b[0m",
                "[19:29:08.946] |T| [write_file]: *** TTY: bevypoc source commit: ",
                "[19:29:08.946] |T| [write_file]: *** TTY: 81930e73",
                "[19:29:08.977] |W| [operator()]: Stubbed sceNetCtlInit import called. (Stub)",
                "[19:29:09.000] |C| [main]: critical",
                "[19:29:09.001] |D| [set_phase]: App session phase: Launching -> Running",
            ]
        )
        lines = v.clean_log_lines(text)
        self.assertFalse(any("\x1b" in line for line in lines))
        summary = v.summarize_log(lines, "emulator-stdout.log")
        self.assertEqual(summary["line_count"], 8)
        self.assertEqual(summary["levels"], {"T": 2, "D": 1, "I": 1, "W": 1, "E": 1, "C": 1, "?": 1})
        self.assertEqual(len(summary["tty"]), 2)
        self.assertEqual(
            summary["errors"],
            ["[19:29:08.755] |E| [load_module]: Missing file at kd/bootimage.skprx", "[19:29:09.000] |C| [main]: critical"],
        )
        self.assertEqual(summary["tail"], lines)

    def test_only_newlines_split_log_lines(self) -> None:
        lines = v.clean_log_lines("one\x0cstill one\u2028and on\r\ntwo\n")
        self.assertEqual(lines, ["one\x0cstill one\u2028and on", "two"])

    def test_summary_limits(self) -> None:
        lines = ["[00:00:00.000] |E| [f]: *** TTY: %d" % number for number in range(300)]
        summary = v.summarize_log(lines, "x")
        self.assertEqual((len(summary["errors"]), len(summary["tty"]), len(summary["tail"])), (20, 200, 40))

    def test_log_expectations_match_single_lines(self) -> None:
        lines = v.clean_log_lines("[19:29:08.946] |T| [write_file]: *** TTY: commit: \n\x1b[1mplain qt line\x1b[0m\n")
        expect = v.Expectation("expect-log", "plain qt", regex=re.compile("^plain qt line$"))
        self.assertTrue(v.evaluate_expectation(expect, {}, {}, lines)["satisfied"])
        reject = v.Expectation("reject-log", "TTY", regex=re.compile(r"\*\*\* TTY: commit"))
        result = v.evaluate_expectation(reject, {}, {}, lines)
        self.assertFalse(result["satisfied"])
        self.assertTrue(result["detail"].startswith("line 1: "))
        spanning = v.Expectation("expect-log", "x", regex=re.compile("commit: .*plain"))
        self.assertFalse(v.evaluate_expectation(spanning, {}, {}, lines)["satisfied"])


class VerdictTests(unittest.TestCase):
    @staticmethod
    def item(kind: str, satisfied: bool) -> dict:
        return {"kind": kind, "target": "t", "satisfied": satisfied, "detail": ""}

    def test_precedence(self) -> None:
        met = self.item("expect-file", True)
        unmet = self.item("expect-log", False)
        reject_hit = self.item("reject-log", False)
        reject_clear = self.item("reject-file", True)
        cases = [
            (("install_failed", True, [met]), ("environment_error", "install_failed")),
            ((None, True, [met]), ("fail", "emulator_crashed")),
            ((None, True, []), ("fail", "emulator_crashed")),
            ((None, True, [met, reject_hit]), ("fail", "emulator_crashed")),
            ((None, False, [met, reject_hit]), ("fail", "reject_matched")),
            ((None, False, [met, unmet]), ("fail", "expectation_unmet")),
            ((None, False, [met, reject_clear]), ("pass", None)),
            ((None, False, [reject_clear]), ("inconclusive", "no_expectations")),
            ((None, False, []), ("inconclusive", "no_expectations")),
        ]
        for arguments, expected in cases:
            with self.subTest(expected=expected):
                self.assertEqual(v.decide_verdict(*arguments), expected)

    def test_exit_codes(self) -> None:
        self.assertEqual(
            (v.EXIT_PASS, v.EXIT_FAIL, v.EXIT_USAGE, v.EXIT_ENVIRONMENT, v.EXIT_INCONCLUSIVE), (0, 1, 2, 3, 4)
        )
        self.assertEqual(
            [v.exit_code_for(name) for name in ("pass", "fail", "inconclusive", "environment_error")], [0, 1, 4, 3]
        )

    def test_exit_signal(self) -> None:
        codes = (None, 0, 1, 127, 128, 129, 139, 192, 193, 255, -11, -9)
        self.assertEqual(
            [v.exit_signal(code) for code in codes], [None, None, None, None, None, 1, 11, 64, None, None, 11, 9]
        )

    def test_privilege_check(self) -> None:
        self.assertFalse(v.is_privileged(1000, 1000))
        self.assertTrue(v.is_privileged(0, 0))
        self.assertTrue(v.is_privileged(1000, 0))
        self.assertTrue(v.is_privileged(1000, 1001))


class LayoutTests(TempDirCase):
    def test_instance_paths_per_host(self) -> None:
        root = str(self.tmp / "inst")
        linux = v.InstancePaths(root, "linux")
        self.assertEqual(linux.config_file, os.path.join(root, "xdg/config/Vita3K/config.yml"))
        self.assertEqual(linux.log_file, os.path.join(root, "xdg/cache/Vita3K/vita3k.log"))
        self.assertEqual(linux.vita_fs, os.path.join(root, "xdg/data/Vita3K/Vita3K"))
        self.assertEqual(sorted(linux.xdg_env()), ["XDG_CACHE_HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME"])
        mac = v.InstancePaths(root, "darwin")
        self.assertEqual(mac.config_file, os.path.join(root, "emulator/portable/config.yml"))
        self.assertEqual(mac.log_file, os.path.join(root, "emulator/portable/vita3k.log"))
        self.assertEqual(mac.vita_fs, os.path.join(root, "emulator/portable/fs"))
        self.assertEqual(mac.xdg_env(), {})
        for paths in (linux, mac):
            self.assertEqual(paths.runs_dir, os.path.join(root, "runs"))
            self.assertEqual(paths.lock_file, os.path.join(root, "run.lock"))
            self.assertEqual(paths.state_file, os.path.join(root, "run-state.json"))
            self.assertEqual(paths.version_cache, os.path.join(root, "emulator-version.json"))

    def test_instance_root_and_personal_paths(self) -> None:
        self.assertEqual(v.instance_root({"HOME": "/home/u"}), "/home/u/.vita3k-agent")
        self.assertEqual(v.instance_root({"HOME": "/home/u", "VITA3K_AGENT_HOME": "/srv/inst"}), "/srv/inst")
        self.assertEqual(v.personal_vita3k_paths("darwin", "/Users/u"), ["/Users/u/Library/Application Support/Vita3K"])
        self.assertEqual(
            v.personal_vita3k_paths("linux", "/home/u"),
            ["/home/u/.config/Vita3K", "/home/u/.cache/Vita3K", "/home/u/.local/share/Vita3K"],
        )

    def test_host_detection_seam_and_display_mode(self) -> None:
        self.assertEqual(v.detect_host({"VITA3K_VPK_HOST": "darwin"}), "darwin")
        self.assertEqual(v.detect_host({"VITA3K_VPK_HOST": "linux"}), "linux")
        with self.assertRaises(v.UsageError):
            v.detect_host({"VITA3K_VPK_HOST": "windows"})
        self.assertEqual(v.resolve_display_mode("auto", "darwin", {}), "host")
        self.assertEqual(v.resolve_display_mode("auto", "linux", {}), "xvfb")
        self.assertEqual(v.resolve_display_mode("auto", "linux", {"DISPLAY": ":0"}), "host")
        self.assertEqual(v.resolve_display_mode("auto", "linux", {"WAYLAND_DISPLAY": "wayland-0"}), "host")
        self.assertEqual(v.resolve_display_mode("xvfb", "darwin", {"DISPLAY": ":0"}), "xvfb")

    def make_executable(self, path: Path) -> Path:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("#!/bin/sh\n")
        path.chmod(0o755)
        return path

    def test_macos_discovery_requires_portable_layout(self) -> None:
        env = {"VITA3K_VPK_HOST": "darwin"}
        paths = v.InstancePaths(str(self.tmp / "inst"), v.detect_host(env))
        self.assertEqual(v.discover_binary(paths, env), (None, "emulator_missing"))
        binary = self.make_executable(self.tmp / "inst" / "emulator" / "Vita3K.app" / "Contents" / "MacOS" / "Vita3K")
        self.assertEqual(v.discover_binary(paths, env), (str(binary), "isolation_unavailable"))
        (self.tmp / "inst" / "emulator" / "portable").mkdir()
        self.assertEqual(v.discover_binary(paths, env), (str(binary), None))

        outside = self.make_executable(self.tmp / "Applications" / "Vita3K.app" / "Contents" / "MacOS" / "Vita3K")
        (self.tmp / "Applications" / "portable").mkdir()
        env_outside = dict(env, VITA3K_BIN=str(outside))
        self.assertEqual(v.discover_binary(paths, env_outside), (str(outside), "isolation_unavailable"))
        # A link inside the instance that points to an outside bundle is still outside.
        link = self.tmp / "inst" / "emulator" / "Linked.app"
        os.symlink(self.tmp / "Applications" / "Vita3K.app", link)
        env_link = dict(env, VITA3K_BIN=str(link / "Contents" / "MacOS" / "Vita3K"))
        self.assertEqual(v.discover_binary(paths, env_link)[1], "isolation_unavailable")
        env_missing = dict(env, VITA3K_BIN=str(self.tmp / "absent"))
        self.assertEqual(v.discover_binary(paths, env_missing), (None, "emulator_missing"))

    def test_linux_discovery_order(self) -> None:
        env = {"VITA3K_VPK_HOST": "linux", "PATH": str(self.tmp / "bin")}
        paths = v.InstancePaths(str(self.tmp / "inst"), "linux")
        self.assertEqual(v.discover_binary(paths, env), (None, "emulator_missing"))
        on_path = self.make_executable(self.tmp / "bin" / "Vita3K")
        self.assertEqual(v.discover_binary(paths, env), (str(on_path), None))
        appimage = self.make_executable(self.tmp / "inst" / "emulator" / "Vita3K-aarch64.AppImage")
        self.assertEqual(v.discover_binary(paths, env), (str(appimage), None))
        extracted = self.make_executable(self.tmp / "inst" / "emulator" / "squashfs-root" / "AppRun")
        self.assertEqual(v.discover_binary(paths, env), (str(extracted), None))
        not_executable = self.tmp / "plain"
        not_executable.write_text("x")
        self.assertEqual(v.discover_binary(paths, dict(env, VITA3K_BIN=str(not_executable))), (None, "emulator_missing"))


class XwdTests(unittest.TestCase):
    def test_real_dump_converts(self) -> None:
        png = v.xwd_to_png((FIXTURES / "vita3k-frame-crop-64x48.xwd").read_bytes())
        width, height, rows = decode_png(png)
        self.assertEqual((width, height), (64, 48))
        self.assertEqual(rows[0][0], (24, 16, 48))
        self.assertEqual(rows[4][8], (255, 96, 96))
        self.assertEqual({pixel for row in rows for pixel in row}, {(24, 16, 48), (255, 96, 96)})

    def test_truncated_dump_raises(self) -> None:
        data = (FIXTURES / "vita3k-frame-crop-64x48.xwd").read_bytes()
        for cut in (50, 200, len(data) - 1):
            with self.subTest(cut=cut), self.assertRaises(v.XwdError):
                v.xwd_to_png(data[:cut])

    def test_unsupported_format_raises(self) -> None:
        data = bytearray((FIXTURES / "vita3k-frame-crop-64x48.xwd").read_bytes())
        struct.pack_into(">I", data, 4, 6)
        with self.assertRaises(v.XwdError):
            v.xwd_to_png(bytes(data))
        with self.assertRaises(v.XwdError):
            v.xwd_to_png(make_xwd(2, 1, b"\x00" * 4, 16, 4, 0))

    def test_unsupported_masks_and_header_raise(self) -> None:
        pixels = bytes(8)
        for masks in ((0, 0, 0), (0x3FF00000, 0x000FFC00, 0x000003FF), (0xFF000000, 0x00FF0000, 0x0000FF00)):
            with self.subTest(masks=masks), self.assertRaises(v.XwdError):
                v.xwd_to_png(make_xwd(2, 1, pixels[:6], 24, 6, 0, masks))
        short_header = bytearray(make_xwd(2, 1, pixels, 32, 8, 0))
        struct.pack_into(">I", short_header, 0, 50)
        with self.assertRaises(v.XwdError):
            v.xwd_to_png(bytes(short_header))
        with self.assertRaises(v.XwdError):
            v.xwd_to_png(make_xwd(2, 1, pixels, 32, 4, 0))  # a row shorter than its pixels

    def test_synthetic_24_bit_and_padded_dumps(self) -> None:
        expected = (2, 2, [[(255, 0, 0), (1, 2, 3)], [(4, 5, 6), (0, 0, 255)]])
        # 24 bits per pixel, most significant byte first, rows padded to 8 bytes.
        big_24 = make_xwd(2, 2, bytes([255, 0, 0, 1, 2, 3, 9, 9, 4, 5, 6, 0, 0, 255, 9, 9]), 24, 8, 1)
        # 32 bits per pixel, least significant byte first, rows padded to 12 bytes.
        little_32 = make_xwd(
            2, 2, bytes([0, 0, 255, 0, 3, 2, 1, 0, 9, 9, 9, 9, 6, 5, 4, 0, 255, 0, 0, 0, 9, 9, 9, 9]), 32, 12, 0
        )
        for name, dump in (("big 24", big_24), ("little 32 padded", little_32)):
            with self.subTest(dump=name):
                self.assertEqual(decode_png(v.xwd_to_png(dump)), expected)

    def test_synthetic_32_bit_dumps(self) -> None:
        # Two pixels: red (255, 0, 0) and a mixed colour (1, 2, 3).
        little = make_xwd(2, 1, bytes([0, 0, 255, 0, 3, 2, 1, 0]), 32, 8, 0)
        big = make_xwd(2, 1, bytes([0, 255, 0, 0, 0, 1, 2, 3]), 32, 8, 1)
        for name, dump in (("little", little), ("big", big)):
            with self.subTest(order=name):
                self.assertEqual(decode_png(v.xwd_to_png(dump)), (2, 1, [[(255, 0, 0), (1, 2, 3)]]))


class RunDirTests(TempDirCase):
    def test_naming_and_order(self) -> None:
        runs = str(self.tmp / "runs")
        first = v.create_run_dir(runs, "20261002T120000Z", "ABCD12345")
        second = v.create_run_dir(runs, "20261002T120000Z", "ABCD12345")
        third = v.create_run_dir(runs, "20261002T120001Z", "ABCD12345")
        names = [os.path.basename(path) for path in (first, second, third)]
        self.assertEqual(names[:2], ["20261002T120000Z-ABCD12345", "20261002T120000Z-ABCD12345-2"])
        self.assertEqual(sorted(names), names)
        for name in names:
            self.assertTrue(v.RUN_DIR_RE.fullmatch(name))

    def test_prune_keeps_newest_and_ignores_other_entries(self) -> None:
        runs = self.tmp / "runs"
        runs.mkdir()
        names = ["202610%02dT120000Z-ABCD12345" % day for day in range(1, 6)]
        for name in names:
            (runs / name).mkdir()
            (runs / name / "result.json").write_text("{}")
        (runs / "keep-me").mkdir()
        target = self.tmp / "target"
        target.mkdir()
        os.symlink(target, runs / "20260101T000000Z-ABCD12345")
        removed = v.prune_run_dirs(str(runs), str(runs / names[-1]), keep=3)
        self.assertEqual([os.path.basename(path) for path in removed], names[:2])
        self.assertEqual(
            sorted(os.listdir(runs)), sorted(names[2:] + ["keep-me", "20260101T000000Z-ABCD12345"])
        )
        self.assertTrue(target.is_dir())
        # The current run directory survives even when it sorts first.
        self.assertEqual(v.prune_run_dirs(str(runs), str(runs / names[2]), keep=0), [str(runs / names[3]), str(runs / names[4])])
        self.assertTrue((runs / names[2]).is_dir())


class PlanTests(TempDirCase):
    def parse(self, *arguments: str):
        return v.build_parser().parse_args(["run", "x.vpk", *arguments])

    def test_plan_validates_before_any_change(self) -> None:
        paths = v.InstancePaths(str(self.tmp / "inst"), "linux")
        vpk = v.inspect_vpk(str(make_vpk(self.tmp / "x.vpk", "OWNTITLE1")))
        seed = self.tmp / "a=b.txt"
        seed.write_text("seed")
        plan = v.build_run_plan(
            self.parse(
                "--expect-file-contains", "ux0:data/a.txt=k=v", "--expect-log", "x+", "--reject-log", "y",
                "--reject-file", "ux0:data/b.txt", "--seed", "%s=ux0:data/x.txt" % seed,
                "--clean", "ux0:data/app/", "--stop-when-satisfied",
            ),
            paths, vpk,
        )
        self.assertEqual([item.kind for item in plan.expectations], ["expect-file-contains", "expect-log", "reject-log", "reject-file"])
        self.assertEqual((plan.expectations[0].rel, plan.expectations[0].text), ("ux0/data/a.txt", "k=v"))
        self.assertEqual(plan.seeds, [(str(seed), os.path.join(paths.vita_fs, "ux0/data/x.txt"))])
        self.assertEqual(plan.cleans, [os.path.join(paths.vita_fs, "ux0/data/app")])
        self.assertFalse(os.path.exists(paths.root))

    def test_plan_rejects_bad_arguments(self) -> None:
        paths = v.InstancePaths(str(self.tmp / "inst"), "linux")
        vpk = v.inspect_vpk(str(make_vpk(self.tmp / "x.vpk", "OWNTITLE1")))
        cases = [
            ("--stop-when-satisfied",),
            ("--stop-when-satisfied", "--reject-log", "x"),
            ("--expect-log", "("),
            ("--expect-file", "app0:x"),
            ("--clean", "ux0:app/OWNTITLE1"),
            ("--seed", "%s=ux0:data/x.txt" % (self.tmp / "absent"),),
            ("--timeout", "0"),
            ("--timeout", "nan"),
            ("--timeout", "inf"),
            ("--settle", "-1"),
            ("--settle", "nan"),
            ("--settle", "inf"),
        ]
        for arguments in cases:
            with self.subTest(arguments=arguments), self.assertRaises(v.UsageError):
                v.build_run_plan(self.parse(*arguments), paths, vpk)


class SyntaxTests(unittest.TestCase):
    def test_python_3_9_syntax(self) -> None:
        sources = [SCRIPTS / "vita3k_vpk.py"] + sorted(Path(__file__).resolve().parent.glob("*.py"))
        for path in sources:
            with self.subTest(path=path.name):
                ast.parse(path.read_text(encoding="utf-8"), filename=str(path), feature_version=(3, 9))
                self.assertTrue(path.read_text(encoding="utf-8").startswith(("from __future__", "#!")))

    def test_script_avoids_newer_constructs(self) -> None:
        source = (SCRIPTS / "vita3k_vpk.py").read_text(encoding="utf-8")
        self.assertIn("from __future__ import annotations", source)
        self.assertIsNone(re.search(r"^\s*match\s.+:\s*(#.*)?$", source, re.MULTILINE))
        self.assertNotIn("strict=", source)
        self.assertNotIn("datetime.UTC", source)
        for node in ast.walk(ast.parse(source)):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id in ("isinstance", "issubclass"):
                # `X | Y` as a class argument needs Python 3.10.
                self.assertFalse(any(isinstance(argument, ast.BinOp) for argument in node.args), node.lineno)


if __name__ == "__main__":
    unittest.main()
