from __future__ import annotations

import ast
import os
from pathlib import Path
import re
import sys
import unittest

SKILL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SKILL_ROOT / "scripts"))

import vita3k_vpk as v  # noqa: E402

SKILL = SKILL_ROOT / "SKILL.md"
INSTALL = SKILL_ROOT / "references" / "install.md"
EVIDENCE = SKILL_ROOT / "references" / "evidence.md"
ADAPTER = SKILL_ROOT / "agents" / "openai.yaml"
DOCUMENTS = (SKILL, INSTALL, EVIDENCE)
SCRIPT_SOURCE = (SKILL_ROOT / "scripts" / "vita3k_vpk.py").read_text(encoding="utf-8")
UNVERIFIED = "unverified until gate G2"
VERIFIED_RE = re.compile(r"verified \d{4}-\d{2}-\d{2}")


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def section(text: str, heading: str) -> str:
    """The body of one `## heading` or `### heading` section."""
    match = re.search(r"^(#{2,3}) %s\n(.*?)(?=^#{2,3} |\Z)" % re.escape(heading), text, re.MULTILINE | re.DOTALL)
    assert match, "no section %r" % heading
    return match.group(2)


def table_rows(text: str) -> list[list[str]]:
    """Cells of each table body row. A `\\|` inside a cell is not a separator."""
    rows = []
    for line in text.splitlines():
        if line.startswith("|") and not re.match(r"^\|[\s:|-]+\|$", line):
            cells = [cell.strip().replace("\\|", "|") for cell in re.split(r"(?<!\\)\|", line.strip().strip("|"))]
            rows.append(cells)
    return rows[1:]


def function_node(name: str) -> ast.FunctionDef:
    tree = ast.parse(SCRIPT_SOURCE)
    return next(node for node in ast.walk(tree) if isinstance(node, ast.FunctionDef) and node.name == name)


def text_constants(node: ast.AST) -> list[str]:
    return [item.value for item in ast.walk(node) if isinstance(item, ast.Constant) and isinstance(item.value, str)]


def script_reasons() -> set[str]:
    """Every reason code the script can report, read from its source."""
    reasons = set()
    for name in ("run_launches", "discover_binary", "decide_verdict"):
        for node in ast.walk(function_node(name)):
            if isinstance(node, ast.Return) and node.value is not None:
                value = node.value.elts[-1] if isinstance(node.value, ast.Tuple) else node.value
                if isinstance(value, ast.Constant) and isinstance(value.value, str):
                    reasons.add(value.value)
    for name in ("finish_run", "cmd_run"):
        for node in ast.walk(function_node(name)):
            if isinstance(node, ast.Assign):
                names = [target.id for target in node.targets if isinstance(target, ast.Name)]
                value = node.value.elts[-1] if isinstance(node.value, ast.Tuple) else node.value
                if (names == ["reason"] or isinstance(node.value, ast.Tuple)) and isinstance(value, ast.Constant):
                    if isinstance(value.value, str):
                        reasons.add(value.value)
    return reasons


def script_warnings() -> set[str]:
    return set(re.findall(r'_add_warning\(result, "(\w+)"\)', SCRIPT_SOURCE))


def doctor_problems() -> dict:
    """Problem code -> whether it clears `ready`, read from cmd_doctor."""
    problems = {}
    for node in ast.walk(function_node("cmd_doctor")):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == "problem":
            problems[node.args[0].value] = node.args[3].value
    return problems


def run_parser_options() -> dict:
    subparsers = next(action for action in v.build_parser()._actions if getattr(action, "choices", None))
    return {name: set(parser._option_string_actions) - {"-h", "--help"} for name, parser in subparsers.choices.items()}


class SkillDocumentTests(unittest.TestCase):
    def test_frontmatter_has_exactly_name_and_description(self) -> None:
        text = read(SKILL)
        self.assertTrue(text.startswith("---\n"))
        frontmatter = text.split("---\n")[1]
        pairs = dict(line.split(": ", 1) for line in frontmatter.splitlines())
        self.assertEqual(sorted(pairs), ["description", "name"])
        self.assertEqual(pairs["name"], SKILL_ROOT.name)
        for word in ("Vita3K", "VPK", "Python 3", "Do not use"):
            self.assertIn(word, pairs["description"])
        # An unquoted YAML scalar must not hold a key separator or a comment start.
        for value in pairs.values():
            self.assertNotIn(": ", value)
            self.assertNotIn(" #", value)

    def test_every_documented_option_exists(self) -> None:
        options = run_parser_options()
        every_option = options["run"] | options["doctor"]
        for path in (SKILL, EVIDENCE):
            for token in sorted(set(re.findall(r"(?<![\w-])--[a-z][a-z-]*", read(path)))):
                with self.subTest(document=path.name, option=token):
                    if token.endswith("-"):  # `--expect-*` names a family of options
                        self.assertTrue(any(option.startswith(token) for option in every_option))
                    else:
                        self.assertIn(token, every_option)

    def test_option_table_matches_the_parser(self) -> None:
        rows = table_rows(section(read(SKILL), "`run` options"))
        documented = {re.match(r"`(--[a-z-]+)", row[0]).group(1) for row in rows}
        self.assertEqual(documented, run_parser_options()["run"])
        meaning = dict((re.match(r"`(--[a-z-]+)", row[0]).group(1), row[1]) for row in rows)
        self.assertIn("Default %d." % v.DEFAULT_TIMEOUT, meaning["--timeout"])
        self.assertIn("Default %d." % v.DEFAULT_SETTLE, meaning["--settle"])
        arguments = ["run", "x.vpk"]
        for row in rows:
            usage = row[0].strip("`").split(" ", 1)
            arguments.append(usage[0])
            if len(usage) == 2:
                arguments.append("host" if usage[0] == "--display" else "1")
        parsed = v.build_parser().parse_args(arguments)
        self.assertEqual((parsed.display, parsed.timeout, parsed.no_screenshot), ("host", 1.0, True))
        self.assertIn("--display auto|xvfb|host", read(SKILL))
        self.assertEqual(v.DISPLAY_MODES, ("auto", "xvfb", "host"))

    def test_exit_code_table_matches_the_constants(self) -> None:
        rows = dict((int(row[0]), row[1]) for row in table_rows(section(read(SKILL), "Exit codes")))
        expected = {
            v.EXIT_PASS: "`pass`",
            v.EXIT_FAIL: "`fail`",
            v.EXIT_USAGE: "Usage error",
            v.EXIT_ENVIRONMENT: "`environment_error`",
            v.EXIT_INCONCLUSIVE: "`inconclusive`",
        }
        self.assertEqual(sorted(rows), sorted(expected))
        for code, word in expected.items():
            self.assertIn(word, rows[code])
        for verdict in ("pass", "fail", "inconclusive", "environment_error"):
            self.assertIn("`%s`" % verdict, rows[v.exit_code_for(verdict)])

    def test_environment_variables(self) -> None:
        rows = table_rows(section(read(SKILL), "Environment variables"))
        self.assertEqual([row[0] for row in rows], ["`VITA3K_AGENT_HOME`", "`VITA3K_BIN`"])
        for name in ("VITA3K_AGENT_HOME", "VITA3K_BIN"):
            self.assertIn('"%s"' % name, SCRIPT_SOURCE)
        # The test seams stay undocumented.
        for document in DOCUMENTS:
            self.assertNotIn("VITA3K_VPK_", read(document))

    def test_doctor_problem_table_matches_the_script(self) -> None:
        rows = table_rows(section(read(SKILL), "Commands"))
        documented = dict((row[0].strip("`"), row[1] == "yes") for row in rows if row[1] in ("yes", "no"))
        self.assertEqual(documented, doctor_problems())
        self.assertEqual(len(documented), 9)
        verification = section(read(INSTALL), "Verification")
        clears, keeps = verification.split("do not clear `ready`")[1], verification.split("do not clear `ready`")[0]
        for code, blocks in doctor_problems().items():
            with self.subTest(problem=code):
                self.assertIn("`%s`" % code, clears if blocks else keeps)

    def test_required_sections_in_order(self) -> None:
        headings = re.findall(r"^## (.+)$", read(SKILL), re.MULTILINE)
        self.assertEqual(headings, ["Workflow", "Commands", "Invariants", "Reporting"])
        self.assertEqual(len(re.findall(r"^\d+\. ", section(read(SKILL), "Workflow"), re.MULTILINE)), 7)


class ReferenceTests(unittest.TestCase):
    def test_relative_links_resolve(self) -> None:
        for path in DOCUMENTS:
            for target in re.findall(r"\]\(([^)]+)\)", read(path)):
                if re.match(r"[a-z]+://", target):
                    continue
                with self.subTest(document=path.name, link=target):
                    self.assertTrue((path.parent / target.split("#")[0]).is_file())
        self.assertIn("(references/install.md)", read(SKILL))
        self.assertIn("(references/evidence.md)", read(SKILL))

    def test_no_file_refers_to_the_plan_directory(self) -> None:
        needle = ("agents/" + "plans").encode("ascii")
        for directory, subdirs, files in os.walk(SKILL_ROOT):
            subdirs[:] = [name for name in subdirs if name != "__pycache__"]
            for name in files:
                path = Path(directory) / name
                with self.subTest(file=str(path.relative_to(SKILL_ROOT))):
                    self.assertNotIn(needle, path.read_bytes())

    def test_documents_are_tool_neutral_and_host_neutral(self) -> None:
        for path in DOCUMENTS:
            text = read(path)
            for word in ("Claude", "Codex", "/Users/", "/home/"):
                with self.subTest(document=path.name, word=word):
                    self.assertNotIn(word, text)

    def test_references_state_the_verified_version(self) -> None:
        for path in (INSTALL, EVIDENCE):
            with self.subTest(document=path.name):
                first_paragraph = read(path).split("\n\n")[1]
                self.assertRegex(first_paragraph, r"Vita3K v\d+\.\d+\.\d+ \d+-[0-9a-f]{8}")
                self.assertRegex(first_paragraph, r"\d{4}-\d{2}-\d{2}")

    def test_install_sections_named_by_doctor_exist(self) -> None:
        headings = re.findall(r"^## (.+)$", read(INSTALL), re.MULTILINE)
        self.assertEqual(
            headings,
            ["Instance layout", "Linux aarch64 and x86_64", "Headless Linux", "macOS", "Firmware (optional)",
             "Updating and removing", "Verification"],
        )
        for heading in ("macOS", "Linux aarch64 and x86_64", "Firmware (optional)"):
            self.assertIn('"%s"' % heading, SCRIPT_SOURCE.replace('\\"', '"'))

    def test_every_macos_step_is_marked(self) -> None:
        steps = re.findall(r"^\d+\. .*$", section(read(INSTALL), "macOS"), re.MULTILINE)
        self.assertGreaterEqual(len(steps), 6)
        for step in steps:
            with self.subTest(step=step[:40]):
                self.assertTrue(UNVERIFIED in step or VERIFIED_RE.search(step), step)

    def test_install_layout_matches_the_script(self) -> None:
        text = section(read(INSTALL), "Instance layout")
        for host in ("linux", "darwin"):
            paths = v.InstancePaths("/root-of-instance", host)
            for value in (paths.config_file, paths.log_file, paths.vita_fs, paths.runs_dir, paths.lock_file,
                          paths.state_file, paths.version_cache):
                with self.subTest(host=host, path=value):
                    self.assertIn("`%s" % os.path.relpath(value, "/root-of-instance"), text)
        for path in v.personal_vita3k_paths("linux", "~") + v.personal_vita3k_paths("darwin", "~"):
            self.assertIn("`%s`" % path, text)
        # Every place where the script looks for the emulator is in the layout table.
        candidates = set()
        for node in ast.walk(function_node("discover_binary")):
            if isinstance(node, ast.Call) and getattr(node.func, "attr", "") == "join":
                candidates.add("emulator/" + "/".join(text_constants(node)))
        self.assertEqual(len(candidates), 5)
        emulator_row = next(row for row in table_rows(text) if row[0].startswith("Emulator"))
        for candidate in candidates:
            with self.subTest(candidate=candidate):
                self.assertIn("`%s`" % candidate, " ".join(emulator_row))
        self.assertIn("`Vita3K` on `PATH`", emulator_row[1])
        self.assertIn('shutil.which("Vita3K"', SCRIPT_SOURCE)
        for key, value in v.config_seed_pairs("xvfb"):
            self.assertIn("`%s: %s`" % (key, value), text)
        headless = section(read(INSTALL), "Headless Linux")
        self.assertIn("backend-renderer: %s" % v.HEADLESS_RENDERER, headless)
        for name, value in v.HEADLESS_ENV.items():
            self.assertIn("%s=%s" % (name, value), headless)

    def test_result_fields_match_the_script(self) -> None:
        vpk = v.VpkInfo("x.vpk", "0" * 64, "ABCD12345", "1" * 64)
        result = v.new_result("linux", "host", vpk, v.RunPlan())
        rows = table_rows(section(read(EVIDENCE), "Result fields"))
        documented = [name for row in rows for name in re.findall(r"`(\w+)`", row[0])]
        self.assertEqual(documented, list(result))
        for row in rows:
            top = re.findall(r"`(\w+)`", row[0])[0]
            if isinstance(result[top], dict):
                with self.subTest(field=top):
                    self.assertEqual(set(re.findall(r"`(\w+)`", row[1])), set(result[top]))
        summary = v.summarize_log([], "x")
        self.assertEqual(set(re.findall(r"`(\w+)`", dict((row[0], row[1]) for row in rows)["`log_summary`"])), set(summary))
        warnings = re.findall(r"`(\w+)`", dict((row[0], row[1]) for row in rows)["`warnings`"])
        self.assertEqual(set(warnings), script_warnings())
        self.assertEqual(len(warnings), 5)

    def test_reason_codes_match_the_script(self) -> None:
        documented = set(re.findall(r"reason `(\w+)`", section(read(EVIDENCE), "Failure classes")))
        self.assertEqual(documented, script_reasons())
        # The script side is read from the source. This guards the reading itself.
        self.assertEqual(len(documented), 15)
        self.assertLessEqual({"install_failed", "isolation_violated", "interrupted", "emulator_crashed"}, documented)

    def test_adapter_metadata(self) -> None:
        lines = read(ADAPTER).splitlines()
        self.assertEqual(lines[0], "interface:")
        pairs = dict(line.strip().split(": ", 1) for line in lines[1:])
        self.assertEqual(sorted(pairs), ["default_prompt", "display_name", "short_description"])
        self.assertEqual(pairs["display_name"], '"Vita3K Run VPK"')
        self.assertLessEqual(len(pairs["short_description"].strip('"')), 60)
        self.assertIn("$vita3k-run-vpk", pairs["default_prompt"])


if __name__ == "__main__":
    unittest.main()
