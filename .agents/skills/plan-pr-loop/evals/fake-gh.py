#!/usr/bin/env python3
"""State-backed fake `gh` for plan-pr-loop forward evaluations."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def fail(message: str, code: int = 1) -> int:
    sys.stderr.write(f"fake-gh: {message}\n")
    return code


def state_path() -> Path:
    value = os.environ.get("PLAN_PR_LOOP_FAKE_GH_STATE")
    if not value:
        raise RuntimeError("PLAN_PR_LOOP_FAKE_GH_STATE is required")
    return Path(value).expanduser().resolve()


def read_state(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise RuntimeError("fake state must be a JSON object")
    value.setdefault("next_pr_number", 1)
    value.setdefault("next_comment_id", 1000)
    value.setdefault("prs", [])
    value.setdefault("viewerPermission", "WRITE")
    return value


def write_state(path: Path, state: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as handle:
        name = handle.name
        json.dump(state, handle, sort_keys=True, indent=2)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(name, path)


def trace(argv: list[str], result: str, detail: Any = None) -> None:
    value = os.environ.get("PLAN_PR_LOOP_FAKE_GH_TRACE")
    if not value:
        return
    record = {
        "argv": argv,
        "result": result,
        "detail": detail,
        "at": datetime.now(timezone.utc).isoformat(),
    }
    path = Path(value).expanduser().resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, sort_keys=True) + "\n")


def option(argv: list[str], name: str) -> str | None:
    if name in argv:
        index = argv.index(name)
        if index + 1 < len(argv):
            return argv[index + 1]
    prefix = f"{name}="
    for value in argv:
        if value.startswith(prefix):
            return value[len(prefix) :]
    return None


def api_fields(argv: list[str]) -> dict[str, list[str]]:
    fields: dict[str, list[str]] = {}
    for index, value in enumerate(argv):
        if value not in {"-f", "--raw-field", "-F", "--field"} or index + 1 >= len(argv):
            continue
        raw = argv[index + 1]
        if "=" not in raw:
            continue
        key, field_value = raw.split("=", 1)
        fields.setdefault(key.removesuffix("[]"), []).append(field_value)
    return fields


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def git_oid(ref: str, fallback: str) -> str:
    result = subprocess.run(
        ["git", "rev-parse", ref],
        text=True,
        capture_output=True,
        check=False,
    )
    return result.stdout.strip() if result.returncode == 0 else fallback


def find_pr(state: dict[str, Any], selector: str | None = None) -> dict[str, Any] | None:
    prs = state["prs"]
    if selector and selector.isdigit():
        return next((item for item in prs if item.get("number") == int(selector)), None)
    if selector:
        return next((item for item in prs if item.get("headRefName") == selector), None)
    return prs[-1] if prs else None


def pr_json(pr: dict[str, Any]) -> dict[str, Any]:
    defaults = {
        "state": "OPEN",
        "isDraft": False,
        "mergedAt": None,
        "mergeable": "MERGEABLE",
        "mergeStateStatus": "CLEAN",
        "reviewDecision": "",
        "reviewRequests": [],
        "statusCheckRollup": [],
        "comments": [],
        "reviews": [],
        "review_comments": [],
        "timeline": [],
    }
    return {**defaults, **pr}


def handle_pr(argv: list[str], state: dict[str, Any]) -> tuple[int, bool, Any]:
    if len(argv) < 2:
        return fail("pr subcommand required"), False, None
    command = argv[1]
    if command == "view":
        selector = argv[2] if len(argv) > 2 and not argv[2].startswith("-") else None
        pr = find_pr(state, selector)
        if pr is None:
            return fail("pull request not found"), False, None
        value = pr_json(pr)
        sys.stdout.write(json.dumps(value, sort_keys=True) + "\n")
        return 0, False, value.get("number")

    if command == "create":
        base = option(argv, "--base")
        head = option(argv, "--head")
        title = option(argv, "--title")
        body = option(argv, "--body")
        body_file = option(argv, "--body-file")
        if body_file:
            body = Path(body_file).read_text(encoding="utf-8")
        if not base or not head or not title:
            return fail("pr create requires --base, --head, and --title"), False, None
        existing = next(
            (
                item
                for item in state["prs"]
                if item.get("baseRefName") == base and item.get("headRefName") == head
            ),
            None,
        )
        if existing:
            return fail("matching pull request already exists"), False, existing.get("number")
        number = state["next_pr_number"]
        state["next_pr_number"] += 1
        repo_url = state.get("repositoryUrl", "https://example.invalid/owner/repo")
        pr = pr_json(
            {
                "number": number,
                "url": f"{repo_url}/pull/{number}",
                "title": title,
                "body": body or "",
                "baseRefName": base,
                "baseRefOid": git_oid(base, state.get("baseRefOid", "base-oid-1")),
                "headRefName": head,
                "headRefOid": git_oid(head, state.get("headRefOid", "head-oid-1")),
            }
        )
        state["prs"].append(pr)
        sys.stdout.write(pr["url"] + "\n")
        return 0, True, number

    if command == "comment":
        selector = argv[2] if len(argv) > 2 else None
        pr = find_pr(state, selector)
        if pr is None:
            return fail("pull request not found"), False, None
        body = option(argv, "--body")
        body_file = option(argv, "--body-file")
        if body_file:
            body = Path(body_file).read_text(encoding="utf-8")
        if body is None:
            return fail("pr comment requires --body or --body-file"), False, None
        comment_id = state["next_comment_id"]
        state["next_comment_id"] += 1
        comment = {
            "id": comment_id,
            "user": {"login": state.get("authenticatedLogin", "fixture-user")},
            "body": body,
            "created_at": now(),
            "updated_at": now(),
            "html_url": f"{pr['url']}#issuecomment-{comment_id}",
        }
        pr.setdefault("comments", []).append(comment)
        sys.stdout.write(comment["html_url"] + "\n")
        return 0, True, comment_id

    if command == "edit":
        selector = argv[2] if len(argv) > 2 else None
        pr = find_pr(state, selector)
        if pr is None:
            return fail("pull request not found"), False, None
        reviewer = option(argv, "--add-reviewer")
        if reviewer and reviewer not in pr.setdefault("reviewRequests", []):
            pr["reviewRequests"].append(reviewer)
            pr.setdefault("timeline", []).append(
                {"event": "review_requested", "reviewer": reviewer, "created_at": now()}
            )
        return 0, bool(reviewer), reviewer

    if command == "checks":
        selector = argv[2] if len(argv) > 2 else None
        pr = find_pr(state, selector)
        if pr is None:
            return fail("pull request not found"), False, None
        sys.stdout.write(json.dumps(pr.get("statusCheckRollup", []), sort_keys=True) + "\n")
        return 0, False, pr.get("number")

    return fail(f"unsupported pr command: {command}"), False, None


def handle_api(argv: list[str], state: dict[str, Any]) -> tuple[int, bool, Any]:
    path = next((value for value in argv[1:] if value.startswith("/repos/") or value.startswith("repos/")), None)
    if not path:
        return fail("api path required"), False, None
    segments = path.strip("/").split("/")
    try:
        resource = "pulls" if "pulls" in segments else "issues"
        resource_index = segments.index(resource)
        number = int(segments[resource_index + 1])
    except (ValueError, IndexError):
        return fail(f"unsupported api path: {path}"), False, None
    pr = find_pr(state, str(number))
    if pr is None:
        return fail("pull request not found"), False, None
    method = (option(argv, "--method") or option(argv, "-X") or "GET").upper()
    if method not in {"GET", "POST"}:
        return fail(f"unsupported api method: {method}"), False, None
    fields = api_fields(argv)
    if method == "POST":
        comment_id = state["next_comment_id"]
        state["next_comment_id"] += 1
        if path.endswith(f"issues/{number}/comments"):
            value = {
                "id": comment_id,
                "body": (fields.get("body") or [""])[0],
                "created_at": now(),
                "updated_at": now(),
                "html_url": f"https://github.example.invalid/pr/{number}#issuecomment-{comment_id}",
            }
            pr.setdefault("comments", []).append(value)
        elif "/comments/" in path and path.endswith("/replies") and "pulls" in segments:
            try:
                comment_index = segments.index("comments")
                parent_id = int(segments[comment_index + 1])
            except (ValueError, IndexError):
                return fail(f"unsupported reply path: {path}"), False, None
            value = {
                "id": comment_id,
                "in_reply_to_id": parent_id,
                "body": (fields.get("body") or [""])[0],
                "created_at": now(),
                "updated_at": now(),
                "html_url": f"https://github.example.invalid/pr/{number}#discussion_r{comment_id}",
            }
            pr.setdefault("review_comments", []).append(value)
        elif path.endswith(f"pulls/{number}/requested_reviewers"):
            requested = fields.get("reviewers", []) + fields.get("team_reviewers", [])
            for reviewer in requested:
                if reviewer not in pr.setdefault("reviewRequests", []):
                    pr["reviewRequests"].append(reviewer)
                    pr.setdefault("timeline", []).append(
                        {"event": "review_requested", "reviewer": reviewer, "created_at": now()}
                    )
            value = {"requested_reviewers": requested}
        else:
            return fail(f"unsupported POST api path: {path}"), False, None
        sys.stdout.write(json.dumps(value, sort_keys=True) + "\n")
        return 0, True, value
    if path.endswith(f"issues/{number}/comments"):
        value = pr.get("comments", [])
    elif path.endswith(f"pulls/{number}/reviews"):
        value = pr.get("reviews", [])
    elif path.endswith(f"pulls/{number}/comments"):
        value = pr.get("review_comments", [])
    elif path.endswith(f"issues/{number}/timeline"):
        value = pr.get("timeline", [])
    elif path.endswith(f"pulls/{number}/requested_reviewers"):
        value = {"users": [{"login": item} for item in pr.get("reviewRequests", [])], "teams": []}
    else:
        return fail(f"unsupported api path: {path}"), False, None
    sys.stdout.write(json.dumps(value, sort_keys=True) + "\n")
    return 0, False, path


def main() -> int:
    argv = sys.argv[1:]
    try:
        path = state_path()
        state = read_state(path)
        code: int
        changed: bool
        detail: Any
        if argv[:2] == ["auth", "status"]:
            sys.stdout.write("Logged in to github.com\nToken scopes: 'repo', 'workflow'\n")
            code, changed, detail = 0, False, "authenticated"
        elif argv[:2] == ["repo", "view"]:
            value = {"viewerPermission": state["viewerPermission"]}
            if "-q" in argv or "--jq" in argv:
                sys.stdout.write(state["viewerPermission"] + "\n")
            else:
                sys.stdout.write(json.dumps(value) + "\n")
            code, changed, detail = 0, False, value
        elif argv and argv[0] == "pr":
            code, changed, detail = handle_pr(argv, state)
        elif argv and argv[0] == "api":
            code, changed, detail = handle_api(argv, state)
        else:
            code, changed, detail = fail(f"unsupported command: {' '.join(argv)}", 64), False, None
        if changed:
            write_state(path, state)
        trace(argv, "ok" if code == 0 else "error", detail)
        return code
    except (OSError, ValueError, json.JSONDecodeError, RuntimeError) as exc:
        trace(argv, "error", str(exc))
        return fail(str(exc), 5)


if __name__ == "__main__":
    raise SystemExit(main())
