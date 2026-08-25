#!/usr/bin/env python3
"""Deterministic state, lock, lease, and outbox helper for plan-pr-loop."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from datetime import datetime, timezone
from typing import Any, cast


SCHEMA_VERSION = "plan-pr-loop-v1"
PHASES = {
    "preflight",
    "queued",
    "implementing",
    "internal-review",
    "publishing",
    "awaiting-human-review",
    "addressing-feedback",
    "awaiting-merge",
    "complete",
    "human-required",
    "recovery-required",
}
TRANSITIONS = {
    "preflight": {"queued"},
    "queued": {"implementing", "complete"},
    "implementing": {"internal-review", "queued"},
    "internal-review": {"publishing", "implementing"},
    "publishing": {"awaiting-human-review"},
    "awaiting-human-review": {"addressing-feedback", "awaiting-merge"},
    "addressing-feedback": {"awaiting-human-review", "awaiting-merge"},
    "awaiting-merge": {"addressing-feedback", "queued", "complete"},
    "complete": set(),
    "human-required": PHASES - {"complete", "human-required"},
    "recovery-required": PHASES - {"complete", "recovery-required"},
}
STOP_PHASES = {"human-required", "recovery-required"}
FEEDBACK_STREAMS = {"issue_comments", "reviews", "review_comments"}
REQUIREMENT_STATUSES = {"in-scope", "deferred-approved"}
COVERAGE_STATUSES = {"planned", "merged", "satisfied-by-base", "deferred-approved"}
QUEUE_STATUSES = {
    "queued",
    "implementing",
    "internal-review",
    "publishing",
    "awaiting-human-review",
    "addressing-feedback",
    "awaiting-merge",
    "merged",
    "satisfied-by-base",
    "superseded",
}
TERMINAL_QUEUE_STATUSES = {"merged", "satisfied-by-base", "superseded"}
ACTIVE_QUEUE_STATUSES = QUEUE_STATUSES - TERMINAL_QUEUE_STATUSES - {"queued"}
QUEUE_STATUS_TRANSITIONS = {
    "queued": {"implementing", "satisfied-by-base", "superseded"},
    "implementing": {"internal-review", "queued"},
    "internal-review": {"publishing", "implementing"},
    "publishing": {"awaiting-human-review"},
    "awaiting-human-review": {"addressing-feedback", "awaiting-merge"},
    "addressing-feedback": {"awaiting-human-review", "awaiting-merge"},
    "awaiting-merge": {"addressing-feedback", "merged"},
    "merged": set(),
    "satisfied-by-base": set(),
    "superseded": set(),
}
REVIEW_ISOLATION_TRANSITIONS = {
    "none": {"backup-intent", "reviewing"},
    "backup-intent": {"backed-up"},
    "backed-up": {"reviewing", "restore-intent"},
    "reviewing": {"archive-intent", "restore-intent"},
    "archive-intent": {"archived"},
    "archived": {"restore-intent", "restored"},
    "restore-intent": {"restored"},
    "restored": {"none", "backup-intent", "reviewing"},
}
FEEDBACK_PROCESSING_TRANSITIONS = {
    "seen": {"seen", "in-progress", "replied", "disposed"},
    "in-progress": {"in-progress", "code-pushed"},
    "code-pushed": {"code-pushed", "replied"},
    "replied": {"replied", "disposed"},
    "disposed": {"disposed"},
}
FEEDBACK_CLASSES = {"code-change", "question", "non-actionable"}
OUTBOX_REQUIRED_BY_KIND = {
    "pr-create": {"base_ref", "head_ref", "expected_head_sha", "expected_base_oid", "marker", "input_digest"},
    "comment-reply": {"pr_number", "target", "feedback_identity_digest", "marker", "input_digest"},
    "review-request": {
        "pr_number",
        "target",
        "expected_head_sha",
        "expected_base_oid",
        "input_digest",
    },
}
FORBIDDEN_STATE_KEYS = {
    "body",
    "comment_body",
    "diff",
    "full_diff",
    "token",
    "secret",
    "password",
    "credential",
    "credentials",
    "api_key",
    "apikey",
}


class HelperError(Exception):
    def __init__(self, message: str, code: int) -> None:
        super().__init__(message)
        self.code = code


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def require(condition: object, message: str, code: int = 2) -> None:
    if not condition:
        raise HelperError(message, code)


def reject_sensitive_keys(value: Any, path: str = "state") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            require(
                key.lower() not in FORBIDDEN_STATE_KEYS,
                f"forbidden durable key at {path}.{key}",
            )
            reject_sensitive_keys(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            reject_sensitive_keys(child, f"{path}[{index}]")


def validate_reason(reason: Any, label: str = "reason") -> str:
    require(isinstance(reason, str) and reason, f"{label} required")
    reason = cast(str, reason)
    require("\n" not in reason and "\r" not in reason, f"{label} must be one line")
    require(len(reason) <= 512, f"{label} is too long")
    return reason


def digest_json(value: Any) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def feedback_identity_digest(stream: str, record: dict[str, Any]) -> str:
    identity_keys = (
        ("id", "body_digest", "classification", "submitted_at", "state")
        if stream == "reviews"
        else ("id", "body_digest", "classification", "updated_at")
    )
    identity_keys = (*identity_keys, "repository_id", "entry_id", "pr_number")
    return digest_json(
        {
            "domain": "plan-pr-loop-feedback-identity-v1",
            "stream": stream,
            "identity": {key: record.get(key) for key in identity_keys},
        }
    )


def queue_contract_digest(entry: dict[str, Any], requirements: dict[str, dict[str, Any]]) -> str:
    dynamic = {"revision", "sequence", "status", "split_into", "terminal_evidence", "contract_digest"}
    contract = {key: value for key, value in entry.items() if key not in dynamic}
    contract["requirement_content_digests"] = [
        requirements[requirement_id]["content_digest"] for requirement_id in entry.get("requirement_ids", [])
    ]
    return digest_json({"domain": "plan-pr-loop-contract-v1", "contract": contract})


def with_contract_digests(
    queue: Any,
    requirements: list[dict[str, Any]],
    application_context: dict[str, Any] | None = None,
    *,
    allow_stale: bool = False,
) -> list[dict[str, Any]]:
    require(isinstance(queue, list), "queue must be a list")
    by_requirement = {item["requirement_id"]: item for item in requirements}
    result: list[dict[str, Any]] = []
    for raw_entry in cast(list[Any], queue):
        require(isinstance(raw_entry, dict), "each queue entry must be an object")
        entry = dict(cast(dict[str, Any], raw_entry))
        supplied = entry.pop("contract_digest", None)
        if application_context is not None:
            entry.setdefault("application_context_digest", digest_json(application_context))
            if "compatibility" not in entry and not application_context["has_active_users"] and not application_context["backward_compatibility_required"]:
                entry["compatibility"] = {
                    "behavior_change": False,
                    "backward_compatible": True,
                    "feature_flag_decision": "not-required",
                    "decision_evidence_digest": None,
                }
        requirement_ids = entry.get("requirement_ids", [])
        if isinstance(requirement_ids, list) and all(item in by_requirement for item in requirement_ids):
            computed = queue_contract_digest(entry, by_requirement)
            require(allow_stale or supplied in {None, computed}, f"queue contract_digest mismatch: {entry.get('entry_id')}", 3)
            entry["contract_digest"] = computed
        result.append(entry)
    return result


def validate_requirements(requirements: Any) -> set[str]:
    require(isinstance(requirements, list), "requirements must be a list")
    requirement_items = cast(list[Any], requirements)
    by_id: dict[str, dict[str, Any]] = {}
    for index, raw_requirement in enumerate(requirement_items):
        require(isinstance(raw_requirement, dict), f"requirements[{index}] must be an object")
        requirement = cast(dict[str, Any], raw_requirement)
        requirement_id = requirement.get("requirement_id")
        require(isinstance(requirement_id, str) and requirement_id, f"requirements[{index}].requirement_id required")
        requirement_id = cast(str, requirement_id)
        require(requirement_id not in by_id, f"duplicate requirement_id: {requirement_id}")
        source = requirement.get("source")
        require(isinstance(source, dict), f"requirements[{index}].source must be an object")
        source = cast(dict[str, Any], source)
        require(isinstance(source.get("file"), str) and source["file"], f"requirements[{index}].source.file required")
        heading_path = source.get("heading_path")
        require(isinstance(heading_path, list), f"requirements[{index}].source.heading_path must be a list")
        heading_path = cast(list[Any], heading_path)
        require(all(isinstance(item, str) and item for item in heading_path), f"requirements[{index}] invalid heading_path")
        require(isinstance(source.get("ordinal"), int) and source["ordinal"] >= 1, f"requirements[{index}].source.ordinal must be positive")
        require(isinstance(requirement.get("content_digest"), str) and requirement["content_digest"], f"requirements[{index}].content_digest required")
        require(isinstance(requirement.get("behavior"), str) and requirement["behavior"], f"requirements[{index}].behavior required")
        acceptance = requirement.get("acceptance")
        require(isinstance(acceptance, list) and acceptance, f"requirements[{index}].acceptance must be nonempty")
        acceptance = cast(list[Any], acceptance)
        require(all(isinstance(item, str) and item for item in acceptance), f"requirements[{index}] invalid acceptance")
        dependencies = requirement.get("dependencies", [])
        require(isinstance(dependencies, list), f"requirements[{index}].dependencies must be a list")
        require(all(isinstance(item, str) and item for item in dependencies), f"requirements[{index}] invalid dependencies")
        for list_key in ("proposed_locations", "verification"):
            items = requirement.get(list_key)
            require(isinstance(items, list), f"requirements[{index}].{list_key} must be a list")
            items = cast(list[Any], items)
            require(all(isinstance(item, str) and item for item in items), f"requirements[{index}] invalid {list_key}")
        require(requirement.get("verification"), f"requirements[{index}].verification must be nonempty")
        require(isinstance(requirement.get("risk"), str) and requirement["risk"], f"requirements[{index}].risk required")
        require(
            requirement.get("classification") in {"reviewer-written", "generated", "mechanical", "vendor", "mixed"},
            f"requirements[{index}] invalid classification",
        )
        require("remaining_decision" in requirement, f"requirements[{index}].remaining_decision required")
        require(
            requirement["remaining_decision"] is None
            or (isinstance(requirement["remaining_decision"], str) and requirement["remaining_decision"]),
            f"requirements[{index}] invalid remaining_decision",
        )
        require(requirement.get("status", "in-scope") in REQUIREMENT_STATUSES, f"requirements[{index}] invalid status")
        by_id[requirement_id] = requirement

    for requirement_id, requirement in by_id.items():
        for dependency in requirement.get("dependencies", []):
            require(dependency in by_id, f"requirement {requirement_id} depends on unknown requirement: {dependency}")
            require(dependency != requirement_id, f"requirement {requirement_id} cannot depend on itself")

    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(requirement_id: str) -> None:
        require(requirement_id not in visiting, f"requirement dependency cycle at: {requirement_id}")
        if requirement_id in visited:
            return
        visiting.add(requirement_id)
        for dependency in by_id[requirement_id].get("dependencies", []):
            visit(dependency)
        visiting.remove(requirement_id)
        visited.add(requirement_id)

    for requirement_id in by_id:
        visit(requirement_id)
    return set(by_id)


def validate_queue(queue: Any, requirement_ids_available: set[str]) -> set[str]:
    require(isinstance(queue, list), "queue must be a list")
    queue_items = cast(list[Any], queue)
    seen: set[str] = set()
    active_sequences: set[int] = set()
    for index, entry_value in enumerate(queue_items):
        entry = cast(dict[str, Any], entry_value)
        require(isinstance(entry, dict), f"queue[{index}] must be an object")
        entry_id = entry.get("entry_id")
        require(isinstance(entry_id, str) and entry_id, f"queue[{index}].entry_id required")
        entry_id = cast(str, entry_id)
        require(entry_id not in seen, f"duplicate queue entry_id: {entry_id}")
        seen.add(entry_id)
        workflow_kind = entry.get("workflow_kind")
        require(
            workflow_kind in {None, "devex-retrospective"},
            f"queue[{index}] invalid workflow_kind",
        )
        require(
            isinstance(entry.get("revision"), int) and entry["revision"] >= 1,
            f"queue[{index}].revision must be positive",
        )
        for lineage_key in ("supersedes", "split_into"):
            lineage = entry.get(lineage_key, [])
            require(isinstance(lineage, list), f"queue[{index}].{lineage_key} must be a list")
            require(all(isinstance(item, str) and item for item in lineage), f"invalid {lineage_key}")
        entry_requirement_ids = entry.get("requirement_ids", [])
        require(isinstance(entry_requirement_ids, list), f"queue[{index}].requirement_ids must be a list")
        require(entry_requirement_ids, f"queue[{index}].requirement_ids must be nonempty")
        require(all(isinstance(item, str) and item for item in entry_requirement_ids), f"queue[{index}] invalid requirement_ids")
        require(set(entry_requirement_ids).issubset(requirement_ids_available), f"queue[{index}] references unknown requirement_id")
        require(entry.get("status", "queued") in QUEUE_STATUSES, f"queue[{index}] invalid status")
        require(isinstance(entry.get("sequence"), int) and entry["sequence"] >= 0, f"queue[{index}].sequence must be nonnegative")
        if entry.get("status") != "superseded":
            require(entry["sequence"] >= 1, f"active queue[{index}].sequence must be positive")
            require(entry["sequence"] not in active_sequences, f"duplicate active queue sequence: {entry['sequence']}")
            active_sequences.add(entry["sequence"])
        require(isinstance(entry.get("contract_digest"), str) and entry["contract_digest"], f"queue[{index}].contract_digest required")
        for text_key in ("slug", "title", "purpose"):
            require(
                isinstance(entry.get(text_key), str) and entry[text_key],
                f"queue[{index}].{text_key} required",
            )
        for list_key in ("included_paths", "excluded_work", "acceptance", "validation"):
            values = entry.get(list_key)
            require(isinstance(values, list), f"queue[{index}].{list_key} must be a list")
            values = cast(list[Any], values)
            require(
                all(isinstance(value, str) and value for value in values),
                f"queue[{index}] invalid {list_key}",
            )
        require(entry["included_paths"], f"queue[{index}].included_paths must be nonempty")
        require(entry["acceptance"], f"queue[{index}].acceptance must be nonempty")
        require(entry["validation"], f"queue[{index}].validation must be nonempty")
        review_shape = entry.get("estimated_review_shape")
        require(isinstance(review_shape, dict), f"queue[{index}].estimated_review_shape must be an object")
        review_shape = cast(dict[str, Any], review_shape)
        for shape_key in ("human_written_lines", "generated_lines", "files"):
            require(review_shape.get(shape_key) is not None, f"queue[{index}].estimated_review_shape.{shape_key} required")
        require(isinstance(entry.get("exception_required"), bool), f"queue[{index}].exception_required must be boolean")
        if entry["exception_required"]:
            require(
                isinstance(entry.get("exception_reason"), str) and entry["exception_reason"],
                f"queue[{index}].exception_reason required",
            )
        else:
            require(entry.get("exception_reason") is None, f"queue[{index}].exception_reason must be null")
        if entry.get("status") == "superseded":
            require(entry.get("split_into"), f"superseded queue entry requires split_into: {entry_id}")
        terminal_evidence = entry.get("terminal_evidence")
        if entry.get("status") == "merged":
            require(isinstance(terminal_evidence, dict), f"merged queue entry requires terminal_evidence: {entry_id}")
            terminal_evidence = cast(dict[str, Any], terminal_evidence)
            require(isinstance(terminal_evidence.get("pr_number"), int) and terminal_evidence["pr_number"] >= 1, "merged evidence pr_number required")
            for evidence_key in ("merge_sha", "base_sha", "verification_digest"):
                require(isinstance(terminal_evidence.get(evidence_key), str) and terminal_evidence[evidence_key], f"merged evidence {evidence_key} required")
            exception_id = terminal_evidence.get("review_exception_approval_id")
            if exception_id is not None:
                require(isinstance(exception_id, str) and exception_id, "merged review exception approval ID must be nonempty")
                require(
                    isinstance(terminal_evidence.get("human_disposition_digest"), str)
                    and terminal_evidence["human_disposition_digest"],
                    "merged review exception requires human disposition evidence",
                )
                require(
                    isinstance(terminal_evidence.get("feedback_identity_digest"), str)
                    and terminal_evidence["feedback_identity_digest"],
                    "merged review exception requires feedback identity evidence",
                )
        elif entry.get("status") == "satisfied-by-base":
            require(isinstance(terminal_evidence, dict), f"satisfied queue entry requires terminal_evidence: {entry_id}")
            terminal_evidence = cast(dict[str, Any], terminal_evidence)
            require(isinstance(terminal_evidence.get("verification_digest"), str) and terminal_evidence["verification_digest"], "satisfied evidence required")
        if workflow_kind == "devex-retrospective" and entry.get("status") in {"merged", "satisfied-by-base"}:
            terminal_evidence = cast(dict[str, Any], terminal_evidence)
            expected_outcome = "changes-merged" if entry.get("status") == "merged" else "no-change"
            require(
                terminal_evidence.get("outcome") == expected_outcome,
                f"DevEx retrospective terminal outcome must be {expected_outcome}: {entry_id}",
            )
            require(
                isinstance(terminal_evidence.get("retrospective_artifact"), str)
                and terminal_evidence["retrospective_artifact"],
                f"DevEx retrospective artifact required: {entry_id}",
            )
            require(
                isinstance(terminal_evidence.get("retrospective_artifact_digest"), str)
                and terminal_evidence["retrospective_artifact_digest"],
                f"DevEx retrospective artifact digest required: {entry_id}",
            )
        prerequisites = entry.get("prerequisites", [])
        require(isinstance(prerequisites, list), f"queue[{index}].prerequisites must be a list")
        require(all(isinstance(item, str) and item for item in prerequisites), f"queue[{index}] invalid prerequisites")
    for entry_value in queue_items:
        entry = cast(dict[str, Any], entry_value)
        for lineage_key in ("supersedes", "split_into"):
            for referenced_id in entry.get(lineage_key, []):
                require(referenced_id in seen, f"queue lineage references unknown entry_id: {referenced_id}")
        for prerequisite in entry.get("prerequisites", []):
            require(prerequisite in seen, f"queue prerequisite references unknown entry_id: {prerequisite}")
            require(prerequisite != entry["entry_id"], f"queue entry cannot depend on itself: {prerequisite}")
            if entry.get("status") in ACTIVE_QUEUE_STATUSES | {"merged", "satisfied-by-base"}:
                require(
                    next(
                        (candidate.get("status", "queued") for candidate in queue_items if isinstance(candidate, dict) and candidate.get("entry_id") == prerequisite),
                        None,
                    )
                    in {"merged", "satisfied-by-base"},
                    f"queue prerequisite is not complete: {prerequisite}",
                )

    by_id = {entry["entry_id"]: entry for entry in cast(list[dict[str, Any]], queue_items)}
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(entry_id: str) -> None:
        require(entry_id not in visiting, f"queue dependency cycle at: {entry_id}")
        if entry_id in visited:
            return
        visiting.add(entry_id)
        for prerequisite in by_id[entry_id].get("prerequisites", []):
            visit(prerequisite)
        visiting.remove(entry_id)
        visited.add(entry_id)

    for entry_id in by_id:
        visit(entry_id)
    active_entries = [entry for entry in by_id.values() if entry.get("status", "queued") in ACTIVE_QUEUE_STATUSES]
    require(len(active_entries) <= 1, "more than one queue entry is active")
    retrospective_entries = [entry for entry in by_id.values() if entry.get("workflow_kind") == "devex-retrospective"]
    require(len(retrospective_entries) <= 1, "more than one DevEx retrospective queue entry")
    if retrospective_entries:
        retrospective = retrospective_entries[0]
        require(retrospective.get("status") != "superseded", "DevEx retrospective cannot be superseded")
        require(
            retrospective["sequence"] == max(
                entry["sequence"] for entry in by_id.values() if entry.get("status") != "superseded"
            ),
            "DevEx retrospective must be the final active queue sequence",
        )
        require(
            set(retrospective["included_paths"]).issubset({"AGENTS.md", ".agents/**"}),
            "DevEx retrospective paths must stay within AGENTS.md or .agents/**",
        )
    return seen


def require_devex_retrospective(state: dict[str, Any], *, terminal: bool) -> dict[str, Any]:
    entries = [entry for entry in state["queue"] if entry.get("workflow_kind") == "devex-retrospective"]
    require(len(entries) == 1, "exactly one DevEx retrospective queue entry is required", 4)
    entry = cast(dict[str, Any], entries[0])
    requirement_ids = entry.get("requirement_ids", [])
    require(len(requirement_ids) == 1, "DevEx retrospective must map exactly one workflow requirement", 4)
    workflow_requirements = [
        item
        for item in state["requirements"]
        if item.get("source", {}).get("file") == "skill://plan-pr-loop/devex-retrospective"
    ]
    require(
        len(workflow_requirements) == 1,
        "exactly one DevEx retrospective workflow requirement is required",
        4,
    )
    requirement = cast(dict[str, Any], workflow_requirements[0])
    require(
        requirement.get("requirement_id") == requirement_ids[0],
        "DevEx retrospective entry maps the wrong workflow requirement",
        4,
    )
    mapped_entries = [
        candidate["entry_id"]
        for candidate in state["queue"]
        if requirement_ids[0] in candidate.get("requirement_ids", [])
    ]
    require(mapped_entries == [entry["entry_id"]], "DevEx workflow requirement must map only to its final entry", 4)
    if terminal:
        require(
            entry.get("status") in {"merged", "satisfied-by-base"},
            "DevEx retrospective is not terminal",
            4,
        )
    return entry


def validate_coverage(
    coverage: Any,
    requirement_ids: set[str],
    queue_ids: set[str],
) -> None:
    require(isinstance(coverage, dict), "coverage must be an object")
    coverage = cast(dict[str, Any], coverage)
    require(set(coverage).issubset(requirement_ids), "coverage references unknown requirement_id")
    for requirement_id, raw_record in coverage.items():
        require(isinstance(raw_record, dict), f"coverage.{requirement_id} must be an object")
        record = cast(dict[str, Any], raw_record)
        require(record.get("status") in COVERAGE_STATUSES, f"coverage.{requirement_id} invalid status")
        planned_entry_ids = record.get("planned_entry_ids", [])
        require(isinstance(planned_entry_ids, list), f"coverage.{requirement_id}.planned_entry_ids must be a list")
        require(all(isinstance(item, str) and item for item in planned_entry_ids), f"coverage.{requirement_id} invalid planned_entry_ids")
        require(set(planned_entry_ids).issubset(queue_ids), f"coverage.{requirement_id} references unknown queue entry")
        if record["status"] in {"merged", "satisfied-by-base", "deferred-approved"}:
            require(
                isinstance(record.get("evidence_digest"), str) and record["evidence_digest"],
                f"coverage.{requirement_id}.evidence_digest required for terminal status",
            )


def validate_application_context(context: Any) -> None:
    require(isinstance(context, dict), "application_context must be an object")
    context = cast(dict[str, Any], context)
    for key in ("has_active_users", "backward_compatibility_required"):
        require(isinstance(context.get(key), bool), f"application_context.{key} must be boolean")
    feature_flags = context.get("feature_flags")
    allowed_flags = {"appropriate", "not-appropriate", "decide-per-pr", "not-applicable"}
    require(feature_flags in allowed_flags, "application_context.feature_flags invalid")
    if context["has_active_users"] or context["backward_compatibility_required"]:
        require(feature_flags != "not-applicable", "feature flag appropriateness must be confirmed for an in-use/compatible application")
    require(isinstance(context.get("confirmation_digest"), str) and context["confirmation_digest"], "application_context.confirmation_digest required")
    require(isinstance(context.get("confirmed_at"), str) and context["confirmed_at"], "application_context.confirmed_at required")


def validate_review_gate_record(entry_id: str, record: Any, queue_entry: dict[str, Any]) -> None:
    require(isinstance(record, dict), f"review gate must be an object: {entry_id}")
    record = cast(dict[str, Any], record)
    require(record.get("entry_id") == entry_id, f"review gate entry mismatch: {entry_id}")
    require(record.get("contract_digest") == queue_entry.get("contract_digest"), f"review gate contract is stale: {entry_id}")
    for key in (
        "base_sha",
        "head_sha",
        "critical_important_dispositions_digest",
        "thermo_artifact_digest",
        "thermo_dispositions_digest",
        "validation_digest",
        "fix_commit_sha",
        "verified_remote_head_sha",
        "completed_at",
    ):
        require(isinstance(record.get(key), str) and record[key], f"review gate {key} required: {entry_id}")
    reviewers = record.get("reviewer_artifact_digests")
    require(isinstance(reviewers, dict) and len(reviewers) == 2, f"review gate requires two reviewer artifacts: {entry_id}")
    require(
        all(isinstance(name, str) and name and isinstance(digest, str) and digest for name, digest in reviewers.items()),
        f"review gate reviewer artifacts are invalid: {entry_id}",
    )
    require(len(set(reviewers.values())) == 2, f"review gate reviewer artifacts must be independent: {entry_id}")
    require(record["fix_commit_sha"] == record["head_sha"], f"review gate fix commit is not final head: {entry_id}")
    require(record["verified_remote_head_sha"] == record["head_sha"], f"review gate remote head is stale: {entry_id}")


def require_current_review_gate(state: dict[str, Any], entry_id: str, base_sha: str, head_sha: str) -> dict[str, Any]:
    gate = state["review_gates"].get(entry_id)
    require(isinstance(gate, dict), f"complete review gate required: {entry_id}", 4)
    gate = cast(dict[str, Any], gate)
    queue_entry = next(entry for entry in state["queue"] if entry["entry_id"] == entry_id)
    validate_review_gate_record(entry_id, gate, queue_entry)
    require(gate["base_sha"] == base_sha, f"review gate base is stale: {entry_id}", 4)
    require(gate["head_sha"] == head_sha, f"review gate head is stale: {entry_id}", 4)
    return gate


def validate_state(state: dict[str, Any]) -> None:
    require(state.get("schema_version") == SCHEMA_VERSION, "unknown schema_version")
    require(isinstance(state.get("state_revision"), int) and state["state_revision"] >= 1, "invalid state_revision")
    require(
        isinstance(state.get("executor_fencing_token"), int)
        and state["executor_fencing_token"] >= 1,
        "invalid executor_fencing_token",
    )
    require(state.get("phase") in PHASES, "invalid phase")

    application_context = state.get("application_context")
    if application_context is not None:
        validate_application_context(application_context)
    if state.get("phase") != "preflight":
        require(application_context is not None, "active state requires confirmed application context")
    application_context_history = state.get("application_context_history", [])
    require(isinstance(application_context_history, list), "application_context_history must be a list")
    application_context_history = cast(list[Any], application_context_history)
    require(
        all(isinstance(item, dict) for item in application_context_history),
        "application_context_history must contain objects",
    )
    for item in application_context_history:
        validate_application_context(item)
    contexts_by_digest = {
        digest_json(item): cast(dict[str, Any], item)
        for item in application_context_history
    }
    if application_context is not None:
        require(
            digest_json(application_context) in contexts_by_digest,
            "current application context is missing from history",
        )

    plan = state.get("plan")
    require(isinstance(plan, dict), "plan must be an object")
    plan = cast(dict[str, Any], plan)
    for key in ("stable_id", "canonical_path", "digest"):
        require(isinstance(plan.get(key), str) and plan[key], f"plan.{key} required")
    require(isinstance(plan.get("files"), list), "plan.files must be a list")

    repository = state.get("repository")
    require(isinstance(repository, dict), "repository must be an object")
    repository = cast(dict[str, Any], repository)
    for key in ("repository_id", "base_branch"):
        require(isinstance(repository.get(key), str) and repository[key], f"repository.{key} required")

    requirement_ids = validate_requirements(state.get("requirements"))
    requirements_by_id = {item["requirement_id"]: item for item in cast(list[dict[str, Any]], state["requirements"])}
    if state.get("queue"):
        require(application_context is not None, "queue requires confirmed application context")
    queue_ids = validate_queue(state.get("queue"), requirement_ids)
    for entry in cast(list[dict[str, Any]], state["queue"]):
        require(entry["contract_digest"] == queue_contract_digest(entry, requirements_by_id), f"stale contract digest: {entry['entry_id']}")
        compatibility = entry.get("compatibility")
        require(isinstance(compatibility, dict), f"queue compatibility contract required: {entry['entry_id']}")
        compatibility = cast(dict[str, Any], compatibility)
        for key in ("behavior_change", "backward_compatible"):
            require(isinstance(compatibility.get(key), bool), f"queue compatibility.{key} must be boolean")
        require(compatibility.get("feature_flag_decision") in {"required", "not-required"}, "invalid per-PR feature flag decision")
        context_digest = entry.get("application_context_digest")
        require(
            isinstance(context_digest, str) and context_digest in contexts_by_digest,
            f"queue application context is unknown: {entry['entry_id']}",
        )
        context = contexts_by_digest[cast(str, context_digest)]
        if context["backward_compatibility_required"]:
            require(
                compatibility["backward_compatible"],
                "PR violates the confirmed backward-compatibility requirement",
            )
        if compatibility["behavior_change"] and context["feature_flags"] == "appropriate":
            require(compatibility["feature_flag_decision"] == "required", "behavior change requires a feature flag")
        if context["feature_flags"] == "not-appropriate":
            require(compatibility["feature_flag_decision"] == "not-required", "feature flags were confirmed inappropriate")
        if compatibility["behavior_change"] and context["feature_flags"] == "decide-per-pr":
            require(isinstance(compatibility.get("decision_evidence_digest"), str) and compatibility["decision_evidence_digest"], "per-PR feature flag decision requires human evidence")
    validate_coverage(state.get("coverage"), requirement_ids, queue_ids)
    queue_by_id = {entry["entry_id"]: entry for entry in cast(list[dict[str, Any]], state["queue"])}
    for requirement_id, record in cast(dict[str, dict[str, Any]], state["coverage"]).items():
        for entry_id in record.get("planned_entry_ids", []):
            entry = queue_by_id[entry_id]
            require(requirement_id in entry.get("requirement_ids", []), f"coverage mapping mismatch: {requirement_id} -> {entry_id}")
            require(entry.get("status", "queued") != "superseded", f"coverage maps superseded entry: {entry_id}")
    current = state.get("current")
    require(isinstance(current, dict), "current must be an object")
    current = cast(dict[str, Any], current)
    current_entry = current.get("entry_id")
    if current_entry is not None:
        require(isinstance(current_entry, str) and current_entry, "current.entry_id must be nonempty")
        require(current_entry in queue_ids, "current.entry_id is not present in queue")
    active_entries = [
        entry for entry in cast(list[dict[str, Any]], state["queue"])
        if entry.get("status", "queued") in ACTIVE_QUEUE_STATUSES
    ]
    if active_entries:
        require(current_entry == active_entries[0]["entry_id"], "active queue entry does not match current.entry_id")

    prs = state.get("prs")
    require(isinstance(prs, dict), "prs must be an object")
    prs = cast(dict[str, Any], prs)
    require(set(prs).issubset(queue_ids), "prs references unknown queue entry")
    require(all(isinstance(item, dict) for item in prs.values()), "each prs record must be an object")
    for entry_id, pr_record in prs.items():
        require(
            pr_record.get("contract_digest") == queue_by_id[entry_id]["contract_digest"],
            f"PR record contract is stale: {entry_id}",
        )

    review_gates = state.get("review_gates")
    require(isinstance(review_gates, dict), "review_gates must be an object")
    review_gates = cast(dict[str, Any], review_gates)
    require(set(review_gates).issubset(queue_ids), "review_gates references unknown queue entry")
    for entry_id, gate in review_gates.items():
        validate_review_gate_record(entry_id, gate, queue_by_id[entry_id])
        pr_record = prs.get(entry_id)
        require(isinstance(pr_record, dict), f"review gate lacks PR metadata: {entry_id}")
        pr_record = cast(dict[str, Any], pr_record)
        require(gate["base_sha"] == pr_record.get("reviewed_base_sha"), f"review gate base does not match PR metadata: {entry_id}")
        require(gate["head_sha"] == pr_record.get("local_head_sha"), f"review gate head does not match local PR metadata: {entry_id}")
        require(gate["head_sha"] == pr_record.get("remote_head_sha"), f"review gate head does not match remote PR metadata: {entry_id}")

    review_isolation = state.get("review_isolation")
    require(isinstance(review_isolation, dict), "review_isolation must be an object")
    review_isolation = cast(dict[str, Any], review_isolation)
    require(review_isolation.get("phase") in REVIEW_ISOLATION_TRANSITIONS, "invalid review isolation phase")

    final_acceptance = state.get("final_acceptance")
    require(final_acceptance is None or isinstance(final_acceptance, dict), "final_acceptance must be null or an object")

    requirements = cast(list[dict[str, Any]], state["requirements"])
    coverage = cast(dict[str, dict[str, Any]], state["coverage"])
    if state["phase"] not in {"preflight", *STOP_PHASES}:
        require_devex_retrospective(state, terminal=False)
    if state["phase"] != "preflight":
        require(requirements, "active state requires a nonempty requirement inventory")
        for requirement in requirements:
            requirement_id = requirement["requirement_id"]
            coverage_record = coverage.get(requirement_id)
            if requirement.get("status", "in-scope") == "in-scope":
                require(coverage_record is not None, f"in-scope requirement lacks coverage: {requirement_id}")
                coverage_record = cast(dict[str, Any], coverage_record)
                require(
                    coverage_record.get("status") == "satisfied-by-base" or bool(coverage_record.get("planned_entry_ids")),
                    f"in-scope requirement is not mapped: {requirement_id}",
                )
    if state["phase"] == "complete":
        require_devex_retrospective(state, terminal=True)
        require(requirements, "complete state requires a nonempty requirement inventory")
        for requirement in requirements:
            requirement_id = requirement["requirement_id"]
            record = coverage.get(requirement_id, {})
            expected = (
                {"deferred-approved"}
                if requirement.get("status", "in-scope") == "deferred-approved"
                else {"merged", "satisfied-by-base"}
            )
            require(record.get("status") in expected, f"requirement not complete: {requirement_id}")
        for entry in cast(list[dict[str, Any]], state["queue"]):
            require(entry.get("status") in TERMINAL_QUEUE_STATUSES, f"queue entry not terminal: {entry['entry_id']}")
            if entry.get("status") == "merged":
                pr_record = prs.get(entry["entry_id"])
                require(isinstance(pr_record, dict), f"merged entry lacks PR record: {entry['entry_id']}")
                pr_record = cast(dict[str, Any], pr_record)
                evidence = cast(dict[str, Any], entry["terminal_evidence"])
                require(pr_record.get("pr_number") == evidence["pr_number"], f"merged PR number mismatch: {entry['entry_id']}")
                require(pr_record.get("merge_sha") == evidence["merge_sha"], f"merged SHA mismatch: {entry['entry_id']}")
                gate = review_gates.get(entry["entry_id"])
                if not isinstance(gate, dict):
                    approval_id = evidence.get("review_exception_approval_id")
                    human_disposition_digest = evidence.get("human_disposition_digest")
                    approval = next(
                        (
                            item
                            for item in state["exception_approvals"]
                            if item.get("approval_id") == approval_id
                            and item.get("kind") == "merged-feedback-race"
                            and item.get("entry_id") == entry["entry_id"]
                            and item.get("contract_digest") == entry["contract_digest"]
                            and item.get("summary_digest") == human_disposition_digest
                            and item.get("merge_sha") == evidence.get("merge_sha")
                            and item.get("verification_digest") == evidence.get("verification_digest")
                            and item.get("feedback_identity_digest") == evidence.get("feedback_identity_digest")
                        ),
                        None,
                    )
                    require(isinstance(approval, dict), f"merged entry lacks review gate or approved merge-race exception: {entry['entry_id']}")

    feedback = state.get("feedback")
    require(isinstance(feedback, dict), "feedback must be an object")
    feedback = cast(dict[str, Any], feedback)
    for stream in FEEDBACK_STREAMS:
        require(isinstance(feedback.get(stream), dict), f"feedback.{stream} must be an object")
        for item_id, item in feedback[stream].items():
            normalized_stream, normalized_id, normalized = normalized_feedback({"stream": stream, "item": item})
            require(normalized_stream == stream and normalized_id == item_id, f"feedback identity mismatch: {stream}/{item_id}")
            require(normalized == item, f"feedback record contains unsupported fields: {stream}/{item_id}")

    outbox = state.get("outbox")
    require(isinstance(outbox, list), "outbox must be a list")
    outbox = cast(list[Any], outbox)
    operation_ids = [item.get("operation_id") for item in outbox if isinstance(item, dict)]
    require(len(operation_ids) == len(outbox), "each outbox item must be an object with operation_id")
    require(all(isinstance(item, str) and item for item in operation_ids), "invalid outbox operation_id")
    require(len(operation_ids) == len(set(operation_ids)), "duplicate outbox operation_id")
    require(
        all(
            isinstance(item, dict)
            and item.get("status")
            in {"pending", "authorized", "resolved", "ambiguous", "cancelled-before-attempt", "cancelled-human-resolved"}
            for item in outbox
        ),
        "invalid outbox status",
    )
    logical_digests: set[str] = set()
    for raw_item in outbox:
        item = cast(dict[str, Any], raw_item)
        kind = item.get("kind")
        require(kind in OUTBOX_REQUIRED_BY_KIND, "invalid outbox kind")
        for key in OUTBOX_REQUIRED_BY_KIND[cast(str, kind)]:
            require(item.get(key) is not None and item.get(key) != "", f"persisted {kind} operation.{key} required")
        feedback_targets = item.get("feedback_targets")
        feedback_digests = item.get("feedback_identity_digests")
        if feedback_targets is not None or feedback_digests is not None:
            require(kind == "review-request", "only review requests may batch feedback")
            require(
                isinstance(feedback_targets, list)
                and isinstance(feedback_digests, list)
                and len(feedback_targets) == len(feedback_digests)
                and len(feedback_targets) >= 1,
                "invalid batched feedback binding",
            )
            feedback_targets = cast(list[Any], feedback_targets)
            feedback_digests = cast(list[Any], feedback_digests)
            require(
                all(isinstance(value, str) and value for value in (*feedback_targets, *feedback_digests)),
                "batched feedback bindings must be nonempty strings",
            )
            require(len(set(feedback_targets)) == len(feedback_targets), "batched feedback targets must be unique")
            require(
                item.get("feedback_target") is None and item.get("feedback_identity_digest") is None,
                "persisted outbox mixes singular and batched feedback",
            )
        logical_fields = {
            key: item.get(key)
            for key in (
                "kind",
                "repository_id",
                "pr_number",
                "base_ref",
                "head_ref",
                "target",
                "feedback_target",
                "feedback_identity_digest",
                "feedback_targets",
                "feedback_identity_digests",
                "expected_base_oid",
                "expected_head_sha",
                "input_digest",
            )
        }
        logical_digest = digest_json(logical_fields)
        require(item.get("logical_digest") == logical_digest, "outbox logical_digest mismatch")
        require(logical_digest not in logical_digests, "duplicate logical outbox operation")
        logical_digests.add(logical_digest)
        if item.get("status") == "authorized":
            require(isinstance(item.get("authorized_at"), str) and item["authorized_at"], "authorized outbox lacks timestamp")
            require(item.get("attempted") is None, "authorized outbox cannot claim a provider result")
        elif item.get("status") == "resolved":
            require(isinstance(item.get("authorized_at"), str) and item["authorized_at"], "resolved outbox lacks authorization")
            require(isinstance(item.get("evidence_digest"), str) and item["evidence_digest"], "resolved outbox lacks evidence")
            if kind in {"pr-create", "comment-reply"}:
                require(item.get("remote_id") is not None and item.get("remote_id") != "", "resolved outbox lacks remote ID")
        elif item.get("status") == "cancelled-before-attempt":
            require(item.get("attempted") is False, "pre-attempt cancellation must prove no provider attempt")
            require(isinstance(item.get("evidence_digest"), str) and item["evidence_digest"], "cancelled outbox lacks evidence")
        elif item.get("status") == "cancelled-human-resolved":
            require(item.get("attempted") is True, "human-resolved cancellation must follow a possible provider attempt")
            for evidence_key in ("evidence_digest", "human_disposition_digest", "reconciliation_digest"):
                require(isinstance(item.get(evidence_key), str) and item[evidence_key], f"human-resolved cancellation lacks {evidence_key}")
        elif item.get("status") == "ambiguous":
            require(isinstance(item.get("authorized_at"), str) and item["authorized_at"], "ambiguous outbox lacks authorization")
            require(item.get("attempted") is True, "ambiguous outbox must record a possible provider attempt")
            require(isinstance(item.get("evidence_digest"), str) and item["evidence_digest"], "ambiguous outbox lacks evidence")

    if state["phase"] == "complete":
        final_acceptance = cast(dict[str, Any] | None, final_acceptance)
        require(
            isinstance(final_acceptance, dict)
            and final_acceptance.get("status") == "passed"
            and isinstance(final_acceptance.get("evidence_digest"), str)
            and final_acceptance["evidence_digest"],
            "complete state requires passed final acceptance evidence",
        )
        final_acceptance = cast(dict[str, Any], final_acceptance)
        require(
            final_acceptance.get("base_sha") == repository.get("last_verified_base_sha"),
            "final acceptance base does not match last verified repository base",
        )
        require(
            all(item.get("status") in {"resolved", "cancelled-before-attempt", "cancelled-human-resolved"} for item in outbox),
            "complete state has unresolved outbox",
        )
        for stream in FEEDBACK_STREAMS:
            for item_id, item in feedback[stream].items():
                require(
                    item.get("processing_state") == "disposed"
                    and isinstance(item.get("disposition"), str)
                    and item["disposition"],
                    f"complete state has undisposed feedback: {stream}/{item_id}",
                )

    require(isinstance(state.get("exception_approvals"), list), "exception_approvals must be a list")
    require(isinstance(state.get("history"), list), "history must be a list")
    reject_sensitive_keys(state)


def load_payload(args: argparse.Namespace) -> dict[str, Any]:
    raw: str
    if args.input_json is not None:
        raw = args.input_json
    elif not sys.stdin.isatty():
        raw = sys.stdin.read()
    else:
        raw = ""
    if not raw.strip():
        return {}
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise HelperError(f"invalid input JSON: {exc}", 2) from exc
    require(isinstance(value, dict), "input JSON must be an object")
    return value


def output(value: dict[str, Any]) -> None:
    json.dump(value, sys.stdout, sort_keys=True)
    sys.stdout.write("\n")
def normalized_feedback(payload: dict[str, Any]) -> tuple[str, str, dict[str, Any]]:
    stream = payload.get("stream")
    item = payload.get("item")
    require(stream in FEEDBACK_STREAMS, "invalid feedback stream")
    require(isinstance(item, dict), "feedback item object required")
    stream = cast(str, stream)
    item = cast(dict[str, Any], item)
    item_id = item.get("id")
    require(isinstance(item_id, (str, int)), "feedback item id required")
    record: dict[str, Any] = {
        "id": item_id,
        "classification": item.get("classification"),
        "body_digest": item.get("body_digest"),
        "disposition": item.get("disposition"),
        "url": item.get("url"),
        "outbound_operation_id": item.get("outbound_operation_id"),
        "review_request_operation_id": item.get("review_request_operation_id"),
        "processing_state": item.get("processing_state", "seen"),
        "intended_fix_digest": item.get("intended_fix_digest"),
        "expected_head_sha": item.get("expected_head_sha"),
        "commit_sha": item.get("commit_sha"),
        "validation_digest": item.get("validation_digest"),
    }
    for optional_key in (
        "repository_id",
        "entry_id",
        "pr_number",
        "mapped_entry_id",
        "mapped_entry_contract_digest",
        "merge_commit_sha",
        "merge_evidence_digest",
        "human_disposition_digest",
        "review_exception_approval_id",
    ):
        if optional_key in item:
            record[optional_key] = item.get(optional_key)
    if stream == "reviews":
        record.update({"submitted_at": item.get("submitted_at"), "state": item.get("state")})
        require(record["submitted_at"] is not None, "review submitted_at required")
        require(record["state"] is not None, "review state required")
    else:
        record.update({"updated_at": item.get("updated_at")})
        require(record["updated_at"] is not None, "comment updated_at required")
    require(isinstance(record["body_digest"], str) and record["body_digest"], "body_digest required")
    require(record["classification"] in FEEDBACK_CLASSES, "feedback classification required")
    require(record["processing_state"] in FEEDBACK_PROCESSING_TRANSITIONS, "invalid feedback processing_state")
    classification = record["classification"]
    processing_state = record["processing_state"]
    mapped_later = processing_state == "disposed" and isinstance(record.get("mapped_entry_id"), str)
    if mapped_later:
        require(classification == "code-change", "only code-change feedback may map to a later entry")
        for key in ("mapped_entry_contract_digest", "human_disposition_digest"):
            require(isinstance(record.get(key), str) and record[key], f"mapped feedback {key} required")
    if classification == "code-change":
        require(processing_state in {"seen", "in-progress", "code-pushed", "replied", "disposed"}, "invalid code feedback state")
    elif classification == "question":
        require(processing_state in {"seen", "replied", "disposed"}, "invalid question feedback state")
    else:
        require(processing_state in {"seen", "disposed"}, "invalid non-actionable feedback state")
    if processing_state == "in-progress":
        for key in ("intended_fix_digest", "expected_head_sha"):
            require(isinstance(record.get(key), str) and record[key], f"feedback {key} required in progress")
    if (
        classification == "code-change"
        and processing_state in {"code-pushed", "replied", "disposed"}
        and not mapped_later
    ):
        for key in ("intended_fix_digest", "expected_head_sha"):
            require(isinstance(record.get(key), str) and record[key], f"feedback {key} required after code push")
        for key in ("commit_sha", "validation_digest"):
            require(isinstance(record.get(key), str) and record[key], f"feedback {key} required after code push")
    if (
        processing_state in {"replied", "disposed"}
        and classification in {"code-change", "question"}
        and not mapped_later
    ):
        require(isinstance(record.get("outbound_operation_id"), str) and record["outbound_operation_id"], "feedback outbound_operation_id required after reply")
    if classification == "code-change" and processing_state in {"replied", "disposed"} and not mapped_later:
        if not (isinstance(record.get("review_request_operation_id"), str) and record["review_request_operation_id"]):
            for key in (
                "merge_commit_sha",
                "merge_evidence_digest",
                "human_disposition_digest",
                "review_exception_approval_id",
            ):
                require(isinstance(record.get(key), str) and record[key], f"merged feedback {key} required without review request")
    if processing_state == "disposed":
        require(isinstance(record.get("disposition"), str) and record["disposition"], "disposed feedback requires disposition")
    return stream, str(item_id), record
