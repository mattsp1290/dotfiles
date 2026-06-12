#!/usr/bin/env python3
import importlib.util
import pathlib
import sys
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "scripts" / "github-pr-attention.py"
spec = importlib.util.spec_from_file_location("github_pr_attention", SCRIPT)
assert spec is not None
assert spec.loader is not None
mod = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = mod
spec.loader.exec_module(mod)


class FakeClient:
    def __init__(self):
        self.searches = {
            "is:pr is:open author:mattsp1290 archived:false": [
                {"url": "https://api.github.com/repos/acme/owned/issues/1", "pull_request": {}}
            ],
            "is:pr is:open review-requested:mattsp1290 archived:false": [
                {"url": "https://api.github.com/repos/acme/review/issues/2", "pull_request": {}},
                {"url": "https://api.github.com/repos/acme/already-approved/issues/3", "pull_request": {}},
            ],
            "is:pr is:open mentions:mattsp1290 archived:false": [
                {"url": "https://api.github.com/repos/acme/mentioned/issues/4", "pull_request": {}},
                {"url": "https://api.github.com/repos/acme/title-only/issues/5", "pull_request": {}},
            ],
        }
        self.prs = {
            ("acme/owned", 1): self._pr("owned", 1, "mattsp1290", "2026-01-01T00:00:00Z"),
            ("acme/review", 2): self._pr("review", 2, "alice", "2026-01-02T00:00:00Z", requested=["mattsp1290"]),
            ("acme/already-approved", 3): self._pr("approved", 3, "bob", "2026-01-03T00:00:00Z", requested=["mattsp1290"]),
            ("acme/mentioned", 4): self._pr("mentioned", 4, "carol", "2026-01-04T00:00:00Z"),
            ("acme/title-only", 5): self._pr("title only", 5, "dana", "2026-01-05T00:00:00Z"),
        }
        self.reviews = {
            ("acme/owned", 1): [],
            ("acme/review", 2): [],
            ("acme/already-approved", 3): [{"user": {"login": "mattsp1290"}, "state": "APPROVED", "submitted_at": "2026-01-03T00:00:00Z"}],
            ("acme/mentioned", 4): [],
            ("acme/title-only", 5): [],
        }
        self.comments = {
            ("acme/mentioned", 4, "issues"): [
                {"body": "Can @mattsp1290 weigh in?", "user": {"login": "carol"}, "created_at": "2026-01-04T00:00:00Z", "html_url": "https://example/comment"}
            ],
            ("acme/title-only", 5, "issues"): [],
        }

    def _pr(self, title, num, author, updated, requested=None):
        return {
            "state": "open",
            "title": title,
            "html_url": f"https://github.com/acme/{title}/pull/{num}",
            "user": {"login": author},
            "draft": False,
            "created_at": updated,
            "updated_at": updated,
            "base": {"ref": "main"},
            "head": {"label": f"{author}:branch"},
            "requested_reviewers": [{"login": r} for r in (requested or [])],
            "requested_teams": [],
        }

    def get(self, path):
        if path == "/user":
            return {"login": "mattsp1290"}
        parts = path.strip("/").split("/")
        if len(parts) >= 5 and parts[0] == "repos" and parts[3] == "pulls":
            repo = f"{parts[1]}/{parts[2]}"
            number = int(parts[4])
            if len(parts) == 6 and parts[5].startswith("reviews"):
                return self.reviews[(repo, number)]
            return self.prs[(repo, number)]
        raise AssertionError(f"unexpected get {path}")

    def paged(self, path, *, limit=None, accept="application/vnd.github+json"):
        if path.startswith("/search/issues?"):
            import urllib.parse
            query = urllib.parse.parse_qs(urllib.parse.urlparse(path).query)["q"][0]
            yield from self.searches[query]
            return
        parts = path.strip("/").split("/")
        repo = f"{parts[1]}/{parts[2]}"
        number = int(parts[4])
        kind = parts[3]
        yield from self.comments.get((repo, number, kind), [])


class AttentionReportTests(unittest.TestCase):
    def test_collects_and_filters_attention_items(self):
        report = mod.collect_attention(FakeClient())
        keys = {(item["repo"], item["number"]): item for item in report["items"]}
        self.assertEqual(report["viewer"], "mattsp1290")
        self.assertIn(("acme/owned", 1), keys)
        self.assertIn(("acme/review", 2), keys)
        self.assertIn(("acme/mentioned", 4), keys)
        self.assertNotIn(("acme/already-approved", 3), keys)
        self.assertNotIn(("acme/title-only", 5), keys)
        self.assertEqual(keys[("acme/review", 2)]["priority"], "high")
        self.assertEqual(keys[("acme/mentioned", 4)]["mention_hits"][0]["author"], "carol")

    def test_markdown_render_is_agent_readable(self):
        report = mod.collect_attention(FakeClient())
        text = mod.render_markdown(report)
        self.assertIn("GitHub PR attention report", text)
        self.assertIn("Agent summary", text)
        self.assertIn("acme/review#2", text)


if __name__ == "__main__":
    unittest.main()
