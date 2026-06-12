#!/usr/bin/env python3
import http.server
import importlib.util
import json
import os
import pathlib
import subprocess
import sys
import threading
import unittest
import urllib.parse

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
        def limited(items):
            count = 0
            for item in items:
                if limit is not None and count >= limit:
                    return
                yield item
                count += 1

        if path.startswith("/search/issues?"):
            import urllib.parse
            query = urllib.parse.parse_qs(urllib.parse.urlparse(path).query)["q"][0]
            yield from limited(self.searches[query])
            return
        parts = path.strip("/").split("/")
        repo = f"{parts[1]}/{parts[2]}"
        number = int(parts[4])
        kind = parts[3]
        yield from limited(self.comments.get((repo, number, kind), []))


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

    def test_parse_next_link_extracts_next_url(self):
        link = '<https://api.github.com/search/issues?page=2>; rel="next", <https://api.github.com/search/issues?page=3>; rel="last"'
        self.assertEqual(mod.parse_next_link(link), "https://api.github.com/search/issues?page=2")

    def test_contains_login_mention_matches_only_exact_login(self):
        self.assertTrue(mod.contains_login_mention("ping @mattsp1290 please", "mattsp1290"))
        self.assertFalse(mod.contains_login_mention("ping @mattsp1290-bot please", "mattsp1290"))
        self.assertFalse(mod.contains_login_mention("email mattsp1290@example.com", "mattsp1290"))

    def test_detail_collection_error_keeps_search_match_in_report(self):
        class ErrorClient(FakeClient):
            def get(self, path):
                if path == "/user":
                    return {"login": "mattsp1290"}
                raise mod.GitHubError("SAML protected")

        report = mod.collect_attention(ErrorClient(), max_search_items=1)
        # max_search_items is per GitHub search query, so one item from each
        # attention search should survive as an error item.
        self.assertEqual(report["attention_count"], 3)
        self.assertTrue(all("collection_error" in item for item in report["items"]))


class MockGitHubHandler(http.server.BaseHTTPRequestHandler):
    requests_seen = []

    def log_message(self, format, *args):
        return

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        query = urllib.parse.parse_qs(parsed.query)
        MockGitHubHandler.requests_seen.append(
            {
                "path": parsed.path,
                "query": query,
                "authorization": self.headers.get("Authorization"),
            }
        )
        response = self.response_for(parsed.path, query)
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(response).encode("utf-8"))

    def response_for(self, path, query):
        if path == "/user":
            return {"login": "mattsp1290"}
        if path == "/search/issues":
            q = query["q"][0]
            if q == "is:pr is:open author:mattsp1290 archived:false":
                return {"items": [self.search_item("owned", 10)]}
            if q == "is:pr is:open review-requested:mattsp1290 archived:false":
                return {"items": [self.search_item("review", 20)]}
            if q == "is:pr is:open mentions:mattsp1290 archived:false":
                return {"items": [self.search_item("mentioned", 30)]}
            return {"items": []}
        if path == "/repos/acme/owned/pulls/10":
            return self.pr("owned", 10, "mattsp1290", "2026-02-01T00:00:00Z")
        if path == "/repos/acme/review/pulls/20":
            return self.pr("review", 20, "alice", "2026-02-02T00:00:00Z", requested=["mattsp1290"])
        if path == "/repos/acme/mentioned/pulls/30":
            return self.pr("mentioned", 30, "carol", "2026-02-03T00:00:00Z")
        if path.endswith("/reviews"):
            return []
        if path == "/repos/acme/mentioned/issues/30/comments":
            return [
                {
                    "body": "Could @mattsp1290 confirm this direction?",
                    "user": {"login": "carol"},
                    "created_at": "2026-02-03T00:00:00Z",
                    "html_url": "https://github.com/acme/mentioned/pull/30#issuecomment-1",
                }
            ]
        if path.endswith("/comments"):
            return []
        raise AssertionError(f"unhandled mock GitHub path: {path}")

    def search_item(self, repo, number):
        return {"url": f"http://mock.local/repos/acme/{repo}/issues/{number}", "pull_request": {}}

    def pr(self, repo, number, author, updated, requested=None):
        return {
            "state": "open",
            "title": f"{repo} title",
            "html_url": f"https://github.com/acme/{repo}/pull/{number}",
            "user": {"login": author},
            "draft": False,
            "created_at": updated,
            "updated_at": updated,
            "base": {"ref": "main"},
            "head": {"label": f"{author}:branch"},
            "requested_reviewers": [{"login": r} for r in (requested or [])],
            "requested_teams": [],
        }


class AttentionReportE2ETests(unittest.TestCase):
    def test_cli_pipes_search_detail_reviews_comments_to_json_with_mock_github(self):
        MockGitHubHandler.requests_seen = []
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), MockGitHubHandler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(server.shutdown)
        self.addCleanup(server.server_close)
        api_root = f"http://127.0.0.1:{server.server_port}"

        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--api-root", api_root, "--format", "json"],
            env={**os.environ, "GITHUB_TOKEN": "fake-token-for-mock"},
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
        )

        report = json.loads(result.stdout)
        self.assertEqual(report["viewer"], "mattsp1290")
        self.assertEqual(report["attention_count"], 3)
        by_repo = {item["repo"]: item for item in report["items"]}
        self.assertEqual(by_repo["acme/review"]["reasons"], ["review_requested"])
        self.assertEqual(by_repo["acme/mentioned"]["mention_hits"][0]["author"], "carol")
        self.assertEqual(by_repo["acme/owned"]["priority"], "medium")
        self.assertTrue(any(req["path"] == "/search/issues" for req in MockGitHubHandler.requests_seen))
        self.assertTrue(any(req["path"] == "/repos/acme/mentioned/issues/30/comments" for req in MockGitHubHandler.requests_seen))
        self.assertTrue(all(req["authorization"] == "Bearer fake-token-for-mock" for req in MockGitHubHandler.requests_seen))


if __name__ == "__main__":
    unittest.main()
