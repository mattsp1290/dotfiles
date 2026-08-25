from __future__ import annotations

import argparse
from typing import Any, cast

from pr_loop_model import (
    FEEDBACK_PROCESSING_TRANSITIONS,
    FEEDBACK_STREAMS,
    OUTBOX_REQUIRED_BY_KIND,
    HelperError,
    digest_json,
    feedback_identity_digest,
    normalized_feedback,
    require,
    require_current_review_gate,
    utc_now,
)
from pr_loop_store import check_cas, commit_mutation, load_state


def bind_feedback_context(state: dict[str, Any], record: dict[str, Any]) -> dict[str, Any]:
    bound = dict(record)
    bound["repository_id"] = state["repository"]["repository_id"]
    current = state.get("current", {})
    if isinstance(current.get("entry_id"), str) and current["entry_id"]:
        bound["entry_id"] = current["entry_id"]
    if isinstance(current.get("pr_number"), int) and current["pr_number"] >= 1:
        bound["pr_number"] = current["pr_number"]
    return bound

def command_feedback_check(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    _, state = load_state(args)
    stream, item_id, record = normalized_feedback(payload)
    record = bind_feedback_context(state, record)
    previous = state["feedback"][stream].get(item_id)
    identity_keys = (
        {"id", "body_digest", "classification", "submitted_at", "state", "repository_id", "entry_id", "pr_number"}
        if stream == "reviews"
        else {"id", "body_digest", "classification", "updated_at", "repository_id", "entry_id", "pr_number"}
    )
    previous_identity = {key: previous.get(key) for key in identity_keys} if previous else None
    current_identity = {key: record.get(key) for key in identity_keys}
    return {"ok": True, "unseen": previous_identity != current_identity, "previous": previous}


def command_feedback_record(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    path, state = load_state(args)
    check_cas(state, args)
    stream, item_id, record = normalized_feedback(payload)
    record = bind_feedback_context(state, record)
    previous = state["feedback"][stream].get(item_id)
    if previous is None:
        require(record["processing_state"] == "seen", "new feedback must begin at seen", 4)
    else:
        identity_keys = (
            {"id", "body_digest", "classification", "submitted_at", "state", "repository_id", "entry_id", "pr_number"}
            if stream == "reviews"
            else {"id", "body_digest", "classification", "updated_at", "repository_id", "entry_id", "pr_number"}
        )
        same_identity = all(previous.get(key) == record.get(key) for key in identity_keys)
        if same_identity:
            require(
                record["processing_state"] in FEEDBACK_PROCESSING_TRANSITIONS[previous.get("processing_state", "seen")],
                "illegal feedback processing transition",
                4,
            )
        else:
            require(record["processing_state"] == "seen", "edited feedback must restart at seen", 4)
    mapped_later = record["processing_state"] == "disposed" and isinstance(record.get("mapped_entry_id"), str)
    if mapped_later:
        source_entry = next(
            (item for item in state["queue"] if item.get("entry_id") == record.get("entry_id")),
            None,
        )
        target_entry = next(
            (item for item in state["queue"] if item.get("entry_id") == record.get("mapped_entry_id")),
            None,
        )
        require(record["classification"] == "code-change", "only code-change feedback may map to a later entry", 4)
        require(isinstance(source_entry, dict) and source_entry.get("status") == "merged", "mapped feedback source is not merged", 4)
        require(
            isinstance(target_entry, dict)
            and target_entry.get("status") == "queued"
            and target_entry.get("workflow_kind") is None,
            "mapped feedback target is not an ordinary queued entry",
            4,
        )
        source_entry = cast(dict[str, Any], source_entry)
        target_entry = cast(dict[str, Any], target_entry)
        require(target_entry["sequence"] > source_entry["sequence"], "mapped feedback target is not later", 4)
        require(
            target_entry.get("contract_digest") == record.get("mapped_entry_contract_digest"),
            "mapped feedback target contract is stale",
            4,
        )
    if (
        not mapped_later
        and record["processing_state"] in {"replied", "disposed"}
        and record["classification"] in {"code-change", "question"}
    ):
        operation_id = record["outbound_operation_id"]
        reply = next((item for item in state["outbox"] if item.get("operation_id") == operation_id), None)
        require(
            isinstance(reply, dict)
            and reply.get("kind") == "comment-reply"
            and reply.get("status") in {"resolved", "cancelled-human-resolved"}
            and reply.get("target") == f"{stream}:{item_id}"
            and reply.get("feedback_identity_digest") == feedback_identity_digest(stream, record),
            "feedback reply must reference a terminal comment-reply outbox",
            4,
        )
    if (
        not mapped_later
        and record["classification"] == "code-change"
        and record["processing_state"] in {"replied", "disposed"}
    ):
        operation_id = record.get("review_request_operation_id")
        if isinstance(operation_id, str) and operation_id:
            request = next((item for item in state["outbox"] if item.get("operation_id") == operation_id), None)
            bindings = operation_feedback_bindings(request) if isinstance(request, dict) else []
            require(
                isinstance(request, dict)
                and request.get("kind") == "review-request"
                and request.get("status") in {"resolved", "cancelled-human-resolved"}
                and (f"{stream}:{item_id}", feedback_identity_digest(stream, record)) in bindings
                and request.get("expected_head_sha") == record.get("commit_sha"),
                "code feedback must reference a resolved review-request outbox",
                4,
            )
        else:
            entry_id = state["current"].get("entry_id")
            queue_entry = next((item for item in state["queue"] if item.get("entry_id") == entry_id), None)
            terminal_evidence = queue_entry.get("terminal_evidence", {}) if isinstance(queue_entry, dict) else {}
            contract_digest = queue_entry.get("contract_digest") if isinstance(queue_entry, dict) else None
            pr_record = state["prs"].get(entry_id, {})
            approval = next(
                (
                    item
                    for item in state["exception_approvals"]
                    if item.get("approval_id") == record.get("review_exception_approval_id")
                    and item.get("kind") == "merged-feedback-race"
                    and item.get("entry_id") == entry_id
                    and item.get("contract_digest") == contract_digest
                    and item.get("summary_digest") == record.get("human_disposition_digest")
                    and item.get("merge_sha") == record.get("merge_commit_sha")
                    and item.get("verification_digest") == record.get("merge_evidence_digest")
                    and item.get("feedback_identity_digest") == feedback_identity_digest(stream, record)
                ),
                None,
            )
            require(
                isinstance(queue_entry, dict)
                and queue_entry.get("status") == "merged"
                and terminal_evidence.get("merge_sha") == record.get("merge_commit_sha")
                and terminal_evidence.get("verification_digest") == record.get("merge_evidence_digest")
                and terminal_evidence.get("review_exception_approval_id") == record.get("review_exception_approval_id")
                and terminal_evidence.get("human_disposition_digest") == record.get("human_disposition_digest")
                and pr_record.get("merge_sha") == record.get("merge_commit_sha")
                and isinstance(approval, dict),
                "merged feedback without review request lacks verified merge-race approval evidence",
                4,
            )
    state["feedback"][stream][item_id] = record
    state["history"].append({"event": "feedback-recorded", "stream": stream, "id": item_id, "at": utc_now()})
    return commit_mutation(path, state)


def sanitize_outbox(operation: Any) -> dict[str, Any]:
    require(isinstance(operation, dict), "operation object required")
    allowed = {
        "operation_id",
        "kind",
        "repository_id",
        "pr_number",
        "base_ref",
        "head_ref",
        "expected_head_sha",
        "expected_base_oid",
        "target",
        "feedback_target",
        "feedback_identity_digest",
        "feedback_targets",
        "feedback_identity_digests",
        "marker",
        "input_digest",
        "intent_at",
    }
    require(set(operation).issubset(allowed), "outbox operation contains unsupported fields")
    for key in ("operation_id", "kind", "repository_id"):
        require(isinstance(operation.get(key), str) and operation[key], f"operation.{key} required")
    require(operation.get("kind") in {"pr-create", "comment-reply", "review-request"}, "unsupported outbox operation kind")
    kind = operation["kind"]
    for key in OUTBOX_REQUIRED_BY_KIND[kind]:
        require(operation.get(key) is not None and operation.get(key) != "", f"{kind} operation.{key} required")
    result = {key: operation.get(key) for key in allowed if key in operation}
    plural_targets = result.get("feedback_targets")
    plural_digests = result.get("feedback_identity_digests")
    if plural_targets is not None or plural_digests is not None:
        require(kind == "review-request", "batched feedback is allowed only for review requests")
        require(
            isinstance(plural_targets, list)
            and isinstance(plural_digests, list)
            and len(plural_targets) == len(plural_digests)
            and len(plural_targets) >= 1,
            "batched feedback targets and digests must be equal nonempty lists",
        )
        plural_targets = cast(list[Any], plural_targets)
        plural_digests = cast(list[Any], plural_digests)
        pairs = list(zip(plural_targets, plural_digests, strict=True))
        require(
            all(isinstance(target, str) and target and isinstance(digest, str) and digest for target, digest in pairs),
            "batched feedback bindings must be nonempty strings",
        )
        require(len({target for target, _ in pairs}) == len(pairs), "batched feedback targets must be unique")
        pairs.sort()
        result["feedback_targets"] = [target for target, _ in pairs]
        result["feedback_identity_digests"] = [digest for _, digest in pairs]
        require(
            result.get("feedback_target") is None and result.get("feedback_identity_digest") is None,
            "use either singular or batched feedback binding",
        )
    result["intent_at"] = result.get("intent_at") or utc_now()
    result["status"] = "pending"
    return result


def operation_feedback_bindings(operation: dict[str, Any]) -> list[tuple[str, str]]:
    if operation.get("kind") == "comment-reply":
        target = operation.get("target")
        digest = operation.get("feedback_identity_digest")
        return [(target, digest)] if isinstance(target, str) and isinstance(digest, str) else []
    targets = operation.get("feedback_targets")
    digests = operation.get("feedback_identity_digests")
    if isinstance(targets, list) and isinstance(digests, list):
        require(len(targets) == len(digests), "batched feedback binding length mismatch", 4)
        return list(zip(targets, digests, strict=True))
    target = operation.get("feedback_target")
    digest = operation.get("feedback_identity_digest")
    return [(target, digest)] if isinstance(target, str) and isinstance(digest, str) else []


def require_feedback_operation_binding(
    state: dict[str, Any], operation: dict[str, Any], *, require_current_pr: bool = True
) -> None:
    bindings = operation_feedback_bindings(operation)
    if not bindings:
        return
    for target, supplied_digest in bindings:
        require(":" in target, "outbox feedback target is invalid", 4)
        stream, item_id = target.split(":", 1)
        require(stream in FEEDBACK_STREAMS and item_id in state["feedback"][stream], "outbox feedback identity is unknown", 4)
        record = state["feedback"][stream][item_id]
        expected = feedback_identity_digest(stream, record)
        require(supplied_digest == expected, "outbox feedback identity digest is stale", 4)
        require(record.get("repository_id") == state["repository"]["repository_id"], "feedback repository is stale", 4)
        if require_current_pr:
            current = state.get("current", {})
            require(record.get("entry_id") == current.get("entry_id"), "feedback entry is not current", 4)
            require(record.get("pr_number") == current.get("pr_number"), "feedback PR is not current", 4)
            require(operation.get("pr_number") == current.get("pr_number"), "outbox PR target is not current", 4)


def require_outbox_repository_binding(state: dict[str, Any], operation: dict[str, Any]) -> None:
    require(
        operation.get("repository_id") == state["repository"]["repository_id"],
        "outbox repository identity mismatch",
        4,
    )


def command_outbox_begin(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    path, state = load_state(args)
    check_cas(state, args)
    raw_operation = payload.get("operation")
    require(isinstance(raw_operation, dict), "operation object required")
    raw_operation = cast(dict[str, Any], raw_operation)
    operation_id = raw_operation.get("operation_id")
    existing = next((item for item in state["outbox"] if item["operation_id"] == operation_id), None)
    if existing is not None and "intent_at" not in raw_operation:
        raw_operation = dict(raw_operation)
        raw_operation["intent_at"] = existing.get("intent_at")
    operation = sanitize_outbox(raw_operation)
    require_outbox_repository_binding(state, operation)
    if operation["kind"] == "comment-reply" or operation_feedback_bindings(operation):
        require_feedback_operation_binding(
            state,
            operation,
            require_current_pr=isinstance(state.get("current", {}).get("pr_number"), int),
        )
    if operation["kind"] == "pr-create":
        require(state["phase"] == "publishing", "PR creation is allowed only in publishing", 4)
        entry_id = state["current"].get("entry_id")
        require(isinstance(entry_id, str) and entry_id, "PR creation requires a current entry", 4)
        queue_entry = next(entry for entry in state["queue"] if entry["entry_id"] == entry_id)
        require(queue_entry.get("status") == "publishing", "PR creation queue entry is not publishing", 4)
        require(operation["base_ref"] == state["repository"]["base_branch"], "PR creation base ref mismatch", 4)
        require(operation["head_ref"] == state["current"].get("branch"), "PR creation head ref mismatch", 4)
        require_current_review_gate(state, entry_id, operation["expected_base_oid"], operation["expected_head_sha"])
    elif operation["kind"] == "review-request":
        require(
            state["phase"] in {"publishing", "addressing-feedback"},
            "review request is allowed only while publishing or addressing feedback",
            4,
        )
        pr_number = operation["pr_number"]
        matching = [
            (entry_id, record)
            for entry_id, record in state["prs"].items()
            if record.get("pr_number") == pr_number
        ]
        require(len(matching) == 1, "review request must match exactly one persisted PR", 4)
        entry_id, record = matching[0]
        base_sha = operation["expected_base_oid"]
        head_sha = operation["expected_head_sha"]
        require(base_sha == record.get("reviewed_base_sha"), "review request expected base is stale", 4)
        require(head_sha == record.get("local_head_sha"), "review request expected head is stale", 4)
        require(isinstance(base_sha, str) and base_sha, "review request lacks reviewed base", 4)
        require(isinstance(head_sha, str) and head_sha, "review request lacks reviewed head", 4)
        require_current_review_gate(state, entry_id, base_sha, head_sha)
    if existing is not None:
        intent_keys = set(operation) - {"status"}
        require(
            {key: existing.get(key) for key in intent_keys} == {key: operation.get(key) for key in intent_keys},
            "outbox operation ID reused with different intent",
            3,
        )
        return {
            "ok": True,
            "idempotent": True,
            "state_revision": state["state_revision"],
            "phase": state["phase"],
        }
    logical_fields = {
        key: operation.get(key)
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
    require(
        not any(item.get("logical_digest") == logical_digest for item in state["outbox"]),
        "duplicate logical outbox operation",
        3,
    )
    operation["logical_digest"] = logical_digest
    state["outbox"].append(operation)
    state["history"].append({"event": "outbox-begin", "operation_id": operation["operation_id"], "kind": operation["kind"], "at": utc_now()})
    result = commit_mutation(path, state)
    result["idempotent"] = False
    return result


def command_outbox_authorize(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    path, state = load_state(args)
    check_cas(state, args)
    operation_id = payload.get("operation_id")
    require(isinstance(operation_id, str) and operation_id, "operation_id required")
    operation = next((item for item in state["outbox"] if item["operation_id"] == operation_id), None)
    require(isinstance(operation, dict), "outbox operation not found", 2)
    operation = cast(dict[str, Any], operation)
    require(operation.get("status") == "pending", "only a pending outbox operation may be authorized", 4)
    require_outbox_repository_binding(state, operation)
    gate_digest: str | None = None
    if operation["kind"] == "pr-create":
        require(state["phase"] == "publishing", "PR creation authorization requires publishing", 4)
        entry_id = state["current"].get("entry_id")
        require(isinstance(entry_id, str) and entry_id, "PR creation authorization lacks current entry", 4)
        gate = require_current_review_gate(
            state, entry_id, operation["expected_base_oid"], operation["expected_head_sha"]
        )
        require(operation["base_ref"] == state["repository"]["base_branch"], "PR creation base ref moved", 4)
        require(operation["head_ref"] == state["current"].get("branch"), "PR creation head ref moved", 4)
        gate_digest = digest_json(gate)
    elif operation["kind"] == "review-request":
        require(
            state["phase"] in {"publishing", "addressing-feedback"},
            "review request authorization is outside a publication phase",
            4,
        )
        matching = [
            (entry_id, record)
            for entry_id, record in state["prs"].items()
            if record.get("pr_number") == operation["pr_number"]
        ]
        require(len(matching) == 1, "review request authorization lacks exact PR metadata", 4)
        entry_id, record = matching[0]
        require(entry_id == state["current"].get("entry_id"), "review request PR is not current", 4)
        require(operation["expected_base_oid"] == record.get("reviewed_base_sha"), "review request base moved", 4)
        require(operation["expected_head_sha"] == record.get("local_head_sha"), "review request head moved", 4)
        gate = require_current_review_gate(
            state, entry_id, operation["expected_base_oid"], operation["expected_head_sha"]
        )
        gate_digest = digest_json(gate)
        if operation_feedback_bindings(operation):
            require_feedback_operation_binding(state, operation)
    else:
        require(state["phase"] == "addressing-feedback", "comment reply authorization requires addressing-feedback", 4)
        require_feedback_operation_binding(state, operation)
    operation["status"] = "authorized"
    operation["authorized_at"] = utc_now()
    operation["authorized_state_revision"] = state["state_revision"] + 1
    operation["authorized_gate_digest"] = gate_digest
    state["history"].append(
        {"event": "outbox-authorized", "operation_id": operation_id, "kind": operation["kind"], "at": utc_now()}
    )
    return commit_mutation(path, state)


def command_outbox_resolve(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    path, state = load_state(args)
    check_cas(state, args)
    operation_id = payload.get("operation_id")
    require(isinstance(operation_id, str) and operation_id, "operation_id required")
    operation = next((item for item in state["outbox"] if item["operation_id"] == operation_id), None)
    if operation is None:
        raise HelperError("outbox operation not found", 2)
    status = payload.get("status", "resolved")
    require(
        status in {"resolved", "ambiguous", "cancelled-before-attempt", "cancelled-human-resolved"},
        "invalid outbox status",
    )
    prior_status = operation.get("status")
    if prior_status in {"resolved", "cancelled-before-attempt", "cancelled-human-resolved"} or (
        prior_status == "ambiguous" and status == "ambiguous"
    ):
        same_resolution = (
            operation.get("status") == status
            and operation.get("remote_id") == payload.get("remote_id")
            and operation.get("evidence_digest") == payload.get("evidence_digest")
            and operation.get("attempted") == payload.get("attempted")
            and operation.get("human_disposition_digest") == payload.get("human_disposition_digest")
            and operation.get("reconciliation_digest") == payload.get("reconciliation_digest")
        )
        require(same_resolution, "outbox operation already resolved differently", 3)
        return {
            "ok": True,
            "idempotent": True,
            "state_revision": state["state_revision"],
            "phase": state["phase"],
        }
    if status == "resolved":
        require(isinstance(operation.get("authorized_at"), str) and operation["authorized_at"], "resolved operation lacks execution authorization", 4)
        require(isinstance(payload.get("evidence_digest"), str) and payload["evidence_digest"], "resolved outbox requires evidence_digest")
        if operation.get("kind") in {"pr-create", "comment-reply"}:
            require(payload.get("remote_id") is not None and payload.get("remote_id") != "", "resolved operation requires remote_id")
    elif status == "cancelled-before-attempt":
        require(prior_status == "pending", "only a never-authorized operation may be cancelled before attempt", 4)
        require(payload.get("attempted") is False, "cancelled-before-attempt requires attempted=false")
        require(isinstance(payload.get("evidence_digest"), str) and payload["evidence_digest"], "cancellation evidence required")
    elif status == "cancelled-human-resolved":
        require(
            isinstance(operation.get("authorized_at"), str) and operation["authorized_at"],
            "human-resolved cancellation lacks execution authorization",
            4,
        )
        require(payload.get("attempted") is True, "cancelled-human-resolved requires attempted=true")
        for evidence_key in ("evidence_digest", "human_disposition_digest", "reconciliation_digest"):
            require(isinstance(payload.get(evidence_key), str) and payload[evidence_key], f"{evidence_key} required")
    elif status == "ambiguous":
        require(isinstance(operation.get("authorized_at"), str) and operation["authorized_at"], "ambiguous operation lacks execution authorization", 4)
        require(payload.get("attempted") is True, "ambiguous operation requires attempted=true")
        require(isinstance(payload.get("evidence_digest"), str) and payload["evidence_digest"], "ambiguity evidence required")
    if prior_status == "ambiguous" and status != "ambiguous":
        require(status in {"resolved", "cancelled-human-resolved"}, "invalid ambiguity reconciliation", 4)
    operation.update(
        {
            "status": status,
            "remote_id": payload.get("remote_id"),
            "evidence_digest": payload.get("evidence_digest"),
            "attempted": payload.get("attempted"),
            "human_disposition_digest": payload.get("human_disposition_digest"),
            "reconciliation_digest": payload.get("reconciliation_digest"),
            "resolved_at": utc_now(),
        }
    )
    if operation.get("status") == "ambiguous":
        operation["ambiguous_at"] = operation["resolved_at"]
        operation["ambiguity_evidence_digest"] = operation["evidence_digest"]
    state["history"].append({"event": "outbox-resolve", "operation_id": operation_id, "status": status, "at": utc_now()})
    result = commit_mutation(path, state)
    result["idempotent"] = False
    return result


def command_approval_check(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    _, state = load_state(args)
    entry_id = payload.get("entry_id")
    require(isinstance(entry_id, str) and entry_id, "entry_id required")
    queue_by_id = {entry["entry_id"]: entry for entry in state["queue"]}
    require(entry_id in queue_by_id, "approval entry_id is not present in queue")
    digest = queue_by_id[entry_id]["contract_digest"]
    supplied_digest = payload.get("contract_digest")
    if supplied_digest is not None:
        require(isinstance(supplied_digest, str) and supplied_digest, "contract_digest must be nonempty")
        if supplied_digest != digest:
            return {"ok": True, "approved": False, "approval": None, "current_contract_digest": digest}
    approval = next(
        (
            item
            for item in reversed(state["exception_approvals"])
            if item.get("entry_id") == entry_id and item.get("contract_digest") == digest
            and item.get("kind", "scope-exception") == "scope-exception"
        ),
        None,
    )
    return {"ok": True, "approved": approval is not None, "approval": approval}


def command_approval_record(args: argparse.Namespace, payload: dict[str, Any]) -> dict[str, Any]:
    path, state = load_state(args)
    check_cas(state, args)
    allowed = {
        "approval_id",
        "kind",
        "entry_id",
        "contract_digest",
        "approver",
        "approved_at",
        "summary_digest",
        "merge_sha",
        "verification_digest",
        "feedback_identity_digest",
    }
    require(set(payload).issubset(allowed), "approval contains unsupported fields")
    for key in ("approval_id", "entry_id", "contract_digest", "approver", "summary_digest"):
        require(isinstance(payload.get(key), str) and payload[key], f"approval.{key} required")
    kind = payload.get("kind", "scope-exception")
    require(kind in {"scope-exception", "merged-feedback-race"}, "approval.kind is invalid")
    if kind == "merged-feedback-race":
        for key in ("merge_sha", "verification_digest", "feedback_identity_digest"):
            require(isinstance(payload.get(key), str) and payload[key], f"approval.{key} required for merge race")
    queue_ids = {entry["entry_id"] for entry in state["queue"]}
    require(payload["entry_id"] in queue_ids, "approval entry_id is not present in queue")
    queue_by_id = {entry["entry_id"]: entry for entry in state["queue"]}
    require(payload["contract_digest"] == queue_by_id[payload["entry_id"]]["contract_digest"], "approval contract_digest is stale", 3)
    existing = next((item for item in state["exception_approvals"] if item.get("approval_id") == payload["approval_id"]), None)
    approval = {key: payload.get(key) for key in allowed if key in payload}
    approval["kind"] = kind
    approval["approved_at"] = approval.get("approved_at") or (existing or {}).get("approved_at") or utc_now()
    if existing is not None:
        comparable_existing = dict(existing)
        comparable_existing.setdefault("kind", "scope-exception")
        require(comparable_existing == approval, "approval ID reused with different data", 3)
        return {"ok": True, "idempotent": True, "state_revision": state["state_revision"], "phase": state["phase"]}
    state["exception_approvals"].append(approval)
    state["history"].append({"event": "approval-recorded", "approval_id": approval["approval_id"], "entry_id": approval["entry_id"], "at": utc_now()})
    result = commit_mutation(path, state)
    result["idempotent"] = False
    return result
