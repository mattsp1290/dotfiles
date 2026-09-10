from __future__ import annotations

import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SKILL_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = SKILL_ROOT / "scripts"
sys.path.insert(0, str(SCRIPTS))

import validate_project as validator  # noqa: E402


def valid_value() -> dict[str, object]:
    return {
        "schema_version": 1,
        "project": {
            "id": "paper-trail",
            "name": "Paper Trail",
            "vision": "Help a reader trace a claim to the evidence that supports it.",
            "repository_identity": {
                "kind": "remote-url",
                "value": "https://example.com/acme/paper-trail",
            },
        },
        "comparators": [
            {
                "name": "Existing Research Product",
                "official_sources": ["https://example.com/products/research"],
                "relevance": "It demonstrates an observable citation-review journey.",
            }
        ],
        "evaluation_lenses": [
            {
                "name": "Evidence traceability",
                "question": "Can a reader move from a claim to its supporting source?",
            }
        ],
        "acceptance_journey": "A reader opens one report, follows one claim to its source, and returns to the report.",
        "non_goals": [],
        "ecosystem": {"related_repositories": []},
    }


class RepositoryCase(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name) / "repo"
        self.root.mkdir()
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def write(self, value: object | None = None, *, data: bytes | None = None) -> Path:
        agents = self.root / ".agents"
        agents.mkdir(exist_ok=True)
        path = agents / "next-milestone.json"
        path.write_bytes(data if data is not None else validator.canonical_bytes(value or valid_value()))
        return path

    def assert_failure(self, code: int, path_fragment: str) -> validator.ValidationFailure:
        with self.assertRaises(validator.ValidationFailure) as caught:
            validator.validate_repository(str(self.root))
        self.assertEqual(code, caught.exception.code)
        self.assertTrue(any(path_fragment in error for error in caught.exception.errors), caught.exception.errors)
        return caught.exception


class ValidatorTests(RepositoryCase):
    def test_valid_minimum_passes_and_returns_canonical_bytes(self) -> None:
        expected = validator.canonical_bytes(valid_value())
        self.write(data=expected)
        value, data = validator.validate_repository(str(self.root))
        self.assertEqual("paper-trail", value["project"]["id"])
        self.assertEqual(expected, data)

    def test_valid_full_fixture_passes(self) -> None:
        value = valid_value()
        value["non_goals"] = ["Live collaborative editing"]
        value["ecosystem"]["related_repositories"] = [
            {"id": "renderer", "path_hint": "${HOME}/git/renderer", "role": "Renders exported reports."},
            {"id": "indexer", "path_hint": "/opt/projects/indexer", "role": "Indexes source metadata."},
        ]
        self.write(value)
        validator.validate_repository(str(self.root))

    def test_reference_product_shapes_fit_the_generic_schema(self) -> None:
        fixtures = (
            ("eino-agent", "Embedder control", "https://github.com/earendil-works/pi", "A host constructs, runs, observes, and cancels one agent through public APIs."),
            ("eino-tui", "Interactive continuity", "https://github.com/mariozechner/pi-coding-agent", "A user starts a terminal session, follows progress, interrupts it, and resumes safely."),
            ("eino-channels", "Shared conversation", "https://github.com/CopilotKit/OpenTag", "A participant delegates one task in a shared thread and receives the routed result."),
        )
        for project_id, lens, comparator_url, journey in fixtures:
            with self.subTest(project_id=project_id):
                value = valid_value()
                value["project"] = {
                    "id": project_id,
                    "name": project_id.replace("-", " ").title(),
                    "vision": f"Enable a dependable {lens.lower()} outcome through public boundaries.",
                    "repository_identity": {"kind": "module", "value": f"github.com/cloudwego/{project_id}"},
                }
                value["comparators"] = [{"name": "Reference product", "official_sources": [comparator_url], "relevance": f"It provides current evidence for {lens.lower()}."}]
                value["evaluation_lenses"] = [{"name": lens, "question": f"Can the product complete the configured {lens.lower()} journey?"}]
                value["acceptance_journey"] = journey
                self.write(value)
                validator.validate_repository(str(self.root))

    def test_absent_is_distinct_and_read_only(self) -> None:
        self.assert_failure(validator.ABSENT, "file is absent")
        self.assertFalse((self.root / ".agents").exists())

    def test_root_must_be_absolute_git_root(self) -> None:
        with self.assertRaises(validator.ValidationFailure) as caught:
            validator.validate_root("relative")
        self.assertEqual(validator.UNSAFE, caught.exception.code)
        nested = self.root / "nested"
        nested.mkdir()
        with self.assertRaises(validator.ValidationFailure):
            validator.validate_root(str(nested))

    def test_parent_and_leaf_symlinks_are_unsafe(self) -> None:
        outside = Path(self.temp.name) / "outside"
        outside.mkdir()
        (self.root / ".agents").symlink_to(outside, target_is_directory=True)
        self.assert_failure(validator.UNSAFE, ".agents")
        (self.root / ".agents").unlink()
        (self.root / ".agents").mkdir()
        external = outside / "metadata.json"
        external.write_bytes(validator.canonical_bytes(valid_value()))
        (self.root / ".agents" / "next-milestone.json").symlink_to(external)
        self.assert_failure(validator.UNSAFE, "symlinks")

    def test_malformed_duplicate_invalid_utf8_and_oversized_are_distinct(self) -> None:
        self.write(data=b"{")
        self.assert_failure(validator.MALFORMED, "malformed JSON")
        self.write(data=b'{"schema_version":1,"schema_version":1}')
        self.assert_failure(validator.MALFORMED, "duplicate object key")
        self.write(data=b"\xff")
        self.assert_failure(validator.MALFORMED, "invalid UTF-8")
        self.write(data=b" " * (validator.MAX_FILE_BYTES + 1))
        self.assert_failure(validator.MALFORMED, "exceeds")

    def test_unsupported_version_has_stable_class(self) -> None:
        value = valid_value()
        value["schema_version"] = 2
        self.write(value)
        self.assert_failure(validator.UNSUPPORTED, "schema_version")

    def test_unknown_missing_and_wrong_type_errors_have_field_paths(self) -> None:
        value = valid_value()
        value["mystery"] = True
        del value["acceptance_journey"]
        value["comparators"] = "wrong"
        self.write(value)
        failure = self.assert_failure(validator.INVALID, "$.mystery")
        joined = "\n".join(failure.errors)
        self.assertIn("$.acceptance_journey", joined)
        self.assertIn("comparators", joined)

    def test_required_core_fields_and_identifier_are_enforced(self) -> None:
        value = valid_value()
        value["project"]["id"] = "Not Valid"
        value["comparators"][0]["official_sources"] = []
        value["evaluation_lenses"] = []
        value["acceptance_journey"] = " "
        self.write(value)
        failure = self.assert_failure(validator.INVALID, "project.id")
        joined = "\n".join(failure.errors)
        self.assertIn("comparators[0].official_sources", joined)
        self.assertIn("evaluation_lenses", joined)
        self.assertIn("acceptance_journey", joined)

    def test_empty_vision_and_duplicate_names_fail(self) -> None:
        value = valid_value()
        value["project"]["vision"] = ""
        value["comparators"].append(copy.deepcopy(value["comparators"][0]))
        value["comparators"][1]["name"] = "  EXISTING RESEARCH PRODUCT  "
        value["evaluation_lenses"].append(copy.deepcopy(value["evaluation_lenses"][0]))
        self.write(value)
        failure = self.assert_failure(validator.INVALID, "project.vision")
        self.assertIn("comparators[1].name", "\n".join(failure.errors))
        self.assertIn("evaluation_lenses[1]", "\n".join(failure.errors))

    def test_url_shape_credentials_and_duplicate_sources_fail(self) -> None:
        for source in ("http://example.com/docs", "https://user:secret@example.com/docs", "/local"):
            with self.subTest(source=source):
                value = valid_value()
                value["comparators"][0]["official_sources"] = [source]
                self.write(value)
                self.assert_failure(validator.INVALID, "official_sources[0]")
        value = valid_value()
        value["comparators"][0]["official_sources"] = ["https://example.com/docs", "https://EXAMPLE.com/docs"]
        self.write(value)
        self.assert_failure(validator.INVALID, "official_sources[1]")

    def test_repository_identity_forms_and_normalization(self) -> None:
        self.assertEqual(
            "https://github.com/acme/widget",
            validator.normalize_remote_url("git@GitHub.COM:acme/widget.git"),
        )
        self.assertEqual(
            "https://github.com/acme/widget",
            validator.normalize_remote_url("https://GITHUB.com/acme/widget.git/"),
        )
        value = valid_value()
        value["project"]["repository_identity"] = {"kind": "module", "value": "github.com/acme/widget"}
        self.write(value)
        validator.validate_repository(str(self.root))
        for identity in (
            {"kind": "remote-url", "value": "git@github.com:acme/widget.git"},
            {"kind": "module", "value": "GitHub.com/acme/widget"},
            {"kind": "other", "value": "github.com/acme/widget"},
        ):
            with self.subTest(identity=identity):
                value = valid_value()
                value["project"]["repository_identity"] = identity
                self.write(value)
                self.assert_failure(validator.INVALID, "project.repository_identity")

    def test_bounds_are_enforced(self) -> None:
        value = valid_value()
        value["project"]["vision"] = "x" * (validator.MAX_STRING + 1)
        value["non_goals"] = [f"item-{index}" for index in range(validator.MAX_NON_GOALS + 1)]
        self.write(value)
        failure = self.assert_failure(validator.INVALID, "project.vision")
        self.assertIn("non_goals", "\n".join(failure.errors))

    def test_control_characters_are_rejected(self) -> None:
        value = valid_value()
        value["project"]["name"] = "Paper\nTrail"
        self.write(value)
        self.assert_failure(validator.INVALID, "project.name")

    def test_path_hint_grammar(self) -> None:
        invalid = ("relative/repo", "${HOME}/git/*", "${OTHER}/git/repo", "/tmp/../secret", "${HOME}//repo")
        for hint in invalid:
            with self.subTest(hint=hint):
                value = valid_value()
                value["ecosystem"]["related_repositories"] = [
                    {"id": "related", "path_hint": hint, "role": "Provides a public contract."}
                ]
                self.write(value)
                self.assert_failure(validator.INVALID, "path_hint")

    def test_noncanonical_json_fails(self) -> None:
        self.write(data=json.dumps(valid_value()).encode())
        self.assert_failure(validator.INVALID, "canonical")

    def test_noncanonical_key_order_fails(self) -> None:
        value = valid_value()
        reordered = {"project": value["project"], "schema_version": 1, **{key: item for key, item in value.items() if key not in ("project", "schema_version")}}
        self.write(reordered)
        self.assert_failure(validator.INVALID, "canonical schema order")

    def test_cli_success_does_not_echo_product_prose(self) -> None:
        self.write()
        result = subprocess.run(
            [sys.executable, str(SCRIPTS / "validate_project.py"), str(self.root)],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("project_id=paper-trail", result.stdout)
        self.assertNotIn("reader trace", result.stdout)


if __name__ == "__main__":
    unittest.main()
