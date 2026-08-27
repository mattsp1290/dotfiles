#!/usr/bin/env python3
"""List open GitHub pull requests that need the authenticated user's attention.

Requires GITHUB_TOKEN. Uses only the Python standard library so it can run from a
fresh dotfiles checkout without installing dependencies.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Any, Iterable

API_ROOT = "https://api.github.com"
USER_AGENT = "dotfiles-github-pr-attention/1.0"
MENTION_RE_TEMPLATE = r"(?<![A-Za-z0-9_-])@{login}(?![A-Za-z0-9_-])"


class GitHubError(RuntimeError):
    """Raised for GitHub API failures."""


@dataclass(frozen=True)
class PullKey:
    owner: str
    repo: str
    number: int

    @property
    def repo_full_name(self) -> str:
        return f"{self.owner}/{self.repo}"


class GitHubClient:
    def __init__(self, token: str, api_root: str = API_ROOT) -> None:
        self.token = token
        self.api_root = api_root.rstrip("/")

    def request(self, path_or_url: str, *, accept: str = "application/vnd.github+json") -> tuple[Any, dict[str, str]]:
        if path_or_url.startswith("http://") or path_or_url.startswith("https://"):
            url = path_or_url
        else:
            url = f"{self.api_root}{path_or_url}"
        req = urllib.request.Request(
            url,
            headers={
                "Accept": accept,
                "Authorization": f"Bearer {self.token}",
                "User-Agent": USER_AGENT,
                "X-GitHub-Api-Version": "2022-11-28",
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                body = resp.read().decode("utf-8")
                data = json.loads(body) if body else None
                return data, {k.lower(): v for k, v in resp.headers.items()}
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            try:
                message = json.loads(body).get("message", body)
            except json.JSONDecodeError:
                message = body
            if exc.code == 403 and "rate limit" in message.lower():
                reset = exc.headers.get("X-RateLimit-Reset")
                reset_msg = ""
                if reset and reset.isdigit():
                    reset_msg = f"; resets at {dt.datetime.fromtimestamp(int(reset), dt.timezone.utc).isoformat()}"
                raise GitHubError(f"GitHub API rate limit exceeded{reset_msg}") from exc
            raise GitHubError(f"GitHub API HTTP {exc.code} for {url}: {message}") from exc
        except urllib.error.URLError as exc:
            raise GitHubError(f"GitHub API request failed for {url}: {exc.reason}") from exc

    def get(self, path_or_url: str, *, accept: str = "application/vnd.github+json") -> Any:
        return self.request(path_or_url, accept=accept)[0]

    def paged(self, path: str, *, limit: int | None = None, accept: str = "application/vnd.github+json") -> Iterable[Any]:
        url = f"{self.api_root}{path}"
        emitted = 0
        while url:
            data, headers = self.request(url, accept=accept)
            if isinstance(data, dict) and "items" in data:
                page_items = data["items"]
            elif isinstance(data, list):
                page_items = data
            else:
                raise GitHubError(f"Unexpected paginated response shape for {url}")
            for item in page_items:
                yield item
                emitted += 1
                if limit is not None and emitted >= limit:
                    return
            url = parse_next_link(headers.get("link", ""))
            if url:
                # Be gentle on search endpoints.
                time.sleep(0.15)


def parse_next_link(link_header: str) -> str | None:
    for part in link_header.split(","):
        if 'rel="next"' not in part:
            continue
        match = re.search(r"<([^>]+)>", part)
        if match:
            return match.group(1)
    return None


def search_path(query: str, per_page: int = 100) -> str:
    params = urllib.parse.urlencode({"q": query, "per_page": str(per_page), "sort": "updated", "order": "desc"})
    return f"/search/issues?{params}"


def pr_key_from_issue_url(issue_url: str) -> PullKey:
    # https://api.github.com/repos/OWNER/REPO/issues/123
    parsed = urllib.parse.urlparse(issue_url)
    parts = parsed.path.strip("/").split("/")
    if len(parts) < 5 or parts[0] != "repos" or parts[3] != "issues":
        raise ValueError(f"Cannot parse PR key from issue URL: {issue_url}")
    return PullKey(parts[1], parts[2], int(parts[4]))


def short_text(text: str, *, max_len: int = 280) -> str:
    collapsed = re.sub(r"\s+", " ", text or "").strip()
    if len(collapsed) <= max_len:
        return collapsed
    return collapsed[: max_len - 1].rstrip() + "…"


def iso_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def reverse_timestamp(value: str) -> float:
    """Return a sortable value that puts newer ISO timestamps first."""
    if not value:
        return 0.0
    try:
        normalized = value.replace("Z", "+00:00")
        return -dt.datetime.fromisoformat(normalized).timestamp()
    except ValueError:
        return 0.0


def latest_review_state_by_user(reviews: list[dict[str, Any]], login: str) -> str | None:
    user_reviews = [r for r in reviews if (r.get("user") or {}).get("login", "").lower() == login.lower()]
    if not user_reviews:
        return None
    user_reviews.sort(key=lambda r: r.get("submitted_at") or r.get("id") or "")
    return user_reviews[-1].get("state")


def contains_login_mention(text: str, login: str) -> bool:
    return bool(re.search(MENTION_RE_TEMPLATE.format(login=re.escape(login)), text or "", re.IGNORECASE))


def comment_mentions(client: GitHubClient, key: PullKey, login: str, max_mentions: int = 5) -> list[dict[str, str]]:
    mentions: list[dict[str, str]] = []
    endpoints = [
        (f"/repos/{key.repo_full_name}/issues/{key.number}/comments?per_page=100", "issue_comment"),
        (f"/repos/{key.repo_full_name}/pulls/{key.number}/comments?per_page=100", "review_comment"),
    ]
    for endpoint, kind in endpoints:
        for comment in client.paged(endpoint, limit=300):
            body = comment.get("body") or ""
            if not contains_login_mention(body, login):
                continue
            mentions.append(
                {
                    "kind": kind,
                    "author": (comment.get("user") or {}).get("login", "unknown"),
                    "created_at": comment.get("created_at", ""),
                    "url": comment.get("html_url", ""),
                    "snippet": short_text(body),
                }
            )
            if len(mentions) >= max_mentions:
                return mentions
    return mentions


def build_item(
    client: GitHubClient,
    key: PullKey,
    reasons: set[str],
    login: str,
    *,
    include_mentions: bool,
) -> dict[str, Any] | None:
    pr = client.get(f"/repos/{key.repo_full_name}/pulls/{key.number}")
    if pr.get("state") != "open":
        return None

    reviews = client.get(f"/repos/{key.repo_full_name}/pulls/{key.number}/reviews?per_page=100")
    latest_state = latest_review_state_by_user(reviews, login)
    if "review_requested" in reasons and latest_state == "APPROVED":
        reasons.remove("review_requested")

    mention_hits: list[dict[str, str]] = []
    if include_mentions or "mentioned_in_comment" in reasons:
        mention_hits = comment_mentions(client, key, login)
        if mention_hits:
            reasons.add("mentioned_in_comment")
        else:
            reasons.discard("mentioned_in_comment")

    requested_reviewers = [(u.get("login") or "") for u in pr.get("requested_reviewers", [])]
    requested_teams = [(t.get("slug") or "") for t in pr.get("requested_teams", [])]

    if not reasons:
        return None

    priority = priority_for(reasons, pr, mention_hits)
    return {
        "priority": priority,
        "reasons": sorted(reasons),
        "repo": key.repo_full_name,
        "number": key.number,
        "title": pr.get("title", ""),
        "url": pr.get("html_url", ""),
        "author": (pr.get("user") or {}).get("login", "unknown"),
        "is_draft": bool(pr.get("draft")),
        "created_at": pr.get("created_at", ""),
        "updated_at": pr.get("updated_at", ""),
        "base": (pr.get("base") or {}).get("ref", ""),
        "head": (pr.get("head") or {}).get("label", ""),
        "latest_my_review_state": latest_state,
        "requested_reviewers": [r for r in requested_reviewers if r],
        "requested_teams": [t for t in requested_teams if t],
        "mention_hits": mention_hits,
        "agent_summary": agent_summary(priority, reasons, pr, mention_hits, login),
    }


def priority_for(reasons: set[str], pr: dict[str, Any], mention_hits: list[dict[str, str]]) -> str:
    if "review_requested" in reasons and not pr.get("draft"):
        return "high"
    if mention_hits:
        return "high"
    if "authored_by_me" in reasons and not pr.get("draft"):
        return "medium"
    return "low"


def agent_summary(priority: str, reasons: set[str], pr: dict[str, Any], mention_hits: list[dict[str, str]], login: str) -> str:
    bits: list[str] = []
    if "review_requested" in reasons:
        bits.append(f"{login} is requested for review and has not approved it")
    if "mentioned_in_comment" in reasons:
        if mention_hits:
            bits.append(f"{login} was mentioned in a PR comment by {mention_hits[0]['author']}")
        else:
            bits.append(f"{login} was mentioned in a PR comment")
    if "authored_by_me" in reasons:
        bits.append(f"{login} authored this open PR")
    draft = "draft " if pr.get("draft") else ""
    return f"{priority.upper()}: {draft}PR needs attention because " + "; ".join(bits) + "."


def collect_attention(client: GitHubClient, *, include_comment_scan_for_all: bool = False, max_search_items: int | None = None) -> dict[str, Any]:
    user = client.get("/user")
    login = user["login"]
    candidates: dict[PullKey, set[str]] = {}

    searches = [
        (f"is:pr is:open author:{login} archived:false", "authored_by_me"),
        (f"is:pr is:open review-requested:{login} archived:false", "review_requested"),
        (f"is:pr is:open mentions:{login} archived:false", "mentioned_in_comment"),
    ]
    for query, reason in searches:
        for item in client.paged(search_path(query), limit=max_search_items):
            # GitHub issue search can return issues if query is malformed; keep PRs only.
            if "pull_request" not in item:
                continue
            key = pr_key_from_issue_url(item["url"])
            candidates.setdefault(key, set()).add(reason)

    items: list[dict[str, Any]] = []
    for key in sorted(candidates, key=lambda k: (k.owner.lower(), k.repo.lower(), k.number)):
        try:
            item = build_item(
                client,
                key,
                set(candidates[key]),
                login,
                include_mentions=include_comment_scan_for_all,
            )
        except GitHubError as exc:
            reasons = set(candidates[key])
            priority = "high" if {"review_requested", "mentioned_in_comment"} & reasons else "medium"
            item = {
                "priority": priority,
                "reasons": sorted(reasons),
                "repo": key.repo_full_name,
                "number": key.number,
                "title": "(unavailable: GitHub API detail request failed)",
                "url": f"https://github.com/{key.repo_full_name}/pull/{key.number}",
                "author": "unknown",
                "is_draft": None,
                "created_at": "",
                "updated_at": "",
                "base": "",
                "head": "",
                "latest_my_review_state": None,
                "requested_reviewers": [],
                "requested_teams": [],
                "mention_hits": [],
                "collection_error": str(exc),
                "agent_summary": f"{priority.upper()}: PR matched attention search but detail collection failed; inspect manually. Error: {short_text(str(exc))}",
            }
        if item:
            items.append(item)

    priority_order = {"high": 0, "medium": 1, "low": 2}
    items.sort(key=lambda i: (priority_order.get(i["priority"], 99), reverse_timestamp(i.get("updated_at", ""))))
    return {
        "schema_version": 1,
        "generated_at": iso_now(),
        "viewer": login,
        "attention_count": len(items),
        "items": items,
        "agent_instructions": [
            "Prioritize high items first, especially review requests and direct comment mentions.",
            "For authored PRs, summarize merge blockers, stale age, and CI/review state before recommending action.",
            "Use mention_hits snippets as the likely user-facing context when present.",
            "Do not approve, merge, close, or comment on PRs without explicit user instruction.",
        ],
    }


def render_markdown(report: dict[str, Any]) -> str:
    lines = [
        f"# GitHub PR attention report for @{report['viewer']}",
        "",
        f"Generated: {report['generated_at']}",
        f"Open PRs needing attention: {report['attention_count']}",
        "",
    ]
    if not report["items"]:
        lines.append("No open PRs found that match the attention criteria.")
        return "\n".join(lines)
    for idx, item in enumerate(report["items"], 1):
        lines.extend(
            [
                f"## {idx}. [{item['priority'].upper()}] {item['repo']}#{item['number']}: {item['title']}",
                "",
                f"- URL: {item['url']}",
                f"- Reasons: {', '.join(item['reasons'])}",
                f"- Author: @{item['author']}",
                f"- Draft: {item['is_draft']}",
                f"- Updated: {item['updated_at']}",
                f"- Agent summary: {item['agent_summary']}",
            ]
        )
        if item["mention_hits"]:
            lines.append("- Mentions:")
            for hit in item["mention_hits"]:
                lines.append(f"  - {hit['created_at']} @{hit['author']}: {hit['snippet']} ({hit['url']})")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--format", choices=("json", "markdown"), default="json", help="Output format. JSON is best for coding agents.")
    parser.add_argument("--api-root", default=os.environ.get("GITHUB_API_ROOT", API_ROOT), help="Override GitHub API root for testing.")
    parser.add_argument("--include-comment-scan-for-all", action="store_true", help="Scan comments on all candidate PRs, not just mention search hits.")
    parser.add_argument("--max-search-items", type=int, default=None, help="Debug/testing limit per search query.")
    args = parser.parse_args(argv)

    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        print("error: GITHUB_TOKEN environment variable is required", file=sys.stderr)
        return 2

    try:
        report = collect_attention(
            GitHubClient(token, args.api_root),
            include_comment_scan_for_all=args.include_comment_scan_for_all,
            max_search_items=args.max_search_items,
        )
    except GitHubError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    if args.format == "markdown":
        print(render_markdown(report))
    else:
        print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
