#!/usr/bin/env python3
"""Assert required and forbidden command fragments in a fake-gh JSONL trace."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def contains_sequence(argv: list[str], expected: list[str]) -> bool:
    if not expected:
        return True
    width = len(expected)
    if any(argv[index : index + width] == expected for index in range(len(argv) - width + 1)):
        return True
    for argument in argv:
        parts = [part for part in argument.split("/") if part]
        if any(parts[index : index + width] == expected for index in range(len(parts) - width + 1)):
            return True
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--trace", required=True)
    parser.add_argument("--expect", required=True)
    args = parser.parse_args()
    trace_path = Path(args.trace).expanduser().resolve()
    expect_path = Path(args.expect).expanduser().resolve()
    records = [json.loads(line) for line in trace_path.read_text(encoding="utf-8").splitlines() if line]
    contract: dict[str, Any] = json.loads(expect_path.read_text(encoding="utf-8"))
    argvs = [record.get("argv", []) for record in records]

    failures: list[str] = []
    for sequence in contract.get("required_argv_sequences", []):
        if not any(contains_sequence(argv, sequence) for argv in argvs):
            failures.append(f"missing required argv sequence: {sequence}")
    for sequence in contract.get("forbidden_argv_sequences", []):
        if any(contains_sequence(argv, sequence) for argv in argvs):
            failures.append(f"observed forbidden argv sequence: {sequence}")
    for operation in contract.get("max_occurrences", []):
        sequence = operation["sequence"]
        count = sum(contains_sequence(argv, sequence) for argv in argvs)
        if count > operation["max"]:
            failures.append(f"sequence {sequence} occurred {count} times; max is {operation['max']}")
    for operation in contract.get("exact_occurrences", []):
        sequence = operation["sequence"]
        count = sum(contains_sequence(argv, sequence) for argv in argvs)
        if count != operation["count"]:
            failures.append(f"sequence {sequence} occurred {count} times; expected exactly {operation['count']}")
    for operation in contract.get("exact_records", []):
        sequences = operation["sequences"]
        count = sum(all(contains_sequence(argv, sequence) for sequence in sequences) for argv in argvs)
        if count != operation["count"]:
            failures.append(
                f"record sequences {sequences} occurred together {count} times; expected exactly {operation['count']}"
            )

    print(json.dumps({"ok": not failures, "records": len(records), "failures": failures}, sort_keys=True))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
