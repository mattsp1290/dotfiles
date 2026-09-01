#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


HERE = Path(__file__).resolve().parent
VALIDATOR = HERE / "validate_site.py"
RECEIPT_VERIFIER = HERE / "verify_review_receipt.py"
STARTER = HERE.parent / "assets" / "starter-site"


class ValidateSiteTests(unittest.TestCase):
    def run_validator(
        self, root: Path, *extra: str
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["python3", str(VALIDATOR), str(root), *extra],
            text=True,
            capture_output=True,
            check=False,
        )

    def test_starter_passes(self) -> None:
        result = self.run_validator(STARTER)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_missing_component_target_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            copy = Path(tmp) / "site"
            shutil.copytree(STARTER, copy)
            (copy / "components" / "r1.html").unlink()
            result = self.run_validator(copy)
            self.assertEqual(result.returncode, 1)
            self.assertIn("missing local target", result.stdout)

    def test_detached_component_ref_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            copy = Path(tmp) / "site"
            shutil.copytree(STARTER, copy)
            schematic = copy / "schematic" / "index.html"
            text = schematic.read_text(encoding="utf-8")
            text = text.replace('class="component-link"', 'class="plain-link"')
            schematic.write_text(text, encoding="utf-8")
            result = self.run_validator(copy)
            self.assertEqual(result.returncode, 1)
            self.assertIn("outside a component link", result.stdout)

    def test_non_html_component_target_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            copy = Path(tmp) / "site"
            shutil.copytree(STARTER, copy)
            schematic = copy / "schematic" / "index.html"
            text = schematic.read_text(encoding="utf-8").replace(
                "../components/r1.html", "../assets/styles.css", 1
            )
            schematic.write_text(text, encoding="utf-8")
            result = self.run_validator(copy)
            self.assertEqual(result.returncode, 1)
            self.assertIn("component link must target HTML", result.stdout)

    def test_generic_component_target_fails_identity_check(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            copy = Path(tmp) / "site"
            shutil.copytree(STARTER, copy)
            schematic = copy / "schematic" / "index.html"
            text = schematic.read_text(encoding="utf-8")
            text = text.replace("../components/r1.html", "../components/index.html")
            text = text.replace("../components/c1.html", "../components/index.html")
            schematic.write_text(text, encoding="utf-8")
            result = self.run_validator(copy)
            self.assertEqual(result.returncode, 1)
            self.assertIn("target does not declare", result.stdout)

    def test_unreachable_page_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            copy = Path(tmp) / "site"
            shutil.copytree(STARTER, copy)
            (copy / "orphan.html").write_text(
                "<!doctype html><html lang='en'><head><title>Orphan</title></head>"
                "<body><main>Unlinked page</main></body></html>",
                encoding="utf-8",
            )
            result = self.run_validator(copy)
            self.assertEqual(result.returncode, 1)
            self.assertIn("unreachable HTML page: orphan.html", result.stdout)

    def test_commented_css_tokens_and_remote_import_fail(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            copy = Path(tmp) / "site"
            shutil.copytree(STARTER, copy)
            (copy / "assets" / "styles.css").write_text(
                "/* color-scheme :focus-visible prefers-reduced-motion */\n"
                '@import url("https://example.invalid/remote.css");\n',
                encoding="utf-8",
            )
            result = self.run_validator(copy)
            self.assertEqual(result.returncode, 1)
            self.assertIn("remote @import dependency", result.stdout)
            self.assertIn("missing a :focus-visible rule", result.stdout)

    def test_symlink_in_payload_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            copy = Path(tmp) / "site"
            shutil.copytree(STARTER, copy)
            (copy / "assets" / "linked.css").symlink_to(copy / "assets" / "styles.css")
            result = self.run_validator(copy)
            self.assertEqual(result.returncode, 1)
            self.assertIn("symlink is not publishable", result.stdout)

    def test_manifest_lists_only_validated_payload(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            manifest = Path(tmp) / "payload.txt"
            result = self.run_validator(STARTER, "--manifest", str(manifest))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            entries = manifest.read_text(encoding="utf-8").splitlines()
            self.assertIn("index.html", entries)
            self.assertIn("schematic/index.html", entries)
            self.assertTrue(all(not entry.startswith(".") for entry in entries))

    def test_unreferenced_secret_file_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            copy = Path(tmp) / "site"
            shutil.copytree(STARTER, copy)
            (copy / "deployment-secrets.json").write_text(
                '{"api_key":"EXAMPLE_SECRET_SHOULD_NOT_PUBLISH"}', encoding="utf-8"
            )
            result = self.run_validator(copy)
            self.assertEqual(result.returncode, 1)
            self.assertIn("unreferenced file is not publishable", result.stdout)

    def test_referenced_secret_assignment_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            copy = Path(tmp) / "site"
            shutil.copytree(STARTER, copy)
            (copy / "public-data.json").write_text(
                '{"api_key":"EXAMPLE_SECRET_SHOULD_NOT_PUBLISH"}', encoding="utf-8"
            )
            index = copy / "index.html"
            index.write_text(
                index.read_text(encoding="utf-8").replace(
                    "</main>", '<a href="public-data.json">Data</a></main>'
                ),
                encoding="utf-8",
            )
            result = self.run_validator(copy)
            self.assertEqual(result.returncode, 1)
            self.assertIn("possible secret assignment", result.stdout)

    def test_private_key_header_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            copy = Path(tmp) / "site"
            shutil.copytree(STARTER, copy)
            (copy / "leak.txt").write_text(
                "-----BEGIN OPENSSH PRIVATE KEY-----\nexample\n"
                "-----END OPENSSH PRIVATE KEY-----\n",
                encoding="utf-8",
            )
            index = copy / "index.html"
            index.write_text(
                index.read_text(encoding="utf-8").replace(
                    "</main>", '<a href="leak.txt">Leaked file</a></main>'
                ),
                encoding="utf-8",
            )
            result = self.run_validator(copy)
            self.assertEqual(result.returncode, 1)
            self.assertIn("possible secret assignment", result.stdout)

    def test_executable_link_and_file_asset_schemes_fail(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            copy = Path(tmp) / "site"
            shutil.copytree(STARTER, copy)
            index = copy / "index.html"
            index.write_text(
                index.read_text(encoding="utf-8").replace(
                    "</head>", '<script src="file:///etc/passwd"></script></head>'
                ).replace(
                    "</main>", '<a href="javascript:alert(1)">Unsafe</a></main>'
                ),
                encoding="utf-8",
            )
            result = self.run_validator(copy)
            self.assertEqual(result.returncode, 1)
            self.assertIn("unsafe link scheme", result.stdout)
            self.assertIn("non-local script dependency", result.stdout)

    def test_digest_changes_with_content(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            first = Path(tmp) / "first.sha256"
            second = Path(tmp) / "second.sha256"
            result = self.run_validator(STARTER, "--digest-file", str(first))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            copy = Path(tmp) / "site"
            shutil.copytree(STARTER, copy)
            index = copy / "index.html"
            index.write_text(
                index.read_text(encoding="utf-8").replace("One pole", "A single pole"),
                encoding="utf-8",
            )
            result = self.run_validator(copy, "--digest-file", str(second))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertNotEqual(first.read_text(), second.read_text())

    def test_review_receipt_is_bound_to_digest(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            digest = "a" * 64
            receipt = Path(tmp) / "receipt.json"
            receipt.write_text(
                json.dumps(
                    {
                        "schema_version": "schematic-site-review-v1",
                        "payload_sha256": digest,
                        "reviews": {
                            "independent": [
                                {"reviewer": "trace", "status": "complete"},
                                {"reviewer": "access", "status": "complete"},
                            ],
                            "adversarial": {"reviewer": "attack", "status": "complete"},
                            "accuracy": {"reviewer": "accuracy", "status": "complete"},
                            "correctness": {"reviewer": "correct", "status": "complete"},
                        },
                    }
                ),
                encoding="utf-8",
            )
            valid = subprocess.run(
                ["python3", str(RECEIPT_VERIFIER), str(receipt), digest],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(valid.returncode, 0, valid.stdout + valid.stderr)
            stale = subprocess.run(
                ["python3", str(RECEIPT_VERIFIER), str(receipt), "b" * 64],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(stale.returncode, 1)
            self.assertIn("does not match", stale.stdout)


if __name__ == "__main__":
    unittest.main()
