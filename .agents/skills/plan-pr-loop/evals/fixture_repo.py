#!/usr/bin/env python3
"""Create a disposable local Git repository for a plan-pr-loop forward eval."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


def run(*args: str, cwd: Path) -> None:
    subprocess.run(args, cwd=cwd, check=True, text=True, capture_output=True)


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True)
    parser.add_argument(
        "--scenario",
        choices=("normal-two-pr", "review-artifact-isolation", "feedback-and-resume"),
        default="normal-two-pr",
    )
    args = parser.parse_args()
    output = Path(args.output).expanduser().resolve()
    if output.exists():
        raise SystemExit(f"refusing to overwrite existing path: {output}")
    output.mkdir(parents=True)
    remote = output.parent / f"{output.name}-remote.git"
    if remote.exists():
        raise SystemExit(f"refusing to overwrite existing remote: {remote}")
    remote.mkdir()
    run("git", "init", "--bare", cwd=remote)
    run("git", "init", "-b", "main", cwd=output)
    run("git", "config", "user.name", "Plan PR Loop Eval", cwd=output)
    run("git", "config", "user.email", "eval@example.invalid", cwd=output)

    write(output / "README.md", "# Fixture repository\n")
    write(output / "src" / "counter.txt", "0\n")
    plan = output / ".agents" / "plans" / "example-plan"
    confirmed_at = "2026-08-23T00:00:00Z"
    context_values = ("false", "false", "not-applicable", confirmed_at)
    confirmation_digest = hashlib.sha256(
        b"implementation-plan-application-context-v1\0"
        + b"\0".join(value.encode("utf-8") for value in context_values)
    ).hexdigest()
    application_context = json.dumps(
        {
            "application_context": {
                "has_active_users": False,
                "backward_compatibility_required": False,
                "feature_flags": "not-applicable",
                "confirmation_digest": confirmation_digest,
                "confirmed_at": confirmed_at,
            }
        },
        indent=2,
    )
    write(
        plan / "00-overview.md",
        f"""# Fixture Plan\n\n**Status: Ready.**\n\n## Application context\n\n```json\n{application_context}\n```\n\n## Document map\n\n| File | Purpose |\n|---|---|\n| `00-overview.md` | Outcome. |\n| `01-first-change.md` | First change. |\n| `02-second-change.md` | Second change. |\n| `03-execution-handoff.md` | Order. |\n""",
    )
    write(
        plan / "01-first-change.md",
        "# First change\n\nSet `src/counter.txt` to `1`. Verify the exact file content.\n",
    )
    write(
        plan / "02-second-change.md",
        "# Second change\n\nAfter the first PR merges, set `src/counter.txt` to `2`. Verify the exact file content.\n",
    )
    write(
        plan / "03-execution-handoff.md",
        "# Execution handoff\n\n1. First change.\n2. Second change after the first PR merges.\n",
    )
    run("git", "add", "README.md", "src/counter.txt", ".agents/plans/example-plan", cwd=output)
    run("git", "commit", "-m", "Create eval fixture", cwd=output)
    run("git", "remote", "add", "origin", str(remote), cwd=output)
    run("git", "push", "-u", "origin", "main", cwd=output)

    if args.scenario == "review-artifact-isolation":
        write(output / "reviews" / "zz-old-review" / "sentinel.txt", "preserve me\n")

    result = {
        "repository": str(output),
        "remote": str(remote),
        "plan": str(plan),
        "scenario": args.scenario,
    }
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
