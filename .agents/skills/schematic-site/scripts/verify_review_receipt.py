#!/usr/bin/env python3
"""Verify that all required independent reviews cover one payload digest."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


DIGEST = re.compile(r"^[0-9a-f]{64}$")
SINGLE_STAGES = ("adversarial", "accuracy", "correctness")


def complete_reviewer(item: object, label: str, errors: list[str]) -> str | None:
    if not isinstance(item, dict):
        errors.append(f"{label} must be an object")
        return None
    reviewer = item.get("reviewer")
    if not isinstance(reviewer, str) or not reviewer.strip():
        errors.append(f"{label}.reviewer must be a non-empty string")
        return None
    if item.get("status") != "complete":
        errors.append(f"{label}.status must be 'complete'")
    return reviewer.strip()


def verify(receipt: object, expected_digest: str) -> list[str]:
    errors: list[str] = []
    if not isinstance(receipt, dict):
        return ["receipt root must be an object"]
    if receipt.get("schema_version") != "schematic-site-review-v1":
        errors.append("unsupported or missing schema_version")
    digest = receipt.get("payload_sha256")
    if not isinstance(digest, str) or not DIGEST.fullmatch(digest):
        errors.append("payload_sha256 must be 64 lowercase hex characters")
    elif digest != expected_digest:
        errors.append("receipt payload_sha256 does not match the immutable snapshot")

    reviews = receipt.get("reviews")
    if not isinstance(reviews, dict):
        errors.append("reviews must be an object")
        return errors

    reviewers: list[str] = []
    independent = reviews.get("independent")
    if not isinstance(independent, list) or len(independent) != 2:
        errors.append("reviews.independent must contain exactly two reviews")
    else:
        for index, item in enumerate(independent, 1):
            reviewer = complete_reviewer(item, f"independent[{index}]", errors)
            if reviewer:
                reviewers.append(reviewer)

    for stage in SINGLE_STAGES:
        reviewer = complete_reviewer(reviews.get(stage), stage, errors)
        if reviewer:
            reviewers.append(reviewer)

    normalized = [item.casefold() for item in reviewers]
    if len(normalized) != len(set(normalized)):
        errors.append("all five review slots must use distinct reviewer identifiers")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("receipt", type=Path)
    parser.add_argument("expected_digest")
    args = parser.parse_args()
    if not DIGEST.fullmatch(args.expected_digest):
        print("ERROR: expected digest is not lowercase SHA-256", file=sys.stderr)
        return 2
    try:
        receipt = json.loads(args.receipt.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        print(f"ERROR: cannot read review receipt: {exc}", file=sys.stderr)
        return 2
    errors = verify(receipt, args.expected_digest)
    for error in errors:
        print(f"ERROR: {error}")
    if errors:
        return 1
    print(f"PASS: review receipt covers {args.expected_digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
