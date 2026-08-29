#!/usr/bin/env python3
"""Deterministic state, lock, lease, and outbox helper for plan-pr-loop."""

from __future__ import annotations

import argparse
import hashlib
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, cast

from pr_loop_feedback import (
    command_approval_check,
    command_approval_record,
    command_feedback_check,
    command_feedback_record,
    command_outbox_authorize,
    command_outbox_begin,
    command_outbox_resolve,
)
from pr_loop_lease import (
    command_lease_acquire,
    command_lease_release,
    command_lease_takeover,
    command_lock_init,
    command_lock_release,
    command_lock_update_plan,
    expected_state_path,
    require_lock_args,
    verify_live_lease_locked,
)
from pr_loop_model import (
    COVERAGE_STATUSES,
    FEEDBACK_STREAMS,
    PHASES,
    QUEUE_STATUS_TRANSITIONS,
    REVIEW_ISOLATION_TRANSITIONS,
    SCHEMA_VERSION,
    STOP_PHASES,
    TERMINAL_QUEUE_STATUSES,
    TRANSITIONS,
    HelperError,
    digest_json,
    load_payload,
    output,
    require,
    require_current_review_gate,
    require_plan_branch,
    require_devex_retrospective,
    utc_now,
    validate_application_context,
    validate_queue,
    validate_reason,
    validate_requirements,
    validate_review_gate_record,
    validate_state,
    with_contract_digests,
)
from pr_loop_store import atomic_write_json, check_cas, commit_mutation, exclusive_file_lock, load_state, read_json

def command_init(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    require(args.state is not None, "--state is required")
    require(args.fencing_token is not None and args.fencing_token >= 1, "--fencing-token is required")
    path = Path(args.state).expanduser().resolve()
    require(not path.exists(), f"state already exists: {path}", 3)
    plan = payload.get("plan")
    repository = payload.get("repository")
    require(isinstance(plan, dict), "input plan object required")
    require(isinstance(repository, dict), "input repository object required")
    plan = cast(dict[str, Any], plan)
    repository = cast(dict[str, Any], repository)
    requirements = payload.get("requirements", [])
    validate_requirements(requirements)
    requirements = cast(list[dict[str, Any]], requirements)
    application_context = payload.get("application_context")
    if application_context is not None:
        validate_application_context(application_context)
    queue = with_contract_digests(payload.get("queue", []), requirements, application_context)
    state = {
        "schema_version": SCHEMA_VERSION,
        "state_revision": 1,
        "executor_fencing_token": args.fencing_token,
        "plan": plan,
        "repository": repository,
        "phase": "preflight",
        "application_context": application_context,
        "application_context_history": [application_context] if application_context is not None else [],
        "requirements": requirements,
        "queue": queue,
        "coverage": payload.get("coverage", {}),
        "current": {},
        "prs": {},
        "review_gates": {},
        "review_isolation": {"phase": "none"},
        "final_acceptance": None,
        "feedback": {stream: {} for stream in sorted(FEEDBACK_STREAMS)},
        "outbox": [],
        "exception_approvals": [],
        "history": [
            {
                "event": "initialized",
                "at": utc_now(),
                "plan_digest": plan.get("digest"),
            }
        ],
    }
    validate_state(state)
    atomic_write_json(path, state)
    return {"ok": True, "state_revision": 1, "phase": "preflight"}



def command_bind_lease(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    path, state = load_state(args)
    check_cas(state, args, bind=True)
    state["executor_fencing_token"] = args.fencing_token
    state["history"].append({"event": "lease-bound", "at": utc_now(), "fencing_token": args.fencing_token})
    return commit_mutation(path, state)


def command_validate(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    _, state = load_state(args)
    return {
        "ok": True,
        "state_revision": state["state_revision"],
        "phase": state["phase"],
        "executor_fencing_token": state["executor_fencing_token"],
    }


def command_transition(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    path, state = load_state(args)
    check_cas(state, args)
    destination = payload.get("to_phase")
    reason = validate_reason(payload.get("reason"), "transition reason")
    require(destination in PHASES, "valid to_phase required")
    source = state["phase"]
    allowed = set(TRANSITIONS[source])
    if source != "complete":
        allowed |= STOP_PHASES
    require(destination in allowed, f"illegal transition: {source} -> {destination}", 4)
    if destination not in {"preflight", *STOP_PHASES}:
        require_devex_retrospective(state, terminal=False)
    if destination == "publishing" or (source == "addressing-feedback" and destination == "awaiting-human-review"):
        current = state["current"]
        entry_id = current.get("entry_id")
        require(isinstance(entry_id, str) and entry_id, "review publication requires a current entry", 4)
        base_sha = current.get("reviewed_base_sha")
        head_sha = current.get("local_head_sha")
        require(isinstance(base_sha, str) and base_sha, "review publication requires reviewed_base_sha", 4)
        require(isinstance(head_sha, str) and head_sha, "review publication requires local_head_sha", 4)
        require_current_review_gate(state, entry_id, base_sha, head_sha)
    state["phase"] = destination
    state["history"].append({"event": "transition", "from": source, "to": destination, "reason": reason, "at": utc_now()})
    return commit_mutation(path, state)


def require_devex_artifact(state_path: Path, entry: dict[str, Any]) -> None:
    evidence = entry.get("terminal_evidence", {})
    relative = evidence.get("retrospective_artifact")
    require(isinstance(relative, str) and relative, "DevEx retrospective artifact path required", 4)
    relative_path = Path(relative)
    require(not relative_path.is_absolute(), "DevEx retrospective artifact must be run-relative", 4)
    artifact_path = (state_path.parent / relative_path).resolve()
    require(artifact_path.is_relative_to(state_path.parent.resolve()), "DevEx retrospective artifact escapes run state", 4)
    try:
        artifact_digest = hashlib.sha256(artifact_path.read_bytes()).hexdigest()
    except OSError as exc:
        raise HelperError(f"cannot read DevEx retrospective artifact: {exc}", 5) from exc
    require(
        evidence.get("retrospective_artifact_digest") == artifact_digest,
        "DevEx retrospective artifact digest mismatch",
        4,
    )


def command_record_queue(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    path, state = load_state(args)
    check_cas(state, args)
    queue = payload.get("queue")
    reason = payload.get("reason")
    reason = validate_reason(reason, "queue update reason")
    requirement_ids = {item["requirement_id"] for item in state["requirements"]}
    queue = with_contract_digests(queue, state["requirements"], state.get("application_context"))
    validate_queue(queue, requirement_ids)
    queue = cast(list[dict[str, Any]], queue)
    old_by_id = {entry["entry_id"]: entry for entry in state["queue"]}
    new_by_id = {entry["entry_id"]: entry for entry in queue}
    immutable_exceptions = {"sequence", "revision", "status", "split_into", "terminal_evidence", "contract_digest"}
    for entry_id, old_entry in old_by_id.items():
        require(entry_id in new_by_id, f"persisted queue entry cannot be removed: {entry_id}", 3)
        new_entry = new_by_id[entry_id]
        old_core = {key: value for key, value in old_entry.items() if key not in immutable_exceptions}
        new_core = {key: value for key, value in new_entry.items() if key not in immutable_exceptions}
        require(old_core == new_core, f"immutable queue entry fields changed: {entry_id}", 3)
        require(new_entry["revision"] >= old_entry["revision"], f"queue revision decreased: {entry_id}", 3)
        old_status = old_entry.get("status", "queued")
        new_status = new_entry.get("status", "queued")
        if new_status != old_status:
            require(new_status in QUEUE_STATUS_TRANSITIONS[old_status], f"illegal queue status transition: {old_status} -> {new_status}", 4)
            if new_entry.get("workflow_kind") == "devex-retrospective" and new_status in {
                "implementing",
                "satisfied-by-base",
            }:
                require(
                    all(
                        other.get("status") in TERMINAL_QUEUE_STATUSES
                        for other_id, other in new_by_id.items()
                        if other_id != entry_id and other.get("status") != "superseded"
                    ),
                    "DevEx retrospective cannot start before every ordinary queue entry is terminal",
                    4,
                )
            if new_entry.get("workflow_kind") == "devex-retrospective" and new_status in {
                "merged",
                "satisfied-by-base",
            }:
                require_devex_artifact(path, new_entry)
            if new_status == "publishing":
                current = state["current"]
                require(current.get("entry_id") == entry_id, "publishing queue entry is not current", 4)
                base_sha = current.get("reviewed_base_sha")
                head_sha = current.get("local_head_sha")
                require(isinstance(base_sha, str) and base_sha, "publishing requires reviewed_base_sha", 4)
                require(isinstance(head_sha, str) and head_sha, "publishing requires local_head_sha", 4)
                require_current_review_gate(state, entry_id, base_sha, head_sha)
            if new_status == "implementing" and new_entry.get("exception_required"):
                require(
                    any(
                        approval.get("entry_id") == entry_id
                        and approval.get("contract_digest") == new_entry["contract_digest"]
                        and approval.get("kind", "scope-exception") == "scope-exception"
                        for approval in state["exception_approvals"]
                    ),
                    f"queue entry requires current human exception approval: {entry_id}",
                    4,
                )
        if old_entry.get("status") in TERMINAL_QUEUE_STATUSES:
            require(new_entry.get("status") == old_entry.get("status"), f"terminal queue entry reopened: {entry_id}", 3)
        if old_entry.get("status", "queued") != "queued":
            require(new_entry.get("sequence") == old_entry.get("sequence"), f"started queue entry reordered: {entry_id}", 3)
        if new_entry.get("status") == "superseded":
            require(new_entry.get("split_into"), f"superseded queue entry requires split_into: {entry_id}")

    for entry_id, new_entry in new_by_id.items():
        if entry_id in old_by_id:
            continue
        supersedes = new_entry.get("supersedes", [])
        if old_by_id and state["phase"] != "preflight":
            require(supersedes, f"post-preflight queue entry must split a queued parent: {entry_id}", 3)
            require(
                all(parent_id in old_by_id for parent_id in supersedes),
                f"post-preflight split must reference only persisted parents: {entry_id}",
                3,
            )
        for parent_id in supersedes:
            require(parent_id in old_by_id or state["phase"] == "preflight", f"split parent is not persisted: {parent_id}", 3)
            if parent_id not in old_by_id:
                continue
            old_parent = old_by_id[parent_id]
            new_parent = new_by_id[parent_id]
            require(old_parent.get("status", "queued") == "queued", f"only a queued entry may be split: {parent_id}", 3)
            require(new_parent.get("status") == "superseded", f"split parent must become superseded: {parent_id}", 3)
            require(entry_id in new_parent.get("split_into", []), f"split parent omits child lineage: {parent_id} -> {entry_id}", 3)
            require(
                set(new_entry["requirement_ids"]).issubset(set(old_parent["requirement_ids"])),
                f"split child adds requirements not present in parent: {entry_id}",
                3,
            )

    for parent_id, old_parent in old_by_id.items():
        new_parent = new_by_id[parent_id]
        if old_parent.get("status", "queued") == "queued" and new_parent.get("status") == "superseded":
            child_ids = new_parent.get("split_into", [])
            require(child_ids, f"split parent has no children: {parent_id}", 3)
            require(all(child_id in new_by_id for child_id in child_ids), f"split parent references missing child: {parent_id}", 3)
            require(
                all(parent_id in new_by_id[child_id].get("supersedes", []) for child_id in child_ids),
                f"split child omits parent lineage: {parent_id}",
                3,
            )
            child_requirements = {
                requirement_id
                for child_id in child_ids
                for requirement_id in new_by_id[child_id].get("requirement_ids", [])
            }
            require(
                child_requirements == set(old_parent.get("requirement_ids", [])),
                f"split does not conserve parent requirements: {parent_id}",
                3,
            )

    old_queue_digest = digest_json(state["queue"])
    old_summary = {
        entry_id: {key: entry.get(key) for key in ("revision", "sequence", "status", "split_into")}
        for entry_id, entry in old_by_id.items()
    }
    state["queue"] = queue
    coverage = cast(dict[str, dict[str, Any]], state["coverage"])
    for requirement_id in requirement_ids:
        mapped = [
            entry["entry_id"]
            for entry in queue
            if requirement_id in entry.get("requirement_ids", []) and entry.get("status") != "superseded"
        ]
        record = coverage.setdefault(requirement_id, {"status": "planned", "planned_entry_ids": []})
        record["planned_entry_ids"] = mapped
        if record.get("status") == "planned" and not mapped:
            coverage.pop(requirement_id)
    state["history"].append(
        {
            "event": "queue-recorded",
            "reason": reason,
            "entry_ids": [entry["entry_id"] for entry in queue],
            "prior_queue_digest": old_queue_digest,
            "new_queue_digest": digest_json(queue),
            "prior_entries": old_summary,
            "new_entries": {
                entry["entry_id"]: {key: entry.get(key) for key in ("revision", "sequence", "status", "split_into")}
                for entry in queue
            },
            "at": utc_now(),
        }
    )
    return commit_mutation(path, state)


def command_record_requirements(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    path, state = load_state(args)
    check_cas(state, args)
    require(state["phase"] == "preflight", "requirements may change only in preflight", 4)
    requirements = payload.get("requirements")
    reason = payload.get("reason")
    reason = validate_reason(reason, "requirement inventory reason")
    validate_requirements(requirements)
    requirements = cast(list[dict[str, Any]], requirements)
    old_by_id = {item["requirement_id"]: item for item in state["requirements"]}
    new_by_id = {item["requirement_id"]: item for item in requirements}
    started_ids = {
        requirement_id
        for entry in state["queue"]
        if entry.get("status", "queued") != "queued"
        for requirement_id in entry.get("requirement_ids", [])
    }
    for requirement_id in started_ids:
        require(requirement_id in new_by_id, f"started requirement cannot be removed: {requirement_id}", 3)
        require(old_by_id.get(requirement_id) == new_by_id[requirement_id], f"started requirement cannot change: {requirement_id}", 3)
    new_ids = set(new_by_id)
    if old_by_id and old_by_id != new_by_id:
        require(
            isinstance(payload.get("approval_evidence_digest"), str) and payload["approval_evidence_digest"],
            "changed requirement inventory requires approval_evidence_digest",
            3,
        )
    for entry in state["queue"]:
        require(set(entry.get("requirement_ids", [])).issubset(new_ids), f"queue entry would reference removed requirement: {entry['entry_id']}", 3)
    state["requirements"] = requirements
    state["queue"] = with_contract_digests(
        state["queue"], requirements, state.get("application_context"), allow_stale=True
    )
    state["coverage"] = {
        requirement_id: record
        for requirement_id, record in state["coverage"].items()
        if requirement_id in new_ids
    }
    state["history"].append(
        {
            "event": "requirements-recorded",
            "reason": reason,
            "requirement_ids": sorted(new_ids),
            "approval_evidence_digest": payload.get("approval_evidence_digest"),
            "at": utc_now(),
        }
    )
    return commit_mutation(path, state)


def command_record_coverage(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    path, state = load_state(args)
    check_cas(state, args)
    requirement_id = payload.get("requirement_id")
    status = payload.get("status")
    require(isinstance(requirement_id, str) and requirement_id, "requirement_id required")
    require(requirement_id in {item["requirement_id"] for item in state["requirements"]}, "unknown requirement_id")
    require(status in COVERAGE_STATUSES, "invalid coverage status")
    previous = state["coverage"].get(requirement_id, {})
    queue_by_id = {entry["entry_id"]: entry for entry in state["queue"]}
    planned_entry_ids = previous.get("planned_entry_ids", [])
    evidence_digest = payload.get("evidence_digest")
    if status in {"merged", "satisfied-by-base"}:
        require(planned_entry_ids, f"{status} coverage requires mapped queue entries")
        expected_entry_status = "merged" if status == "merged" else "satisfied-by-base"
        require(
            all(queue_by_id[entry_id].get("status") == expected_entry_status for entry_id in planned_entry_ids),
            f"coverage status does not match terminal queue evidence: {requirement_id}",
        )
        computed_evidence = digest_json([queue_by_id[entry_id]["terminal_evidence"] for entry_id in planned_entry_ids])
        require(evidence_digest in {None, computed_evidence}, "coverage evidence_digest does not match queue evidence", 3)
        evidence_digest = computed_evidence
    elif status == "deferred-approved":
        requirement = next(item for item in state["requirements"] if item["requirement_id"] == requirement_id)
        require(requirement.get("status") == "deferred-approved", "requirement is not approved for deferral", 3)
        require(isinstance(evidence_digest, str) and evidence_digest, "deferred coverage requires approval evidence")
    record = {
        "status": status,
        "planned_entry_ids": planned_entry_ids,
    }
    if evidence_digest is not None:
        record["evidence_digest"] = evidence_digest
        record["verified_at"] = payload.get("verified_at") or utc_now()
    state["coverage"][requirement_id] = record
    state["history"].append(
        {"event": "coverage-recorded", "requirement_id": requirement_id, "status": status, "at": utc_now()}
    )
    return commit_mutation(path, state)


def command_record_plan(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    path, state = load_state(args)
    check_cas(state, args)
    require(state["phase"] == "preflight", "plan may change only in preflight", 4)
    plan = payload.get("plan")
    reason = payload.get("reason")
    require(isinstance(plan, dict), "plan object required")
    reason = validate_reason(reason, "plan reconciliation reason")
    plan = cast(dict[str, Any], plan)
    require(plan.get("stable_id") == state["plan"]["stable_id"], "stable plan ID cannot change", 3)
    require(plan.get("canonical_path") == state["plan"]["canonical_path"], "canonical plan path cannot change", 3)
    require(isinstance(plan.get("digest"), str) and plan["digest"], "plan.digest required")
    require(isinstance(plan.get("files"), list), "plan.files must be a list")
    prior_digest = state["plan"]["digest"]
    if plan["digest"] != prior_digest:
        require(
            isinstance(payload.get("approval_evidence_digest"), str) and payload["approval_evidence_digest"],
            "changed plan requires approval_evidence_digest",
            3,
        )
    state["plan"] = plan
    state["history"].append(
        {
            "event": "plan-reconciled",
            "prior_digest": prior_digest,
            "new_digest": plan["digest"],
            "reason": reason,
            "approval_evidence_digest": payload.get("approval_evidence_digest"),
            "at": utc_now(),
        }
    )
    return commit_mutation(path, state)


def command_record_pr(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    path, state = load_state(args)
    check_cas(state, args)
    patch = payload.get("current")
    require(isinstance(patch, dict), "current patch object required")
    patch = cast(dict[str, Any], patch)
    allowed = {
        "entry_id",
        "sequence",
        "branch",
        "base_sha",
        "reviewed_base_sha",
        "local_head_sha",
        "remote_head_sha",
        "pr_number",
        "pr_url",
        "review_artifact",
        "merged_at",
        "merge_sha",
        "contract_digest",
    }
    require(set(patch).issubset(allowed), "current patch contains unsupported fields")
    entry_id = patch.get("entry_id") or state["current"].get("entry_id")
    require(isinstance(entry_id, str) and entry_id, "record-pr requires an entry_id or an existing current entry")
    queue_by_id = {entry["entry_id"]: entry for entry in state["queue"]}
    require(entry_id in queue_by_id, "record-pr entry_id is not present in queue")
    previous_record = state["prs"].get(entry_id, {})
    if "branch" in patch:
        require_plan_branch(state["plan"]["stable_id"], patch["branch"], queue_by_id[entry_id]["sequence"])
        require(
            previous_record.get("branch") in {None, patch["branch"]},
            "persisted feature branch cannot change",
            3,
        )
    if any(
        key in patch and previous_record.get(key) is not None and previous_record.get(key) != patch.get(key)
        for key in ("reviewed_base_sha", "local_head_sha", "remote_head_sha")
    ):
        state["review_gates"].pop(entry_id, None)
        state["history"].append({"event": "review-gate-invalidated", "entry_id": entry_id, "at": utc_now()})
    if state["current"].get("entry_id") != entry_id:
        state["current"] = dict(patch)
        state["current"]["entry_id"] = entry_id
    else:
        state["current"].update(patch)
    pr_record = state["prs"].setdefault(entry_id, {})
    pr_record.update(patch)
    pr_record["entry_id"] = entry_id
    pr_record["contract_digest"] = queue_by_id[entry_id]["contract_digest"]
    state["history"].append({"event": "pr-recorded", "fields": sorted(patch), "at": utc_now()})
    return commit_mutation(path, state)


def command_record_review_gate(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    path, state = load_state(args)
    check_cas(state, args)
    require(state["phase"] in {"internal-review", "addressing-feedback"}, "review gate may be recorded only during review", 4)
    required = {
        "entry_id",
        "base_sha",
        "head_sha",
        "contract_digest",
        "reviewer_artifact_digests",
        "critical_important_dispositions_digest",
        "thermo_artifact_digest",
        "thermo_dispositions_digest",
        "validation_digest",
        "fix_commit_sha",
        "verified_remote_head_sha",
    }
    optional = {"completed_at"}
    require(required.issubset(payload), "review gate is missing required evidence")
    require(set(payload).issubset(required | optional), "review gate contains unsupported fields")
    entry_id = payload.get("entry_id")
    require(isinstance(entry_id, str) and entry_id, "review gate entry_id required")
    entry_id = cast(str, entry_id)
    queue_by_id = {entry["entry_id"]: entry for entry in state["queue"]}
    require(entry_id in queue_by_id, "review gate entry is not present in queue")
    require(state["current"].get("entry_id") == entry_id, "review gate entry is not current", 4)
    require(
        queue_by_id[entry_id].get("status") in {"internal-review", "addressing-feedback"},
        "queue entry is not in a reviewable status",
        4,
    )
    record = dict(payload)
    record["completed_at"] = record.get("completed_at") or utc_now()
    validate_review_gate_record(entry_id, record, queue_by_id[entry_id])
    current = state["current"]
    require(record["base_sha"] == current.get("reviewed_base_sha"), "review gate base does not match current metadata", 4)
    require(record["head_sha"] == current.get("local_head_sha"), "review gate head does not match local metadata", 4)
    require(record["head_sha"] == current.get("remote_head_sha"), "review gate head does not match remote metadata", 4)
    state["review_gates"][entry_id] = record
    state["history"].append(
        {
            "event": "review-gate-recorded",
            "entry_id": entry_id,
            "base_sha": record["base_sha"],
            "head_sha": record["head_sha"],
            "at": utc_now(),
        }
    )
    return commit_mutation(path, state)


def command_record_application_context(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    path, state = load_state(args)
    check_cas(state, args)
    require(state["phase"] == "preflight", "application context may change only in preflight", 4)
    allowed = {
        "has_active_users",
        "backward_compatibility_required",
        "feature_flags",
        "confirmation_digest",
        "confirmed_at",
    }
    require(set(payload) == allowed, "application context requires the exact documented fields")
    validate_application_context(payload)
    if state.get("application_context") is not None and state["application_context"] != payload:
        require(payload["confirmation_digest"] != state["application_context"]["confirmation_digest"], "changed answers require new confirmation evidence", 3)
    state["application_context"] = dict(payload)
    if not any(digest_json(item) == digest_json(payload) for item in state["application_context_history"]):
        state["application_context_history"].append(dict(payload))
    current_digest = digest_json(payload)
    queue: list[dict[str, Any]] = []
    for existing in state["queue"]:
        entry = dict(existing)
        if entry.get("status", "queued") == "queued" and entry["entry_id"] not in state["prs"]:
            entry["application_context_digest"] = current_digest
            entry.pop("contract_digest", None)
        queue.extend(
            with_contract_digests(
                [entry],
                state["requirements"],
                state["application_context"],
                allow_stale=True,
            )
        )
    state["queue"] = queue
    state["history"].append(
        {"event": "application-context-recorded", "confirmation_digest": payload["confirmation_digest"], "at": utc_now()}
    )
    return commit_mutation(path, state)


def command_record_acceptance(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    path, state = load_state(args)
    check_cas(state, args)
    retrospective = require_devex_retrospective(state, terminal=True)
    require_devex_artifact(path, retrospective)
    require(all(entry.get("status") in TERMINAL_QUEUE_STATUSES for entry in state["queue"]), "final acceptance requires terminal queue")
    require(
        set(state["coverage"]) == {item["requirement_id"] for item in state["requirements"]},
        "final acceptance requires complete requirement coverage",
    )
    require(
        all(record.get("status") in {"merged", "satisfied-by-base", "deferred-approved"} for record in state["coverage"].values()),
        "final acceptance requires terminal coverage",
    )
    require(
        all(
            item.get("status") in {"resolved", "cancelled-before-attempt", "cancelled-human-resolved"}
            for item in state["outbox"]
        ),
        "final acceptance requires resolved outbox",
    )
    for stream in FEEDBACK_STREAMS:
        require(
            all(item.get("processing_state") == "disposed" for item in state["feedback"][stream].values()),
            "final acceptance requires disposed feedback",
        )
    allowed = {"status", "evidence_digest", "base_sha", "verified_at"}
    require(set(payload).issubset(allowed), "final acceptance contains unsupported fields")
    require(payload.get("status") == "passed", "only passed final acceptance may be recorded")
    for key in ("evidence_digest", "base_sha"):
        require(isinstance(payload.get(key), str) and payload[key], f"final acceptance {key} required")
    state["final_acceptance"] = {
        "status": "passed",
        "evidence_digest": payload["evidence_digest"],
        "base_sha": payload["base_sha"],
        "verified_at": payload.get("verified_at") or utc_now(),
    }
    state["repository"]["last_verified_base_sha"] = payload["base_sha"]
    state["history"].append(
        {"event": "final-acceptance-recorded", "evidence_digest": payload["evidence_digest"], "at": utc_now()}
    )
    return commit_mutation(path, state)


def command_record_review_isolation(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    path, state = load_state(args)
    check_cas(state, args)
    allowed = {
        "phase",
        "source_path",
        "backup_path",
        "archive_path",
        "base_oid",
        "head_oid",
        "manifest_digest",
        "restored",
    }
    require(set(payload).issubset(allowed), "review isolation contains unsupported fields")
    destination = payload.get("phase")
    require(destination in REVIEW_ISOLATION_TRANSITIONS, "valid review isolation phase required")
    previous = state["review_isolation"]
    source = previous.get("phase", "none")
    require(destination in REVIEW_ISOLATION_TRANSITIONS[source], f"illegal review isolation transition: {source} -> {destination}", 4)
    record = dict(previous)
    record.update(payload)
    if destination in {"backup-intent", "backed-up", "restore-intent", "restored"}:
        require(isinstance(record.get("source_path"), str) and record["source_path"], "review isolation source_path required")
    if destination in {"backup-intent", "backed-up"}:
        require(isinstance(record.get("backup_path"), str) and record["backup_path"], "review isolation backup_path required")
    if destination in {"reviewing", "archive-intent", "archived"}:
        for key in ("base_oid", "head_oid", "manifest_digest"):
            require(isinstance(record.get(key), str) and record[key], f"review isolation {key} required")
    if destination in {"archive-intent", "archived"}:
        require(isinstance(record.get("archive_path"), str) and record["archive_path"], "review isolation archive_path required")
    if destination == "restored":
        record["restored"] = True
    state["review_isolation"] = record
    state["history"].append({"event": "review-isolation", "from": source, "to": destination, "at": utc_now()})
    return commit_mutation(path, state)


CommandHandler = Callable[[argparse.Namespace, dict[str, Any]], dict[str, Any]]


@dataclass(frozen=True)
class CommandSpec:
    handler: CommandHandler
    requires_live_lease: bool = False


COMMANDS: dict[str, CommandSpec] = {
    "lock-init": CommandSpec(command_lock_init),
    "lock-release": CommandSpec(command_lock_release),
    "lock-update-plan": CommandSpec(command_lock_update_plan),
    "lease-acquire": CommandSpec(command_lease_acquire),
    "lease-release": CommandSpec(command_lease_release),
    "lease-takeover": CommandSpec(command_lease_takeover),
    "init": CommandSpec(command_init, requires_live_lease=True),
    "validate": CommandSpec(command_validate),
    "bind-lease": CommandSpec(command_bind_lease, requires_live_lease=True),
    "transition": CommandSpec(command_transition, requires_live_lease=True),
    "record-requirements": CommandSpec(command_record_requirements, requires_live_lease=True),
    "record-queue": CommandSpec(command_record_queue, requires_live_lease=True),
    "record-coverage": CommandSpec(command_record_coverage, requires_live_lease=True),
    "record-acceptance": CommandSpec(command_record_acceptance, requires_live_lease=True),
    "record-review-isolation": CommandSpec(command_record_review_isolation, requires_live_lease=True),
    "record-review-gate": CommandSpec(command_record_review_gate, requires_live_lease=True),
    "record-plan": CommandSpec(command_record_plan, requires_live_lease=True),
    "record-pr": CommandSpec(command_record_pr, requires_live_lease=True),
    "record-application-context": CommandSpec(command_record_application_context, requires_live_lease=True),
    "feedback-check": CommandSpec(command_feedback_check),
    "feedback-record": CommandSpec(command_feedback_record, requires_live_lease=True),
    "outbox-begin": CommandSpec(command_outbox_begin, requires_live_lease=True),
    "outbox-authorize": CommandSpec(command_outbox_authorize, requires_live_lease=True),
    "outbox-resolve": CommandSpec(command_outbox_resolve, requires_live_lease=True),
    "approval-check": CommandSpec(command_approval_check),
    "approval-record": CommandSpec(command_approval_record, requires_live_lease=True),
}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command")
    parser.add_argument("--state")
    parser.add_argument("--lock")
    parser.add_argument("--input-json")
    parser.add_argument("--expected-revision", type=int)
    parser.add_argument("--expected-phase")
    parser.add_argument("--fencing-token", type=int)
    parser.add_argument("--owner-token")
    parser.add_argument("--repository-id")
    parser.add_argument("--stable-plan-id")
    parser.add_argument("--plan-digest")
    parser.add_argument("--goal-id")
    parser.add_argument("--executor-id")
    parser.add_argument("--git-common-dir")
    parser.add_argument("--git-dir")
    parser.add_argument("--checkout-incarnation")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    if args.command not in COMMANDS:
        sys.stderr.write(f"unknown command: {args.command}\n")
        return 64
    try:
        payload = load_payload(args)
        spec = COMMANDS[args.command]
        if spec.requires_live_lease:
            require(args.state is not None, "--state is required")
            state_path = Path(args.state).expanduser().resolve()
            lock_path = require_lock_args(args)
            with exclusive_file_lock(lock_path / ".mutex", create_parent=False):
                verify_live_lease_locked(lock_path, args)
                owner = read_json(lock_path / "owner.json")
                bound_state_path = expected_state_path(lock_path, owner)
                require(state_path == bound_state_path, "state path is not bound to this plan lock", 3)
                with exclusive_file_lock(state_path.with_name(f".{state_path.name}.mutation.lock")):
                    if args.command == "init":
                        plan = payload.get("plan", {})
                        repository = payload.get("repository", {})
                        require(plan.get("stable_id") == owner["stable_plan_id"], "init plan does not match plan lock", 3)
                        require(
                            repository.get("repository_id") == owner["repository_id"],
                            "init repository does not match plan lock",
                            3,
                        )
                    else:
                        bound_state = read_json(state_path)
                        require(
                            bound_state.get("plan", {}).get("stable_id") == owner["stable_plan_id"],
                            "state plan does not match plan lock",
                            3,
                        )
                        require(
                            bound_state.get("repository", {}).get("repository_id") == owner["repository_id"],
                            "state repository does not match plan lock",
                            3,
                        )
                    result = spec.handler(args, payload)
        else:
            result = spec.handler(args, payload)
        output(result)
        return 0
    except HelperError as exc:
        sys.stderr.write(f"error: {exc}\n")
        return exc.code


if __name__ == "__main__":
    raise SystemExit(main())
