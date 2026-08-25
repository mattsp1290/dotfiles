#!/usr/bin/env python3

from __future__ import annotations

import json
import hashlib
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from typing import Any


SKILL_ROOT = Path(__file__).resolve().parents[1]
HELPER = SKILL_ROOT / "scripts" / "pr_loop_state.py"
MONITOR = SKILL_ROOT / "scripts" / "monitor_pr.py"
FAKE_GH = SKILL_ROOT / "evals" / "fake-gh.py"
FIXTURES = Path(__file__).resolve().parent / "fixtures"
STATE_MUTATIONS = {
    "init",
    "bind-lease",
    "transition",
    "record-requirements",
    "record-queue",
    "record-coverage",
    "record-plan",
    "record-pr",
    "record-application-context",
    "record-acceptance",
    "record-review-isolation",
    "record-review-gate",
    "feedback-record",
    "outbox-begin",
    "outbox-authorize",
    "outbox-resolve",
    "approval-record",
}


class HelperTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.lock = self.root / "common" / "plan-pr-loop" / "lock"
        self.state = self.root / "common" / "plan-pr-loop" / "runs" / "stable-plan" / "state.json"
        self.owner = "owner-A"
        self.executor = "executor-A"

        self.assert_ok(
            "lock-init",
            lock=self.lock,
            owner_token=self.owner,
            repository_id="repo-1",
            stable_plan_id="stable-plan",
            plan_digest="digest-v1",
            goal_id="goal-1",
        )
        lease = self.assert_ok(
            "lease-acquire",
            lock=self.lock,
            owner_token=self.owner,
            executor_id=self.executor,
        )
        self.fence = lease["fencing_token"]
        self.assert_ok(
            "init",
            state=self.state,
            fencing_token=self.fence,
            payload={
                "plan": {
                    "stable_id": "stable-plan",
                    "canonical_path": ".agents/plans/example",
                    "digest": "digest-v1",
                    "files": [{"path": "00-overview.md", "sha256": "file-digest"}],
                },
                "repository": {
                    "repository_id": "repo-1",
                    "base_branch": "main",
                    "last_verified_base_sha": "base-sha",
                },
                "application_context": {
                    "has_active_users": False,
                    "backward_compatibility_required": False,
                    "feature_flags": "not-applicable",
                    "confirmation_digest": "context-confirmation-v1",
                    "confirmed_at": "2026-08-22T12:00:00Z",
                },
            },
        )

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def run_helper(
        self,
        command: str,
        *,
        state: Path | None = None,
        lock: Path | None = None,
        payload: dict | None = None,
        expected_revision: int | None = None,
        expected_phase: str | None = None,
        fencing_token: int | None = None,
        owner_token: str | None = None,
        repository_id: str | None = None,
        stable_plan_id: str | None = None,
        plan_digest: str | None = None,
        goal_id: str | None = None,
        executor_id: str | None = None,
    ) -> subprocess.CompletedProcess[str]:
        if command in STATE_MUTATIONS and state is not None:
            lock = lock or self.lock
            owner_token = owner_token or self.owner
            executor_id = executor_id or self.executor
        arguments = [os.fspath(HELPER), command]
        values = {
            "state": state,
            "lock": lock,
            "expected-revision": expected_revision,
            "expected-phase": expected_phase,
            "fencing-token": fencing_token,
            "owner-token": owner_token,
            "repository-id": repository_id,
            "stable-plan-id": stable_plan_id,
            "plan-digest": plan_digest,
            "goal-id": goal_id,
            "executor-id": executor_id,
        }
        for flag, value in values.items():
            if value is not None:
                arguments.extend([f"--{flag}", os.fspath(value) if isinstance(value, Path) else str(value)])
        if payload is not None:
            arguments.extend(["--input-json", json.dumps(payload, sort_keys=True)])
        return subprocess.run(arguments, text=True, capture_output=True, check=False)

    def assert_ok(self, command: str, **kwargs: Any) -> dict:
        result = self.run_helper(command, **kwargs)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        return json.loads(result.stdout)

    def state_data(self) -> dict:
        return json.loads(self.state.read_text(encoding="utf-8"))

    def transition(self, revision: int, source: str, destination: str) -> dict:
        return self.assert_ok(
            "transition",
            state=self.state,
            expected_revision=revision,
            expected_phase=source,
            fencing_token=self.fence,
            payload={"to_phase": destination, "reason": f"test {source} to {destination}"},
        )

    def requirement(
        self,
        requirement_id: str,
        *,
        dependencies: list[str] | None = None,
        status: str = "in-scope",
    ) -> dict:
        return {
            "requirement_id": requirement_id,
            "source": {"file": "01-work.md", "heading_path": ["Work"], "ordinal": 1},
            "content_digest": f"digest-{requirement_id}",
            "behavior": f"Observable behavior for {requirement_id}",
            "acceptance": [f"Verify {requirement_id}"],
            "dependencies": dependencies or [],
            "proposed_locations": ["src/example.txt"],
            "verification": [f"Run verification for {requirement_id}"],
            "risk": "low and reversible",
            "classification": "reviewer-written",
            "remaining_decision": None,
            "status": status,
        }

    def queue_entry(
        self,
        entry_id: str,
        requirement_ids: list[str],
        sequence: int,
        **overrides: Any,
    ) -> dict[str, Any]:
        entry: dict[str, Any] = {
            "entry_id": entry_id,
            "revision": 1,
            "supersedes": [],
            "split_into": [],
            "sequence": sequence,
            "slug": entry_id.removeprefix("pr-") or "change",
            "title": f"Implement {entry_id}",
            "requirement_ids": requirement_ids,
            "prerequisites": [],
            "purpose": f"Deliver {entry_id}",
            "included_paths": ["src/example.txt"],
            "excluded_work": [],
            "acceptance": [f"Verify {entry_id}"],
            "validation": ["run tests"],
            "estimated_review_shape": {
                "human_written_lines": "small",
                "generated_lines": "none",
                "files": "small",
            },
            "exception_required": False,
            "exception_reason": None,
            "status": "queued",
        }
        entry.update(overrides)
        return entry

    def review_gate(self, entry_id: str, base_sha: str, head_sha: str, contract_digest: str) -> dict[str, Any]:
        return {
            "entry_id": entry_id,
            "base_sha": base_sha,
            "head_sha": head_sha,
            "contract_digest": contract_digest,
            "reviewer_artifact_digests": {"boundary": "review-a", "isolation": "review-b"},
            "critical_important_dispositions_digest": "ci-dispositions",
            "thermo_artifact_digest": "thermo-artifact",
            "thermo_dispositions_digest": "thermo-dispositions",
            "validation_digest": "validation",
            "fix_commit_sha": head_sha,
            "verified_remote_head_sha": head_sha,
        }

    def feedback_digest(self, stream: str, item: dict[str, Any]) -> str:
        bound = dict(item)
        state = self.state_data()
        bound["repository_id"] = state["repository"]["repository_id"]
        current = state.get("current", {})
        if isinstance(current.get("entry_id"), str) and current["entry_id"]:
            bound["entry_id"] = current["entry_id"]
        if isinstance(current.get("pr_number"), int) and current["pr_number"] >= 1:
            bound["pr_number"] = current["pr_number"]
        keys = (
            ("id", "body_digest", "classification", "submitted_at", "state")
            if stream == "reviews"
            else ("id", "body_digest", "classification", "updated_at")
        )
        keys = (*keys, "repository_id", "entry_id", "pr_number")
        value = {
            "domain": "plan-pr-loop-feedback-identity-v1",
            "stream": stream,
            "identity": {key: bound.get(key) for key in keys},
        }
        encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        return hashlib.sha256(encoded).hexdigest()

    def record_requirements(self, revision: int, requirements: list[dict]) -> dict:
        return self.assert_ok(
            "record-requirements",
            state=self.state,
            expected_revision=revision,
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"requirements": requirements, "reason": "test inventory"},
        )

    def seed_single_queue(self, *, include_devex: bool = True) -> dict:
        requirements = [self.requirement("R1")]
        queue = [self.queue_entry("pr-one", ["R1"], 1)]
        if include_devex:
            devex_requirement = self.requirement("R-devex", dependencies=["R1"])
            devex_requirement["source"]["file"] = "skill://plan-pr-loop/devex-retrospective"
            devex_requirement["behavior"] = "Assess and, if useful, improve repository agent guidance"
            devex_requirement["proposed_locations"] = ["AGENTS.md", ".agents/"]
            requirements.append(devex_requirement)
            queue.append(
                self.queue_entry(
                    "pr-devex",
                    ["R-devex"],
                    2,
                    workflow_kind="devex-retrospective",
                    prerequisites=["pr-one"],
                    included_paths=["AGENTS.md", ".agents/**"],
                    purpose="Run the final DevEx retrospective",
                )
            )
        inventory = self.record_requirements(1, requirements)
        return self.assert_ok(
            "record-queue",
            state=self.state,
            expected_revision=inventory["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={
                "queue": queue,
                "reason": "test queue",
            },
        )

    def seed_two_ordinary_queue(self) -> dict:
        devex_requirement = self.requirement("R-devex", dependencies=["R1", "R2"])
        devex_requirement["source"]["file"] = "skill://plan-pr-loop/devex-retrospective"
        inventory = self.record_requirements(
            1,
            [self.requirement("R1"), self.requirement("R2"), devex_requirement],
        )
        queue = [
            self.queue_entry("pr-one", ["R1"], 1),
            self.queue_entry("pr-two", ["R2"], 2, prerequisites=["pr-one"]),
            self.queue_entry(
                "pr-devex",
                ["R-devex"],
                3,
                workflow_kind="devex-retrospective",
                prerequisites=["pr-one", "pr-two"],
                included_paths=["AGENTS.md", ".agents/**"],
            ),
        ]
        return self.assert_ok(
            "record-queue",
            state=self.state,
            expected_revision=inventory["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"queue": queue, "reason": "test two-entry queue"},
        )

    def finish_seeded_single_queue(self, revision: int, *, finish_retrospective: bool = True) -> dict:
        base_sha = "b" * 40
        head_sha = "a" * 40
        current = self.assert_ok(
            "record-pr",
            state=self.state,
            expected_revision=revision,
            expected_phase="queued",
            fencing_token=self.fence,
            payload={
                "current": {
                    "entry_id": "pr-one",
                    "sequence": 1,
                    "branch": "plan-pr/01-one",
                    "base_sha": base_sha,
                    "reviewed_base_sha": base_sha,
                    "local_head_sha": head_sha,
                    "remote_head_sha": head_sha,
                }
            },
        )
        revision = current["state_revision"]
        phase = "queued"
        for status in ("implementing", "internal-review"):
            entry = self.state_data()["queue"][0]
            entry["revision"] += 1
            entry["status"] = status
            changed = self.assert_ok(
                "record-queue",
                state=self.state,
                expected_revision=revision,
                expected_phase=phase,
                fencing_token=self.fence,
                payload={"queue": self.queue_with_entry(entry), "reason": f"advance to {status}"},
            )
            revision = changed["state_revision"]
            transitioned = self.transition(revision, phase, status)
            revision = transitioned["state_revision"]
            phase = status
        gate = self.assert_ok(
            "record-review-gate",
            state=self.state,
            expected_revision=revision,
            expected_phase="internal-review",
            fencing_token=self.fence,
            payload=self.review_gate(
                "pr-one",
                base_sha,
                head_sha,
                self.state_data()["queue"][0]["contract_digest"],
            ),
        )
        revision = gate["state_revision"]
        for status in ("publishing", "awaiting-human-review", "awaiting-merge"):
            entry = self.state_data()["queue"][0]
            entry["revision"] += 1
            entry["status"] = status
            changed = self.assert_ok(
                "record-queue",
                state=self.state,
                expected_revision=revision,
                expected_phase=phase,
                fencing_token=self.fence,
                payload={"queue": self.queue_with_entry(entry), "reason": f"advance to {status}"},
            )
            revision = changed["state_revision"]
            transitioned = self.transition(revision, phase, status)
            revision = transitioned["state_revision"]
            phase = status
        merge_sha = head_sha
        pr_record = self.assert_ok(
            "record-pr",
            state=self.state,
            expected_revision=revision,
            expected_phase="awaiting-merge",
            fencing_token=self.fence,
            payload={
                "current": {
                    "entry_id": "pr-one",
                    "pr_number": 1,
                    "merge_sha": merge_sha,
                    "merged_at": "2026-08-22T13:00:00Z",
                }
            },
        )
        revision = pr_record["state_revision"]
        entry = self.state_data()["queue"][0]
        entry["revision"] += 1
        entry["status"] = "merged"
        entry["terminal_evidence"] = {
            "pr_number": 1,
            "merge_sha": merge_sha,
            "base_sha": base_sha,
            "verification_digest": "merged-verification",
        }
        merged = self.assert_ok(
            "record-queue",
            state=self.state,
            expected_revision=revision,
            expected_phase="awaiting-merge",
            fencing_token=self.fence,
            payload={"queue": self.queue_with_entry(entry), "reason": "record verified merge"},
        )
        covered = self.assert_ok(
            "record-coverage",
            state=self.state,
            expected_revision=merged["state_revision"],
            expected_phase="awaiting-merge",
            fencing_token=self.fence,
            payload={"requirement_id": "R1", "status": "merged"},
        )
        if not finish_retrospective:
            return covered
        revision = covered["state_revision"]
        retrospective = next(
            (item for item in self.state_data()["queue"] if item.get("workflow_kind") == "devex-retrospective"),
            None,
        )
        self.assertIsNotNone(retrospective)
        artifact, artifact_digest = self.write_devex_artifact("No durable repository-guidance change was justified.\n")
        retrospective["revision"] += 1
        retrospective["status"] = "satisfied-by-base"
        retrospective["terminal_evidence"] = {
            "verification_digest": artifact_digest,
            "outcome": "no-change",
            "retrospective_artifact": artifact,
            "retrospective_artifact_digest": artifact_digest,
        }
        retrospective_done = self.assert_ok(
            "record-queue",
            state=self.state,
            expected_revision=revision,
            expected_phase="awaiting-merge",
            fencing_token=self.fence,
            payload={"queue": self.queue_with_entry(retrospective), "reason": "record no-change DevEx retrospective"},
        )
        devex_covered = self.assert_ok(
            "record-coverage",
            state=self.state,
            expected_revision=retrospective_done["state_revision"],
            expected_phase="awaiting-merge",
            fencing_token=self.fence,
            payload={"requirement_id": "R-devex", "status": "satisfied-by-base"},
        )
        accepted = self.assert_ok(
            "record-acceptance",
            state=self.state,
            expected_revision=devex_covered["state_revision"],
            expected_phase="awaiting-merge",
            fencing_token=self.fence,
            payload={"status": "passed", "evidence_digest": "final-acceptance", "base_sha": base_sha},
        )
        return self.transition(accepted["state_revision"], "awaiting-merge", "complete")

    def queue_with_entry(self, replacement: dict[str, Any]) -> list[dict[str, Any]]:
        queue = self.state_data()["queue"]
        return [replacement if item["entry_id"] == replacement["entry_id"] else item for item in queue]

    def write_devex_artifact(self, content: str) -> tuple[str, str]:
        relative = "devex-retrospective.md"
        artifact = self.state.parent / relative
        artifact.write_text(content, encoding="utf-8")
        return relative, hashlib.sha256(artifact.read_bytes()).hexdigest()

    def test_stable_plan_identity_and_changed_digest_detection(self) -> None:
        result = self.assert_ok(
            "lock-init",
            lock=self.lock,
            owner_token=self.owner,
            repository_id="repo-1",
            stable_plan_id="stable-plan",
            plan_digest="digest-v2",
            goal_id="goal-1",
        )
        self.assertFalse(result["created"])
        self.assertFalse(result["plan_digest_matches"])
        self.assertEqual(self.state_data()["plan"]["stable_id"], "stable-plan")
        self.assertEqual(self.state_data()["plan"]["digest"], "digest-v1")

        reconciled = self.assert_ok(
            "record-plan",
            state=self.state,
            expected_revision=1,
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={
                "plan": {
                    "stable_id": "stable-plan",
                    "canonical_path": ".agents/plans/example",
                    "digest": "digest-v2",
                    "files": [{"path": "00-overview.md", "sha256": "file-digest-v2"}],
                },
                "reason": "human accepted revised plan before implementation",
                "approval_evidence_digest": "plan-change-approval-v1",
            },
        )
        self.assertEqual(reconciled["state_revision"], 2)
        self.assert_ok(
            "lock-update-plan",
            lock=self.lock,
            owner_token=self.owner,
            executor_id=self.executor,
            fencing_token=self.fence,
            plan_digest="digest-v2",
        )
        verified = self.assert_ok(
            "lock-init",
            lock=self.lock,
            owner_token=self.owner,
            repository_id="repo-1",
            stable_plan_id="stable-plan",
            plan_digest="digest-v2",
            goal_id="goal-1",
        )
        self.assertTrue(verified["plan_digest_matches"])

    def test_atomic_failure_preserves_prior_state_and_ignores_stale_temp(self) -> None:
        before = self.state.read_bytes()
        stale = self.state.parent / f".{self.state.name}.stale.tmp"
        stale.write_text("not json", encoding="utf-8")
        result = self.run_helper(
            "transition",
            state=self.state,
            expected_revision=1,
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"to_phase": "publishing", "reason": "illegal jump"},
        )
        self.assertEqual(result.returncode, 4)
        self.assertEqual(before, self.state.read_bytes())
        self.assert_ok("validate", state=self.state)

    def test_revision_phase_and_fencing_compare_and_set(self) -> None:
        seeded = self.seed_single_queue()
        transition = self.transition(seeded["state_revision"], "preflight", "queued")
        self.assertEqual(transition["state_revision"], 4)
        stale = self.run_helper(
            "record-pr",
            state=self.state,
            expected_revision=3,
            expected_phase="queued",
            fencing_token=self.fence,
            payload={"current": {"branch": "plan-pr/01-example"}},
        )
        self.assertEqual(stale.returncode, 3)

        self.assert_ok(
            "lease-release",
            lock=self.lock,
            owner_token=self.owner,
            executor_id=self.executor,
            fencing_token=self.fence,
        )
        self.executor = "executor-B"
        lease = self.assert_ok(
            "lease-acquire",
            lock=self.lock,
            owner_token=self.owner,
            executor_id=self.executor,
        )
        new_fence = lease["fencing_token"]
        bound = self.assert_ok(
            "bind-lease",
            state=self.state,
            expected_revision=4,
            expected_phase="queued",
            fencing_token=new_fence,
        )
        self.assertEqual(bound["state_revision"], 5)
        stale_fence = self.run_helper(
            "record-pr",
            state=self.state,
            expected_revision=5,
            expected_phase="queued",
            fencing_token=self.fence,
            payload={"current": {"branch": "plan-pr/01-example"}},
        )
        self.assertEqual(stale_fence.returncode, 3)
        self.fence = new_fence

    def test_repository_owner_and_single_executor_lock(self) -> None:
        second_owner = self.run_helper(
            "lock-init",
            lock=self.lock,
            owner_token="owner-B",
            repository_id="repo-1",
            stable_plan_id="other-plan",
            plan_digest="digest-2",
        )
        self.assertEqual(second_owner.returncode, 3)
        second_executor = self.run_helper(
            "lease-acquire",
            lock=self.lock,
            owner_token=self.owner,
            executor_id="executor-B",
        )
        self.assertEqual(second_executor.returncode, 3)
        wrong_release = self.run_helper(
            "lease-release",
            lock=self.lock,
            owner_token=self.owner,
            executor_id="executor-B",
            fencing_token=self.fence,
        )
        self.assertEqual(wrong_release.returncode, 3)

    def test_incomplete_owner_lock_recovery_requires_evidence_and_safe_fence(self) -> None:
        incomplete_lock = self.root / "incomplete" / "plan-pr-loop" / "lock"
        incomplete_lock.mkdir(parents=True)
        rejected = self.run_helper(
            "lock-init",
            lock=incomplete_lock,
            owner_token="incomplete-owner",
            repository_id="repo-incomplete",
            stable_plan_id="incomplete-plan",
            plan_digest="incomplete-digest",
        )
        self.assertEqual(rejected.returncode, 3)
        recovered = self.assert_ok(
            "lock-init",
            lock=incomplete_lock,
            owner_token="incomplete-owner",
            repository_id="repo-incomplete",
            stable_plan_id="incomplete-plan",
            plan_digest="incomplete-digest",
            payload={"incomplete_lock_recovery_evidence_digest": "verified-crash-during-initialization"},
        )
        self.assertTrue(recovered["recovered"])

        unsafe_lock = self.root / "unsafe-incomplete" / "plan-pr-loop" / "lock"
        unsafe_lock.mkdir(parents=True)
        (unsafe_lock / "fence.json").write_text(json.dumps({"last_token": 4}), encoding="utf-8")
        unsafe = self.run_helper(
            "lock-init",
            lock=unsafe_lock,
            owner_token="unsafe-owner",
            repository_id="repo-unsafe",
            stable_plan_id="unsafe-plan",
            plan_digest="unsafe-digest",
            payload={"incomplete_lock_recovery_evidence_digest": "unsafe-recovery-attempt"},
        )
        self.assertEqual(unsafe.returncode, 3)
        self.assertTrue((self.lock / "executor" / "lease.json").exists())

    def test_state_mutation_requires_the_exact_live_lease(self) -> None:
        self.assert_ok(
            "lease-release",
            lock=self.lock,
            owner_token=self.owner,
            executor_id=self.executor,
            fencing_token=self.fence,
        )
        result = self.run_helper(
            "transition",
            state=self.state,
            expected_revision=1,
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"to_phase": "human-required", "reason": "test missing live lease"},
        )
        self.assertEqual(result.returncode, 3)
        self.assertEqual(self.state_data()["state_revision"], 1)

    def test_incomplete_executor_directory_can_be_taken_over_with_evidence(self) -> None:
        self.assert_ok(
            "lease-release",
            lock=self.lock,
            owner_token=self.owner,
            executor_id=self.executor,
            fencing_token=self.fence,
        )
        (self.lock / "executor").mkdir()
        self.executor = "executor-recovery"
        takeover = self.assert_ok(
            "lease-takeover",
            lock=self.lock,
            owner_token=self.owner,
            executor_id=self.executor,
            payload={"takeover_evidence_digest": "proof-no-live-continuation"},
        )
        self.assertTrue(takeover["taken_over"])
        self.assertGreater(takeover["fencing_token"], self.fence)
        self.fence = takeover["fencing_token"]
        bound = self.assert_ok(
            "bind-lease",
            state=self.state,
            expected_revision=1,
            expected_phase="preflight",
            fencing_token=self.fence,
        )
        self.assertEqual(bound["executor_fencing_token"], self.fence)

    def test_owner_lock_release_requires_complete_state_and_preserves_run_state(self) -> None:
        active_release = self.run_helper(
            "lock-release",
            lock=self.lock,
            state=self.state,
            owner_token=self.owner,
        )
        self.assertEqual(active_release.returncode, 3)
        seeded = self.seed_single_queue(include_devex=True)
        queued = self.transition(seeded["state_revision"], "preflight", "queued")
        self.finish_seeded_single_queue(queued["state_revision"])
        self.assert_ok(
            "lease-release",
            lock=self.lock,
            owner_token=self.owner,
            executor_id=self.executor,
            fencing_token=self.fence,
        )
        self.assert_ok("lock-release", lock=self.lock, state=self.state, owner_token=self.owner)
        self.assertFalse(self.lock.exists())
        self.assertTrue(self.state.exists())

    def test_state_mutation_cannot_cross_owner_lock_boundaries(self) -> None:
        other_lock = self.root / "other" / "plan-pr-loop" / "lock"
        other_state = self.root / "other" / "plan-pr-loop" / "runs" / "other-plan" / "state.json"
        self.assert_ok(
            "lock-init",
            lock=other_lock,
            owner_token="owner-B",
            repository_id="repo-2",
            stable_plan_id="other-plan",
            plan_digest="other-digest",
        )
        other_lease = self.assert_ok(
            "lease-acquire",
            lock=other_lock,
            owner_token="owner-B",
            executor_id="executor-B",
        )
        self.assert_ok(
            "init",
            state=other_state,
            lock=other_lock,
            owner_token="owner-B",
            executor_id="executor-B",
            fencing_token=other_lease["fencing_token"],
            payload={
                "plan": {
                    "stable_id": "other-plan",
                    "canonical_path": ".agents/plans/other",
                    "digest": "other-digest",
                    "files": [{"path": "00-overview.md", "sha256": "other-file"}],
                },
                "repository": {
                    "repository_id": "repo-2",
                    "base_branch": "main",
                    "last_verified_base_sha": "other-base",
                },
            },
        )
        crossed = self.run_helper(
            "transition",
            state=other_state,
            lock=self.lock,
            owner_token=self.owner,
            executor_id=self.executor,
            expected_revision=1,
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"to_phase": "human-required", "reason": "attempt cross-lock mutation"},
        )
        self.assertEqual(crossed.returncode, 3)
        self.assertEqual(json.loads(other_state.read_text(encoding="utf-8"))["phase"], "preflight")

    def test_simultaneous_same_revision_mutations_are_serialized(self) -> None:
        seeded = self.seed_single_queue()
        arguments = [
            os.fspath(HELPER),
            "transition",
            "--state",
            os.fspath(self.state),
            "--expected-revision",
            str(seeded["state_revision"]),
            "--expected-phase",
            "preflight",
            "--fencing-token",
            str(self.fence),
            "--lock",
            os.fspath(self.lock),
            "--owner-token",
            self.owner,
            "--executor-id",
            self.executor,
            "--input-json",
            json.dumps({"to_phase": "queued", "reason": "concurrent test"}),
        ]
        first = subprocess.Popen(arguments, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        second = subprocess.Popen(arguments, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        first.communicate(timeout=10)
        second.communicate(timeout=10)
        self.assertEqual(sorted([first.returncode, second.returncode]), [0, 3])
        self.assertEqual(self.state_data()["state_revision"], 4)

    def test_queue_lineage_and_duplicate_rejection(self) -> None:
        devex_requirement = self.requirement("R-devex", dependencies=["R1", "R2"])
        devex_requirement["source"]["file"] = "skill://plan-pr-loop/devex-retrospective"
        inventory = self.record_requirements(
            1,
            [self.requirement("R1"), self.requirement("R2"), devex_requirement],
        )
        queue = [
            self.queue_entry(
                "pr-parent", ["R1", "R2"], 0, revision=2, split_into=["pr-a", "pr-b"], status="superseded"
            ),
            self.queue_entry("pr-a", ["R1"], 1, supersedes=["pr-parent"]),
            self.queue_entry("pr-b", ["R2"], 2, supersedes=["pr-parent"]),
            self.queue_entry(
                "pr-devex",
                ["R-devex"],
                3,
                workflow_kind="devex-retrospective",
                prerequisites=["pr-a", "pr-b"],
                included_paths=["AGENTS.md", ".agents/**"],
            ),
        ]
        recorded = self.assert_ok(
            "record-queue",
            state=self.state,
            expected_revision=inventory["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"queue": queue, "reason": "split parent"},
        )
        coverage = self.state_data()["coverage"]
        self.assertEqual(coverage["R1"]["planned_entry_ids"], ["pr-a"])
        self.assertEqual(coverage["R2"]["planned_entry_ids"], ["pr-b"])
        self.transition(recorded["state_revision"], "preflight", "queued")
        before = self.state.read_bytes()
        bad = self.run_helper(
            "record-queue",
            state=self.state,
            expected_revision=recorded["state_revision"] + 1,
            expected_phase="queued",
            fencing_token=self.fence,
            payload={"queue": [queue[1], queue[1]], "reason": "duplicate"},
        )
        self.assertEqual(bad.returncode, 2)
        self.assertEqual(before, self.state.read_bytes())

    def test_post_preflight_split_requires_persisted_parent_and_conserves_requirements(self) -> None:
        seeded = self.seed_single_queue()
        queued = self.transition(seeded["state_revision"], "preflight", "queued")
        old_entry = self.state_data()["queue"][0]
        child_a = self.queue_entry("pr-a", ["R1"], 2, supersedes=["pr-b"])
        child_b = self.queue_entry("pr-b", ["R1"], 3, supersedes=["pr-a"])
        rejected = self.run_helper(
            "record-queue",
            state=self.state,
            expected_revision=queued["state_revision"],
            expected_phase="queued",
            fencing_token=self.fence,
            payload={"queue": [old_entry, child_a, child_b], "reason": "invalid synthetic split parents"},
        )
        self.assertEqual(rejected.returncode, 3)
        self.assertEqual(len(self.state_data()["queue"]), 2)

    def test_exception_approval_binding_and_invalidation(self) -> None:
        inventory = self.record_requirements(1, [self.requirement("R-generated")])
        queue_result = self.assert_ok(
            "record-queue",
            state=self.state,
            expected_revision=inventory["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={
                "queue": [
                    self.queue_entry(
                        "pr-generated",
                        ["R-generated"],
                        1,
                        exception_required=True,
                        exception_reason="generated output requires a large review packet",
                    )
                ],
                "reason": "exception test",
            },
        )
        contract_digest = self.state_data()["queue"][0]["contract_digest"]
        recorded = self.assert_ok(
            "approval-record",
            state=self.state,
            expected_revision=queue_result["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={
                "approval_id": "approval-1",
                "entry_id": "pr-generated",
                "contract_digest": contract_digest,
                "approver": "human",
                "summary_digest": "summary-v1",
            },
        )
        approved = self.assert_ok(
            "approval-check",
            state=self.state,
            payload={"entry_id": "pr-generated", "contract_digest": contract_digest},
        )
        changed = self.assert_ok(
            "approval-check",
            state=self.state,
            payload={"entry_id": "pr-generated", "contract_digest": "scope-v2"},
        )
        self.assertTrue(approved["approved"])
        self.assertFalse(changed["approved"])
        duplicate = self.assert_ok(
            "approval-record",
            state=self.state,
            expected_revision=recorded["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={
                "approval_id": "approval-1",
                "entry_id": "pr-generated",
                "contract_digest": contract_digest,
                "approver": "human",
                "summary_digest": "summary-v1",
            },
        )
        self.assertTrue(duplicate["idempotent"])

    def test_devex_retrospective_waits_for_ordinary_entries_and_can_close_without_pr(self) -> None:
        devex_requirement = self.requirement("R-devex", dependencies=["R1"])
        devex_requirement["source"]["file"] = "skill://plan-pr-loop/devex-retrospective"
        inventory = self.record_requirements(
            1,
            [
                self.requirement("R1"),
                devex_requirement,
            ],
        )
        ordinary = self.queue_entry("pr-one", ["R1"], 1)
        retrospective = self.queue_entry(
            "pr-devex",
            ["R-devex"],
            2,
            workflow_kind="devex-retrospective",
            prerequisites=["pr-one"],
            included_paths=["AGENTS.md", ".agents/**"],
        )
        queued = self.assert_ok(
            "record-queue",
            state=self.state,
            expected_revision=inventory["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"queue": [ordinary, retrospective], "reason": "include final DevEx gate"},
        )
        active = self.transition(queued["state_revision"], "preflight", "queued")

        early_queue = self.state_data()["queue"]
        early_queue[1].update({"revision": 2, "status": "implementing"})
        rejected = self.run_helper(
            "record-queue",
            state=self.state,
            expected_revision=active["state_revision"],
            expected_phase="queued",
            fencing_token=self.fence,
            payload={"queue": early_queue, "reason": "try retrospective too early"},
        )
        self.assertEqual(rejected.returncode, 2)

        ordinary_complete = self.state_data()["queue"]
        ordinary_complete[0].update(
            {
                "revision": 2,
                "status": "satisfied-by-base",
                "terminal_evidence": {"verification_digest": "ordinary-base-evidence"},
            }
        )
        ordinary_recorded = self.assert_ok(
            "record-queue",
            state=self.state,
            expected_revision=active["state_revision"],
            expected_phase="queued",
            fencing_token=self.fence,
            payload={"queue": ordinary_complete, "reason": "ordinary work is terminal"},
        )
        ordinary_covered = self.assert_ok(
            "record-coverage",
            state=self.state,
            expected_revision=ordinary_recorded["state_revision"],
            expected_phase="queued",
            fencing_token=self.fence,
            payload={"requirement_id": "R1", "status": "satisfied-by-base"},
        )

        artifact, artifact_digest = self.write_devex_artifact("Existing repository guidance is adequate.\n")
        no_change_queue = self.state_data()["queue"]
        no_change_queue[1].update(
            {
                "revision": 2,
                "status": "satisfied-by-base",
                "terminal_evidence": {
                    "verification_digest": artifact_digest,
                    "outcome": "no-change",
                    "retrospective_artifact": artifact,
                    "retrospective_artifact_digest": artifact_digest,
                },
            }
        )
        no_change = self.assert_ok(
            "record-queue",
            state=self.state,
            expected_revision=ordinary_covered["state_revision"],
            expected_phase="queued",
            fencing_token=self.fence,
            payload={"queue": no_change_queue, "reason": "assessment found existing guidance adequate"},
        )
        covered = self.assert_ok(
            "record-coverage",
            state=self.state,
            expected_revision=no_change["state_revision"],
            expected_phase="queued",
            fencing_token=self.fence,
            payload={"requirement_id": "R-devex", "status": "satisfied-by-base"},
        )
        self.assertEqual(covered["state_revision"], no_change["state_revision"] + 1)

    def test_preflight_cannot_finish_without_skill_owned_devex_entry(self) -> None:
        inventory = self.record_requirements(1, [self.requirement("R1")])
        queued = self.assert_ok(
            "record-queue",
            state=self.state,
            expected_revision=inventory["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"queue": [self.queue_entry("pr-one", ["R1"], 1)], "reason": "omit DevEx workflow"},
        )
        rejected = self.run_helper(
            "transition",
            state=self.state,
            expected_revision=queued["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"to_phase": "queued", "reason": "must reject missing DevEx entry"},
        )
        self.assertEqual(rejected.returncode, 4)
        self.assertEqual(self.state_data()["phase"], "preflight")

    def test_feedback_stream_identity_edit_and_duplicate_suppression(self) -> None:
        revision = 1
        fixture_to_stream = {
            "comments.json": "issue_comments",
            "review-comments.json": "review_comments",
            "reviews.json": "reviews",
        }
        for fixture_name, stream in fixture_to_stream.items():
            item = {
                **json.loads((FIXTURES / fixture_name).read_text(encoding="utf-8"))[0],
                "classification": "non-actionable",
            }
            check = self.assert_ok(
                "feedback-check",
                state=self.state,
                payload={"stream": stream, "item": item},
            )
            self.assertTrue(check["unseen"])
            recorded = self.assert_ok(
                "feedback-record",
                state=self.state,
                expected_revision=revision,
                expected_phase="preflight",
                fencing_token=self.fence,
                payload={"stream": stream, "item": {**item, "body": "must not persist"}},
            )
            revision = recorded["state_revision"]
            duplicate = self.assert_ok(
                "feedback-check",
                state=self.state,
                payload={"stream": stream, "item": item},
            )
            self.assertFalse(duplicate["unseen"])
            without_local_disposition = dict(item)
            without_local_disposition.pop("disposition", None)
            still_duplicate = self.assert_ok(
                "feedback-check",
                state=self.state,
                payload={"stream": stream, "item": without_local_disposition},
            )
            self.assertFalse(still_duplicate["unseen"])
            edited = dict(item)
            edited["body_digest"] = f"{item['body_digest']}-edited"
            if stream == "reviews":
                edited["state"] = "DISMISSED"
            else:
                edited["updated_at"] = "2026-08-22T12:30:00Z"
            changed = self.assert_ok(
                "feedback-check",
                state=self.state,
                payload={"stream": stream, "item": edited},
            )
            self.assertTrue(changed["unseen"])
        serialized = self.state.read_text(encoding="utf-8")
        self.assertNotIn("must not persist", serialized)
        self.assertNotIn('"body"', serialized)

    def test_actionable_feedback_cannot_skip_required_processing(self) -> None:
        seen_item = {
            "id": 99,
            "classification": "code-change",
            "body_digest": "feedback-digest",
            "updated_at": "2026-08-22T12:00:00Z",
            "processing_state": "seen",
        }
        seen = self.assert_ok(
            "feedback-record",
            state=self.state,
            expected_revision=1,
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"stream": "issue_comments", "item": seen_item},
        )
        skipped = self.run_helper(
            "feedback-record",
            state=self.state,
            expected_revision=seen["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={
                "stream": "issue_comments",
                "item": {**seen_item, "processing_state": "disposed", "disposition": "fixed"},
            },
        )
        self.assertEqual(skipped.returncode, 2)
        unseen_disposed = self.run_helper(
            "feedback-record",
            state=self.state,
            expected_revision=seen["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={
                "stream": "issue_comments",
                "item": {
                    **seen_item,
                    "id": 100,
                    "classification": "non-actionable",
                    "processing_state": "disposed",
                    "disposition": "duplicate",
                },
            },
        )
        self.assertEqual(unseen_disposed.returncode, 4)

        non_actionable = {**seen_item, "id": 101, "classification": "non-actionable"}
        recorded = self.assert_ok(
            "feedback-record",
            state=self.state,
            expected_revision=seen["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"stream": "issue_comments", "item": non_actionable},
        )
        disposed = self.assert_ok(
            "feedback-record",
            state=self.state,
            expected_revision=recorded["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={
                "stream": "issue_comments",
                "item": {**non_actionable, "processing_state": "disposed", "disposition": "duplicate"},
            },
        )
        self.assertGreater(disposed["state_revision"], recorded["state_revision"])

    def test_outbox_begin_resolve_and_idempotency(self) -> None:
        feedback_item = {
            "id": 1,
            "classification": "non-actionable",
            "body_digest": "comment-one",
            "updated_at": "2026-08-22T12:00:00Z",
            "processing_state": "seen",
        }
        feedback = self.assert_ok(
            "feedback-record",
            state=self.state,
            expected_revision=1,
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"stream": "issue_comments", "item": feedback_item},
        )
        operation = {
            "operation_id": "op-comment",
            "kind": "comment-reply",
            "repository_id": "repo-1",
            "pr_number": 42,
            "target": "issue_comments:1",
            "feedback_identity_digest": self.feedback_digest("issue_comments", feedback_item),
            "marker": "plan-pr-loop:op=op-comment",
            "input_digest": "input-v1",
        }
        begun = self.assert_ok(
            "outbox-begin",
            state=self.state,
            expected_revision=feedback["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"operation": operation},
        )
        self.assertFalse(begun["idempotent"])
        duplicate = self.assert_ok(
            "outbox-begin",
            state=self.state,
            expected_revision=begun["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"operation": operation},
        )
        self.assertTrue(duplicate["idempotent"])
        unauthorized = self.run_helper(
            "outbox-resolve",
            state=self.state,
            expected_revision=duplicate["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={
                "operation_id": "op-comment",
                "status": "resolved",
                "remote_id": "pr-42",
                "evidence_digest": "evidence-v1",
            },
        )
        self.assertEqual(unauthorized.returncode, 4)
        resolved = self.assert_ok(
            "outbox-resolve",
            state=self.state,
            expected_revision=duplicate["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={
                "operation_id": "op-comment",
                "status": "cancelled-before-attempt",
                "attempted": False,
                "evidence_digest": "not-attempted-proof",
            },
        )
        self.assertEqual(resolved["state_revision"], 4)
        resolved_again = self.assert_ok(
            "outbox-resolve",
            state=self.state,
            expected_revision=resolved["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={
                "operation_id": "op-comment",
                "status": "cancelled-before-attempt",
                "attempted": False,
                "evidence_digest": "not-attempted-proof",
            },
        )
        self.assertTrue(resolved_again["idempotent"])
        self.assertEqual(resolved_again["state_revision"], 4)

    def test_outbox_cancellation_requires_proof_or_human_reconciliation(self) -> None:
        feedback_item = {
            "id": 42,
            "classification": "non-actionable",
            "body_digest": "comment-forty-two",
            "updated_at": "2026-08-22T12:00:00Z",
            "processing_state": "seen",
        }
        feedback = self.assert_ok(
            "feedback-record",
            state=self.state,
            expected_revision=1,
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"stream": "issue_comments", "item": feedback_item},
        )
        operation = {
            "operation_id": "op-cancel",
            "kind": "comment-reply",
            "repository_id": "repo-1",
            "pr_number": 42,
            "target": "issue_comments:42",
            "feedback_identity_digest": self.feedback_digest("issue_comments", feedback_item),
            "marker": "plan-pr-loop:op=op-cancel",
            "input_digest": "cancel-input",
        }
        begun = self.assert_ok(
            "outbox-begin",
            state=self.state,
            expected_revision=feedback["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"operation": operation},
        )
        unsupported = self.run_helper(
            "outbox-resolve",
            state=self.state,
            expected_revision=begun["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"operation_id": "op-cancel", "status": "cancelled"},
        )
        self.assertEqual(unsupported.returncode, 2)
        unevidenced = self.run_helper(
            "outbox-resolve",
            state=self.state,
            expected_revision=begun["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"operation_id": "op-cancel", "status": "cancelled-human-resolved", "attempted": True},
        )
        self.assertEqual(unevidenced.returncode, 4)
        resolved = self.assert_ok(
            "outbox-resolve",
            state=self.state,
            expected_revision=begun["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={
                "operation_id": "op-cancel",
                "status": "cancelled-before-attempt",
                "attempted": False,
                "evidence_digest": "cancellation-evidence",
            },
        )
        self.assertEqual(self.state_data()["outbox"][0]["status"], "cancelled-before-attempt")
        self.assertGreater(resolved["state_revision"], begun["state_revision"])

    def test_outbox_rejects_wrong_repository_and_pr_targets(self) -> None:
        seeded = self.seed_single_queue()
        queued = self.transition(seeded["state_revision"], "preflight", "queued")
        current = self.assert_ok(
            "record-pr",
            state=self.state,
            expected_revision=queued["state_revision"],
            expected_phase="queued",
            fencing_token=self.fence,
            payload={"current": {"entry_id": "pr-one", "pr_number": 42}},
        )
        feedback_item = {
            "id": 9,
            "classification": "question",
            "body_digest": "target-binding",
            "updated_at": "2026-08-22T12:00:00Z",
            "processing_state": "seen",
        }
        recorded = self.assert_ok(
            "feedback-record",
            state=self.state,
            expected_revision=current["state_revision"],
            expected_phase="queued",
            fencing_token=self.fence,
            payload={"stream": "issue_comments", "item": feedback_item},
        )
        operation = {
            "operation_id": "op-wrong-target",
            "kind": "comment-reply",
            "repository_id": "repo-1",
            "pr_number": 43,
            "target": "issue_comments:9",
            "feedback_identity_digest": self.feedback_digest("issue_comments", feedback_item),
            "marker": "plan-pr-loop:op=op-wrong-target",
            "input_digest": "wrong-target-input",
        }
        wrong_pr = self.run_helper(
            "outbox-begin",
            state=self.state,
            expected_revision=recorded["state_revision"],
            expected_phase="queued",
            fencing_token=self.fence,
            payload={"operation": operation},
        )
        self.assertEqual(wrong_pr.returncode, 4)
        operation.update({"operation_id": "op-wrong-repo", "repository_id": "repo-2", "pr_number": 42})
        wrong_repo = self.run_helper(
            "outbox-begin",
            state=self.state,
            expected_revision=recorded["state_revision"],
            expected_phase="queued",
            fencing_token=self.fence,
            payload={"operation": operation},
        )
        self.assertEqual(wrong_repo.returncode, 4)

    def test_post_merge_feedback_can_map_to_an_existing_later_contract(self) -> None:
        seeded = self.seed_two_ordinary_queue()
        queued = self.transition(seeded["state_revision"], "preflight", "queued")
        merged = self.finish_seeded_single_queue(
            queued["state_revision"],
            finish_retrospective=False,
        )
        feedback_item = {
            "id": 77,
            "classification": "code-change",
            "body_digest": "late-feedback",
            "updated_at": "2026-08-22T16:00:00Z",
            "processing_state": "seen",
        }
        seen = self.assert_ok(
            "feedback-record",
            state=self.state,
            expected_revision=merged["state_revision"],
            expected_phase="awaiting-merge",
            fencing_token=self.fence,
            payload={"stream": "review_comments", "item": feedback_item},
        )
        target = self.state_data()["queue"][1]
        stale = self.run_helper(
            "feedback-record",
            state=self.state,
            expected_revision=seen["state_revision"],
            expected_phase="awaiting-merge",
            fencing_token=self.fence,
            payload={
                "stream": "review_comments",
                "item": {
                    **feedback_item,
                    "processing_state": "disposed",
                    "disposition": "mapped-later",
                    "mapped_entry_id": "pr-two",
                    "mapped_entry_contract_digest": "stale-contract",
                    "human_disposition_digest": "human-mapping-approval",
                },
            },
        )
        self.assertEqual(stale.returncode, 4)
        mapped = self.assert_ok(
            "feedback-record",
            state=self.state,
            expected_revision=seen["state_revision"],
            expected_phase="awaiting-merge",
            fencing_token=self.fence,
            payload={
                "stream": "review_comments",
                "item": {
                    **feedback_item,
                    "processing_state": "disposed",
                    "disposition": "mapped-later",
                    "mapped_entry_id": "pr-two",
                    "mapped_entry_contract_digest": target["contract_digest"],
                    "human_disposition_digest": "human-mapping-approval",
                },
            },
        )
        self.assertGreater(mapped["state_revision"], seen["state_revision"])

    def test_monitor_wakes_when_pr_is_already_merged(self) -> None:
        fake_state = self.root / "fake-gh-state.json"
        fake_state.write_text(
            json.dumps(
                {
                    "prs": [
                        {
                            "number": 7,
                            "state": "MERGED",
                            "mergedAt": "2026-08-22T17:00:00Z",
                            "mergeCommit": {"oid": "a" * 40},
                            "comments": [],
                            "reviews": [],
                            "review_comments": [],
                        }
                    ]
                }
            ),
            encoding="utf-8",
        )
        environment = {**os.environ, "PLAN_PR_LOOP_FAKE_GH_STATE": os.fspath(fake_state)}
        baseline = subprocess.run(
            [
                os.fspath(MONITOR),
                "--repo",
                "owner/repo",
                "--pr-number",
                "7",
                "--gh",
                os.fspath(FAKE_GH),
                "--snapshot-only",
            ],
            text=True,
            capture_output=True,
            check=False,
            env=environment,
        )
        self.assertEqual(baseline.returncode, 0, baseline.stderr)
        baseline_event = json.loads(baseline.stdout)
        self.assertTrue(baseline_event["terminal"])
        monitor_lock = self.root / "monitor-pr-7"
        monitored = subprocess.run(
            [
                os.fspath(MONITOR),
                "--repo",
                "owner/repo",
                "--pr-number",
                "7",
                "--gh",
                os.fspath(FAKE_GH),
                "--monitor-lock",
                os.fspath(monitor_lock),
                "--expected-fingerprint",
                baseline_event["fingerprint"],
                "--interval-seconds",
                "0.01",
            ],
            text=True,
            capture_output=True,
            check=False,
            env=environment,
        )
        self.assertEqual(monitored.returncode, 0, monitored.stderr)
        event = json.loads(monitored.stdout)
        self.assertEqual(event["event"], "monitor-change")
        self.assertEqual(event["reason"], "terminal-at-monitor-start")
        self.assertFalse(monitor_lock.exists())

        monitor_lock.mkdir()
        (monitor_lock / "owner.json").write_text(
            json.dumps({"pid": 99999999, "repo": "owner/repo", "pr_number": 7}),
            encoding="utf-8",
        )
        stale_arguments = [
            os.fspath(MONITOR),
            "--repo",
            "owner/repo",
            "--pr-number",
            "7",
            "--gh",
            os.fspath(FAKE_GH),
            "--monitor-lock",
            os.fspath(monitor_lock),
            "--expected-fingerprint",
            baseline_event["fingerprint"],
            "--interval-seconds",
            "0.01",
        ]
        stale = subprocess.run(
            stale_arguments,
            text=True,
            capture_output=True,
            check=False,
            env=environment,
        )
        self.assertEqual(stale.returncode, 4)
        self.assertEqual(json.loads(stale.stdout)["event"], "monitor-stale")
        recovered = subprocess.run(
            [*stale_arguments, "--stale-monitor-recovery-evidence-digest", "verified-no-live-monitor"],
            text=True,
            capture_output=True,
            check=False,
            env=environment,
        )
        self.assertEqual(recovered.returncode, 0, recovered.stderr)
        self.assertEqual(json.loads(recovered.stdout)["reason"], "terminal-at-monitor-start")
        self.assertFalse(monitor_lock.exists())

    def test_comment_and_review_request_outboxes(self) -> None:
        seeded = self.seed_single_queue()
        queued = self.transition(seeded["state_revision"], "preflight", "queued")
        base_sha = "1" * 40
        head_sha = "2" * 40
        current = self.assert_ok(
            "record-pr",
            state=self.state,
            expected_revision=queued["state_revision"],
            expected_phase="queued",
            fencing_token=self.fence,
            payload={
                "current": {
                    "entry_id": "pr-one",
                    "pr_number": 42,
                    "reviewed_base_sha": base_sha,
                    "local_head_sha": head_sha,
                    "remote_head_sha": head_sha,
                }
            },
        )
        revision = current["state_revision"]
        phase = "queued"
        for status in ("implementing", "internal-review"):
            entry = self.state_data()["queue"][0]
            entry.update({"revision": entry["revision"] + 1, "status": status})
            changed = self.assert_ok(
                "record-queue",
                state=self.state,
                expected_revision=revision,
                expected_phase=phase,
                fencing_token=self.fence,
                payload={"queue": self.queue_with_entry(entry), "reason": f"prepare {status}"},
            )
            transitioned = self.transition(changed["state_revision"], phase, status)
            revision = transitioned["state_revision"]
            phase = status
        gate = self.assert_ok(
            "record-review-gate",
            state=self.state,
            expected_revision=revision,
            expected_phase="internal-review",
            fencing_token=self.fence,
            payload=self.review_gate("pr-one", base_sha, head_sha, self.state_data()["queue"][0]["contract_digest"]),
        )
        entry = self.state_data()["queue"][0]
        entry.update({"revision": entry["revision"] + 1, "status": "publishing"})
        publishing_queue = self.assert_ok(
            "record-queue",
            state=self.state,
            expected_revision=gate["state_revision"],
            expected_phase="internal-review",
            fencing_token=self.fence,
            payload={"queue": self.queue_with_entry(entry), "reason": "prepare publication operations"},
        )
        publishing = self.transition(publishing_queue["state_revision"], "internal-review", "publishing")
        revision = publishing["state_revision"]
        review_begun = self.assert_ok(
            "outbox-begin",
            state=self.state,
            expected_revision=revision,
            expected_phase="publishing",
            fencing_token=self.fence,
            payload={
                "operation": {
                    "operation_id": "op-review-request",
                    "kind": "review-request",
                    "repository_id": "repo-1",
                    "pr_number": 42,
                    "target": "reviewer",
                    "expected_base_oid": base_sha,
                    "expected_head_sha": head_sha,
                    "input_digest": "digest-review-request",
                }
            },
        )
        review_authorized = self.assert_ok(
            "outbox-authorize",
            state=self.state,
            expected_revision=review_begun["state_revision"],
            expected_phase="publishing",
            fencing_token=self.fence,
            payload={"operation_id": "op-review-request"},
        )
        review_resolved = self.assert_ok(
            "outbox-resolve",
            state=self.state,
            expected_revision=review_authorized["state_revision"],
            expected_phase="publishing",
            fencing_token=self.fence,
            payload={
                "operation_id": "op-review-request",
                "status": "resolved",
                "evidence_digest": "evidence-review-request",
            },
        )
        waiting = self.transition(review_resolved["state_revision"], "publishing", "awaiting-human-review")
        addressing = self.transition(waiting["state_revision"], "awaiting-human-review", "addressing-feedback")
        feedback_item = {
            "id": 42,
            "classification": "question",
            "body_digest": "question-digest",
            "updated_at": "2026-08-22T12:00:00Z",
            "processing_state": "seen",
        }
        feedback_seen = self.assert_ok(
            "feedback-record",
            state=self.state,
            expected_revision=addressing["state_revision"],
            expected_phase="addressing-feedback",
            fencing_token=self.fence,
            payload={"stream": "issue_comments", "item": feedback_item},
        )
        comment_begun = self.assert_ok(
            "outbox-begin",
            state=self.state,
            expected_revision=feedback_seen["state_revision"],
            expected_phase="addressing-feedback",
            fencing_token=self.fence,
            payload={
                "operation": {
                    "operation_id": "op-comment-reply",
                    "kind": "comment-reply",
                    "repository_id": "repo-1",
                    "pr_number": 42,
                    "target": "issue_comments:42",
                    "feedback_identity_digest": self.feedback_digest("issue_comments", feedback_item),
                    "marker": "plan-pr-loop:op=op-comment-reply",
                    "input_digest": "digest-comment-reply",
                }
            },
        )
        comment_authorized = self.assert_ok(
            "outbox-authorize",
            state=self.state,
            expected_revision=comment_begun["state_revision"],
            expected_phase="addressing-feedback",
            fencing_token=self.fence,
            payload={"operation_id": "op-comment-reply"},
        )
        ambiguous = self.assert_ok(
            "outbox-resolve",
            state=self.state,
            expected_revision=comment_authorized["state_revision"],
            expected_phase="addressing-feedback",
            fencing_token=self.fence,
            payload={
                "operation_id": "op-comment-reply",
                "status": "ambiguous",
                "attempted": True,
                "evidence_digest": "ambiguous-provider-snapshot",
            },
        )
        comment_resolved = self.assert_ok(
            "outbox-resolve",
            state=self.state,
            expected_revision=ambiguous["state_revision"],
            expected_phase="addressing-feedback",
            fencing_token=self.fence,
            payload={
                "operation_id": "op-comment-reply",
                "status": "cancelled-human-resolved",
                "attempted": True,
                "evidence_digest": "ambiguous-provider-snapshot",
                "human_disposition_digest": "human-confirmed-no-retry",
                "reconciliation_digest": "final-provider-reconciliation",
            },
        )
        replied = self.assert_ok(
            "feedback-record",
            state=self.state,
            expected_revision=comment_resolved["state_revision"],
            expected_phase="addressing-feedback",
            fencing_token=self.fence,
            payload={
                "stream": "issue_comments",
                "item": {**feedback_item, "processing_state": "replied", "outbound_operation_id": "op-comment-reply"},
            },
        )
        self.assertGreater(replied["state_revision"], comment_resolved["state_revision"])
        unrelated_item = {**feedback_item, "id": 43, "body_digest": "other-question"}
        unrelated_seen = self.assert_ok(
            "feedback-record",
            state=self.state,
            expected_revision=replied["state_revision"],
            expected_phase="addressing-feedback",
            fencing_token=self.fence,
            payload={"stream": "issue_comments", "item": unrelated_item},
        )
        reused = self.run_helper(
            "feedback-record",
            state=self.state,
            expected_revision=unrelated_seen["state_revision"],
            expected_phase="addressing-feedback",
            fencing_token=self.fence,
            payload={
                "stream": "issue_comments",
                "item": {
                    **unrelated_item,
                    "processing_state": "replied",
                    "outbound_operation_id": "op-comment-reply",
                },
            },
        )
        self.assertEqual(reused.returncode, 4)
        stale_request = self.assert_ok(
            "outbox-begin",
            state=self.state,
            expected_revision=unrelated_seen["state_revision"],
            expected_phase="addressing-feedback",
            fencing_token=self.fence,
            payload={
                "operation": {
                    "operation_id": "op-edited-feedback-review",
                    "kind": "review-request",
                    "repository_id": "repo-1",
                    "pr_number": 42,
                    "target": "reviewer",
                    "feedback_targets": ["issue_comments:43", "issue_comments:42"],
                    "feedback_identity_digests": [
                        self.feedback_digest("issue_comments", unrelated_item),
                        self.feedback_digest("issue_comments", feedback_item),
                    ],
                    "expected_base_oid": base_sha,
                    "expected_head_sha": head_sha,
                    "input_digest": "edited-feedback-request",
                }
            },
        )
        persisted_request = self.state_data()["outbox"][-1]
        self.assertEqual(
            persisted_request["feedback_targets"],
            ["issue_comments:42", "issue_comments:43"],
        )
        edited_item = {
            **feedback_item,
            "body_digest": "edited-question-digest",
            "updated_at": "2026-08-22T12:30:00Z",
            "processing_state": "seen",
        }
        edited = self.assert_ok(
            "feedback-record",
            state=self.state,
            expected_revision=stale_request["state_revision"],
            expected_phase="addressing-feedback",
            fencing_token=self.fence,
            payload={"stream": "issue_comments", "item": edited_item},
        )
        stale_reply = self.run_helper(
            "feedback-record",
            state=self.state,
            expected_revision=edited["state_revision"],
            expected_phase="addressing-feedback",
            fencing_token=self.fence,
            payload={
                "stream": "issue_comments",
                "item": {
                    **edited_item,
                    "processing_state": "replied",
                    "outbound_operation_id": "op-comment-reply",
                },
            },
        )
        self.assertEqual(stale_reply.returncode, 4)
        stale_request_authorization = self.run_helper(
            "outbox-authorize",
            state=self.state,
            expected_revision=edited["state_revision"],
            expected_phase="addressing-feedback",
            fencing_token=self.fence,
            payload={"operation_id": "op-edited-feedback-review"},
        )
        self.assertEqual(stale_request_authorization.returncode, 4)
        self.assertEqual(
            [item["kind"] for item in self.state_data()["outbox"]],
            ["review-request", "comment-reply", "review-request"],
        )

    def test_complete_phase_cannot_reopen(self) -> None:
        seeded = self.seed_single_queue(include_devex=True)
        queued = self.transition(seeded["state_revision"], "preflight", "queued")
        complete = self.finish_seeded_single_queue(queued["state_revision"])
        before = self.state.read_bytes()
        result = self.run_helper(
            "transition",
            state=self.state,
            expected_revision=complete["state_revision"],
            expected_phase="complete",
            fencing_token=self.fence,
            payload={"to_phase": "recovery-required", "reason": "must remain terminal"},
        )
        self.assertEqual(result.returncode, 4)
        self.assertEqual(before, self.state.read_bytes())

    def test_requirement_dependency_cycle_is_rejected_atomically(self) -> None:
        before = self.state.read_bytes()
        result = self.run_helper(
            "record-requirements",
            state=self.state,
            expected_revision=1,
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={
                "requirements": [
                    self.requirement("R1", dependencies=["R2"]),
                    self.requirement("R2", dependencies=["R1"]),
                ],
                "reason": "invalid cycle",
            },
        )
        self.assertEqual(result.returncode, 2)
        self.assertEqual(before, self.state.read_bytes())

    def test_queue_entries_are_immutable_and_terminal_entries_cannot_reopen(self) -> None:
        inventory = self.record_requirements(1, [self.requirement("R1")])
        entry = self.queue_entry("pr-one", ["R1"], 1, purpose="First purpose")
        queued = self.assert_ok(
            "record-queue",
            state=self.state,
            expected_revision=inventory["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"queue": [entry], "reason": "initial queue"},
        )
        for replacement in ([], [{**entry, "purpose": "Changed purpose", "revision": 2}]):
            before = self.state.read_bytes()
            rejected = self.run_helper(
                "record-queue",
                state=self.state,
                expected_revision=queued["state_revision"],
                expected_phase="preflight",
                fencing_token=self.fence,
                payload={"queue": replacement, "reason": "invalid rewrite"},
            )
            self.assertEqual(rejected.returncode, 3)
            self.assertEqual(before, self.state.read_bytes())

        current = self.assert_ok(
            "record-pr",
            state=self.state,
            expected_revision=queued["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"current": {"entry_id": "pr-one", "sequence": 1}},
        )
        started = self.assert_ok(
            "record-queue",
            state=self.state,
            expected_revision=current["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"queue": [{**entry, "revision": 2, "status": "implementing"}], "reason": "started"},
        )
        reordered = self.run_helper(
            "record-queue",
            state=self.state,
            expected_revision=started["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={
                "queue": [{**entry, "revision": 3, "status": "implementing", "sequence": 2}],
                "reason": "reorder started entry",
            },
        )
        self.assertEqual(reordered.returncode, 3)
        returned_entry = self.state_data()["queue"][0]
        returned_entry.update({"revision": returned_entry["revision"] + 1, "status": "queued"})
        returned = self.assert_ok(
            "record-queue",
            state=self.state,
            expected_revision=started["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"queue": [returned_entry], "reason": "return before terminal proof"},
        )
        terminal_entry = self.state_data()["queue"][0]
        terminal_entry.update(
            {
                "revision": terminal_entry["revision"] + 1,
                "status": "satisfied-by-base",
                "terminal_evidence": {
                    "verification_digest": "terminal-verification",
                },
            }
        )
        terminal = self.assert_ok(
            "record-queue",
            state=self.state,
            expected_revision=returned["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"queue": [terminal_entry], "reason": "satisfied by base"},
        )
        reopened = self.run_helper(
            "record-queue",
            state=self.state,
            expected_revision=terminal["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"queue": [{**entry, "revision": 4, "status": "queued"}], "reason": "reopen"},
        )
        self.assertEqual(reopened.returncode, 4)
        child = self.queue_entry(
            "pr-child", ["R1"], 2, supersedes=["pr-one"], purpose="Invalid late child"
        )
        split_terminal = self.run_helper(
            "record-queue",
            state=self.state,
            expected_revision=terminal["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={
                "queue": [
                    {**terminal_entry, "revision": terminal_entry["revision"] + 1, "split_into": ["pr-child"]},
                    child,
                ],
                "reason": "invalid terminal split",
            },
        )
        self.assertEqual(split_terminal.returncode, 3)

    def test_unknown_requirement_cannot_enter_queue(self) -> None:
        inventory = self.record_requirements(1, [self.requirement("R1")])
        result = self.run_helper(
            "record-queue",
            state=self.state,
            expected_revision=inventory["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={
                "queue": [{"entry_id": "pr-bad", "revision": 1, "requirement_ids": ["R2"]}],
                "reason": "bad mapping",
            },
        )
        self.assertEqual(result.returncode, 2)

    def test_active_user_context_requires_explicit_per_pr_compatibility(self) -> None:
        context = self.assert_ok(
            "record-application-context",
            state=self.state,
            expected_revision=1,
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={
                "has_active_users": True,
                "backward_compatibility_required": True,
                "feature_flags": "decide-per-pr",
                "confirmation_digest": "active-user-confirmation-v2",
                "confirmed_at": "2026-08-22T14:00:00Z",
            },
        )
        inventory = self.record_requirements(context["state_revision"], [self.requirement("R1")])
        base_entry = self.queue_entry("pr-one", ["R1"], 1)
        missing = self.run_helper(
            "record-queue",
            state=self.state,
            expected_revision=inventory["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"queue": [base_entry], "reason": "missing compatibility decision"},
        )
        self.assertEqual(missing.returncode, 2)
        breaking = self.run_helper(
            "record-queue",
            state=self.state,
            expected_revision=inventory["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={
                "queue": [
                    {
                        **base_entry,
                        "compatibility": {
                            "behavior_change": True,
                            "backward_compatible": False,
                            "feature_flag_decision": "required",
                            "decision_evidence_digest": "cannot-override-confirmed-compatibility",
                        },
                    }
                ],
                "reason": "attempt breaking PR despite compatibility requirement",
            },
        )
        self.assertEqual(breaking.returncode, 2)
        accepted = self.assert_ok(
            "record-queue",
            state=self.state,
            expected_revision=inventory["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={
                "queue": [
                    {
                        **base_entry,
                        "compatibility": {
                            "behavior_change": True,
                            "backward_compatible": True,
                            "feature_flag_decision": "required",
                            "decision_evidence_digest": "per-pr-human-decision",
                        },
                    }
                ],
                "reason": "confirmed compatibility and flag decision",
            },
        )
        self.assertEqual(accepted["state_revision"], inventory["state_revision"] + 1)

    def test_changed_application_context_preserves_historical_pr_contracts(self) -> None:
        seeded = self.seed_single_queue()
        current = self.assert_ok(
            "record-pr",
            state=self.state,
            expected_revision=seeded["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"current": {"entry_id": "pr-one", "branch": "plan-pr/01-one"}},
        )
        before = self.state_data()
        historical_contract = before["queue"][0]["contract_digest"]
        historical_context = before["queue"][0]["application_context_digest"]
        changed = self.assert_ok(
            "record-application-context",
            state=self.state,
            expected_revision=current["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={
                "has_active_users": True,
                "backward_compatibility_required": True,
                "feature_flags": "appropriate",
                "confirmation_digest": "corrected-application-context",
                "confirmed_at": "2026-08-22T14:30:00Z",
            },
        )
        self.assertGreater(changed["state_revision"], current["state_revision"])
        state = self.state_data()
        self.assertEqual(state["queue"][0]["contract_digest"], historical_contract)
        self.assertEqual(state["prs"]["pr-one"]["contract_digest"], historical_contract)
        self.assertEqual(state["queue"][0]["application_context_digest"], historical_context)
        self.assertNotEqual(state["queue"][1]["application_context_digest"], historical_context)
        self.assertEqual(len(state["application_context_history"]), 2)

    def test_merged_feedback_race_uses_explicit_human_exception(self) -> None:
        seeded = self.seed_single_queue(include_devex=True)
        queued = self.transition(seeded["state_revision"], "preflight", "queued")
        base_sha = "1" * 40
        reviewed_head = "2" * 40
        fixed_head = "3" * 40
        merge_sha = "4" * 40
        current = self.assert_ok(
            "record-pr",
            state=self.state,
            expected_revision=queued["state_revision"],
            expected_phase="queued",
            fencing_token=self.fence,
            payload={
                "current": {
                    "entry_id": "pr-one",
                    "pr_number": 42,
                    "reviewed_base_sha": base_sha,
                    "local_head_sha": reviewed_head,
                    "remote_head_sha": reviewed_head,
                }
            },
        )
        revision = current["state_revision"]
        phase = "queued"
        for status in ("implementing", "internal-review"):
            entry = self.state_data()["queue"][0]
            entry.update({"revision": entry["revision"] + 1, "status": status})
            changed = self.assert_ok(
                "record-queue",
                state=self.state,
                expected_revision=revision,
                expected_phase=phase,
                fencing_token=self.fence,
                payload={"queue": self.queue_with_entry(entry), "reason": f"prepare {status}"},
            )
            transitioned = self.transition(changed["state_revision"], phase, status)
            revision = transitioned["state_revision"]
            phase = status
        gated = self.assert_ok(
            "record-review-gate",
            state=self.state,
            expected_revision=revision,
            expected_phase=phase,
            fencing_token=self.fence,
            payload=self.review_gate("pr-one", base_sha, reviewed_head, self.state_data()["queue"][0]["contract_digest"]),
        )
        revision = gated["state_revision"]
        for status in ("publishing", "awaiting-human-review", "addressing-feedback"):
            entry = self.state_data()["queue"][0]
            entry.update({"revision": entry["revision"] + 1, "status": status})
            changed = self.assert_ok(
                "record-queue",
                state=self.state,
                expected_revision=revision,
                expected_phase=phase,
                fencing_token=self.fence,
                payload={"queue": self.queue_with_entry(entry), "reason": f"prepare {status}"},
            )
            transitioned = self.transition(changed["state_revision"], phase, status)
            revision = transitioned["state_revision"]
            phase = status

        feedback_item = {
            "id": 42,
            "classification": "code-change",
            "body_digest": "feedback-body",
            "updated_at": "2026-08-22T15:00:00Z",
            "processing_state": "seen",
        }
        seen = self.assert_ok(
            "feedback-record",
            state=self.state,
            expected_revision=revision,
            expected_phase=phase,
            fencing_token=self.fence,
            payload={"stream": "review_comments", "item": feedback_item},
        )
        feedback_item.update(
            {
                "processing_state": "in-progress",
                "intended_fix_digest": "intended-fix",
                "expected_head_sha": reviewed_head,
            }
        )
        in_progress = self.assert_ok(
            "feedback-record",
            state=self.state,
            expected_revision=seen["state_revision"],
            expected_phase=phase,
            fencing_token=self.fence,
            payload={"stream": "review_comments", "item": feedback_item},
        )
        pushed = self.assert_ok(
            "record-pr",
            state=self.state,
            expected_revision=in_progress["state_revision"],
            expected_phase=phase,
            fencing_token=self.fence,
            payload={"current": {"local_head_sha": fixed_head, "remote_head_sha": fixed_head}},
        )
        self.assertNotIn("pr-one", self.state_data()["review_gates"])
        feedback_item.update(
            {
                "processing_state": "code-pushed",
                "commit_sha": fixed_head,
                "validation_digest": "post-fix-validation",
            }
        )
        code_pushed = self.assert_ok(
            "feedback-record",
            state=self.state,
            expected_revision=pushed["state_revision"],
            expected_phase=phase,
            fencing_token=self.fence,
            payload={"stream": "review_comments", "item": feedback_item},
        )
        contract_digest = self.state_data()["queue"][0]["contract_digest"]
        approval = self.assert_ok(
            "approval-record",
            state=self.state,
            expected_revision=code_pushed["state_revision"],
            expected_phase=phase,
            fencing_token=self.fence,
            payload={
                "approval_id": "merge-race-approval",
                "kind": "merged-feedback-race",
                "entry_id": "pr-one",
                "contract_digest": contract_digest,
                "approver": "human-reviewer",
                "approved_at": "2026-08-22T15:05:00Z",
                "summary_digest": "human-merge-disposition",
                "merge_sha": merge_sha,
                "verification_digest": "merged-verification",
                "feedback_identity_digest": self.feedback_digest("review_comments", feedback_item),
            },
        )
        not_scope_approved = self.assert_ok(
            "approval-check",
            state=self.state,
            payload={"entry_id": "pr-one", "contract_digest": contract_digest},
        )
        self.assertFalse(not_scope_approved["approved"])
        operation = {
            "operation_id": "reply-after-merge",
            "kind": "comment-reply",
            "repository_id": "repo-1",
            "pr_number": 42,
            "target": "review_comments:42",
            "feedback_identity_digest": self.feedback_digest("review_comments", feedback_item),
            "marker": "plan-pr-loop:op=reply-after-merge",
            "input_digest": "reply-input",
        }
        begun = self.assert_ok(
            "outbox-begin",
            state=self.state,
            expected_revision=approval["state_revision"],
            expected_phase=phase,
            fencing_token=self.fence,
            payload={"operation": operation},
        )
        authorized = self.assert_ok(
            "outbox-authorize",
            state=self.state,
            expected_revision=begun["state_revision"],
            expected_phase=phase,
            fencing_token=self.fence,
            payload={"operation_id": "reply-after-merge"},
        )
        resolved = self.assert_ok(
            "outbox-resolve",
            state=self.state,
            expected_revision=authorized["state_revision"],
            expected_phase=phase,
            fencing_token=self.fence,
            payload={
                "operation_id": "reply-after-merge",
                "status": "resolved",
                "remote_id": "reply-43",
                "attempted": True,
                "evidence_digest": "reply-evidence",
            },
        )
        merged_pr = self.assert_ok(
            "record-pr",
            state=self.state,
            expected_revision=resolved["state_revision"],
            expected_phase=phase,
            fencing_token=self.fence,
            payload={"current": {"merge_sha": merge_sha, "merged_at": "2026-08-22T15:04:00Z"}},
        )
        entry = self.state_data()["queue"][0]
        entry.update({"revision": entry["revision"] + 1, "status": "awaiting-merge"})
        queue_waiting = self.assert_ok(
            "record-queue",
            state=self.state,
            expected_revision=merged_pr["state_revision"],
            expected_phase=phase,
            fencing_token=self.fence,
            payload={"queue": self.queue_with_entry(entry), "reason": "human merge superseded the open-PR rereview"},
        )
        phase_waiting = self.transition(queue_waiting["state_revision"], phase, "awaiting-merge")
        phase = "awaiting-merge"
        entry = self.state_data()["queue"][0]
        entry.update(
            {
                "revision": entry["revision"] + 1,
                "status": "merged",
                "terminal_evidence": {
                    "pr_number": 42,
                    "merge_sha": merge_sha,
                    "base_sha": merge_sha,
                    "verification_digest": "merged-verification",
                    "review_exception_approval_id": "merge-race-approval",
                    "human_disposition_digest": "human-merge-disposition",
                    "feedback_identity_digest": self.feedback_digest("review_comments", feedback_item),
                },
            }
        )
        merged = self.assert_ok(
            "record-queue",
            state=self.state,
            expected_revision=phase_waiting["state_revision"],
            expected_phase=phase,
            fencing_token=self.fence,
            payload={"queue": self.queue_with_entry(entry), "reason": "verified human merge won review-request race"},
        )
        covered = self.assert_ok(
            "record-coverage",
            state=self.state,
            expected_revision=merged["state_revision"],
            expected_phase=phase,
            fencing_token=self.fence,
            payload={"requirement_id": "R1", "status": "merged"},
        )
        feedback_item.update(
            {
                "processing_state": "replied",
                "outbound_operation_id": "reply-after-merge",
                "review_request_operation_id": None,
                "merge_commit_sha": merge_sha,
                "merge_evidence_digest": "merged-verification",
                "human_disposition_digest": "human-merge-disposition",
                "review_exception_approval_id": "merge-race-approval",
            }
        )
        replied = self.assert_ok(
            "feedback-record",
            state=self.state,
            expected_revision=covered["state_revision"],
            expected_phase=phase,
            fencing_token=self.fence,
            payload={"stream": "review_comments", "item": feedback_item},
        )
        feedback_item.update({"processing_state": "disposed", "disposition": "fix commit was included in verified human merge"})
        disposed = self.assert_ok(
            "feedback-record",
            state=self.state,
            expected_revision=replied["state_revision"],
            expected_phase=phase,
            fencing_token=self.fence,
            payload={"stream": "review_comments", "item": feedback_item},
        )
        retrospective = next(
            item for item in self.state_data()["queue"] if item.get("workflow_kind") == "devex-retrospective"
        )
        artifact, artifact_digest = self.write_devex_artifact("No merge-race session guidance change was justified.\n")
        retrospective.update(
            {
                "revision": retrospective["revision"] + 1,
                "status": "satisfied-by-base",
                "terminal_evidence": {
                    "verification_digest": artifact_digest,
                    "outcome": "no-change",
                    "retrospective_artifact": artifact,
                    "retrospective_artifact_digest": artifact_digest,
                },
            }
        )
        retrospective_done = self.assert_ok(
            "record-queue",
            state=self.state,
            expected_revision=disposed["state_revision"],
            expected_phase=phase,
            fencing_token=self.fence,
            payload={"queue": self.queue_with_entry(retrospective), "reason": "record merge-race DevEx assessment"},
        )
        devex_covered = self.assert_ok(
            "record-coverage",
            state=self.state,
            expected_revision=retrospective_done["state_revision"],
            expected_phase=phase,
            fencing_token=self.fence,
            payload={"requirement_id": "R-devex", "status": "satisfied-by-base"},
        )
        accepted = self.assert_ok(
            "record-acceptance",
            state=self.state,
            expected_revision=devex_covered["state_revision"],
            expected_phase="awaiting-merge",
            fencing_token=self.fence,
            payload={"status": "passed", "evidence_digest": "final-evidence", "base_sha": merge_sha},
        )
        completed = self.transition(accepted["state_revision"], "awaiting-merge", "complete")
        self.assertEqual(completed["phase"], "complete")

    def test_per_entry_pr_records_preserve_prior_pr_and_reset_current(self) -> None:
        inventory = self.record_requirements(1, [self.requirement("R1"), self.requirement("R2")])
        queue = [
            self.queue_entry("pr-one", ["R1"], 1),
            self.queue_entry("pr-two", ["R2"], 2),
        ]
        queued = self.assert_ok(
            "record-queue",
            state=self.state,
            expected_revision=inventory["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"queue": queue, "reason": "two PR records"},
        )
        first = self.assert_ok(
            "record-pr",
            state=self.state,
            expected_revision=queued["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"current": {"entry_id": "pr-one", "pr_number": 1, "pr_url": "https://example.invalid/pr/1"}},
        )
        self.assert_ok(
            "record-pr",
            state=self.state,
            expected_revision=first["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"current": {"entry_id": "pr-two", "branch": "plan-pr/02-two"}},
        )
        state = self.state_data()
        self.assertNotIn("pr_url", state["current"])
        self.assertEqual(state["prs"]["pr-one"]["pr_url"], "https://example.invalid/pr/1")

    def test_review_isolation_intents_are_durable_and_ordered(self) -> None:
        first = self.assert_ok(
            "record-review-isolation",
            state=self.state,
            expected_revision=1,
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={
                "phase": "backup-intent",
                "source_path": "reviews",
                "backup_path": "review-backups/pr-one",
            },
        )
        backed_up = self.assert_ok(
            "record-review-isolation",
            state=self.state,
            expected_revision=first["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"phase": "backed-up"},
        )
        reviewing = self.assert_ok(
            "record-review-isolation",
            state=self.state,
            expected_revision=backed_up["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={
                "phase": "reviewing",
                "base_oid": "base-oid",
                "head_oid": "head-oid",
                "manifest_digest": "manifest-digest",
            },
        )
        illegal = self.run_helper(
            "record-review-isolation",
            state=self.state,
            expected_revision=reviewing["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={"phase": "backed-up"},
        )
        self.assertEqual(illegal.returncode, 4)

    def test_publication_requires_fresh_review_and_thermo_gate(self) -> None:
        seeded = self.seed_single_queue()
        queued = self.transition(seeded["state_revision"], "preflight", "queued")
        base_sha = "3" * 40
        first_head = "4" * 40
        current = self.assert_ok(
            "record-pr",
            state=self.state,
            expected_revision=queued["state_revision"],
            expected_phase="queued",
            fencing_token=self.fence,
            payload={
                "current": {
                    "entry_id": "pr-one",
                    "branch": "plan-pr/01-one",
                    "reviewed_base_sha": base_sha,
                    "local_head_sha": first_head,
                    "remote_head_sha": first_head,
                }
            },
        )
        revision = current["state_revision"]
        phase = "queued"
        for status in ("implementing", "internal-review"):
            entry = self.state_data()["queue"][0]
            entry.update({"revision": entry["revision"] + 1, "status": status})
            queue_result = self.assert_ok(
                "record-queue",
                state=self.state,
                expected_revision=revision,
                expected_phase=phase,
                fencing_token=self.fence,
                payload={"queue": self.queue_with_entry(entry), "reason": f"advance {status}"},
            )
            phase_result = self.transition(queue_result["state_revision"], phase, status)
            revision = phase_result["state_revision"]
            phase = status

        publishing_entry = self.state_data()["queue"][0]
        publishing_entry.update({"revision": publishing_entry["revision"] + 1, "status": "publishing"})
        bypass = self.run_helper(
            "record-queue",
            state=self.state,
            expected_revision=revision,
            expected_phase="internal-review",
            fencing_token=self.fence,
            payload={"queue": self.queue_with_entry(publishing_entry), "reason": "attempt bypass"},
        )
        self.assertEqual(bypass.returncode, 4)

        gate = self.assert_ok(
            "record-review-gate",
            state=self.state,
            expected_revision=revision,
            expected_phase="internal-review",
            fencing_token=self.fence,
            payload=self.review_gate(
                "pr-one", base_sha, first_head, self.state_data()["queue"][0]["contract_digest"]
            ),
        )
        changed_head = "5" * 40
        moved = self.assert_ok(
            "record-pr",
            state=self.state,
            expected_revision=gate["state_revision"],
            expected_phase="internal-review",
            fencing_token=self.fence,
            payload={"current": {"entry_id": "pr-one", "local_head_sha": changed_head, "remote_head_sha": changed_head}},
        )
        self.assertNotIn("pr-one", self.state_data()["review_gates"])
        stale = self.run_helper(
            "record-queue",
            state=self.state,
            expected_revision=moved["state_revision"],
            expected_phase="internal-review",
            fencing_token=self.fence,
            payload={"queue": self.queue_with_entry(publishing_entry), "reason": "stale review gate"},
        )
        self.assertEqual(stale.returncode, 4)
        refreshed = self.assert_ok(
            "record-review-gate",
            state=self.state,
            expected_revision=moved["state_revision"],
            expected_phase="internal-review",
            fencing_token=self.fence,
            payload=self.review_gate(
                "pr-one", base_sha, changed_head, self.state_data()["queue"][0]["contract_digest"]
            ),
        )
        published = self.assert_ok(
            "record-queue",
            state=self.state,
            expected_revision=refreshed["state_revision"],
            expected_phase="internal-review",
            fencing_token=self.fence,
            payload={"queue": self.queue_with_entry(publishing_entry), "reason": "fresh review gate"},
        )
        self.assertGreater(published["state_revision"], refreshed["state_revision"])
        publishing_phase = self.transition(published["state_revision"], "internal-review", "publishing")
        created_intent = self.assert_ok(
            "outbox-begin",
            state=self.state,
            expected_revision=publishing_phase["state_revision"],
            expected_phase="publishing",
            fencing_token=self.fence,
            payload={
                "operation": {
                    "operation_id": "op-reviewed-pr",
                    "kind": "pr-create",
                    "repository_id": "repo-1",
                    "base_ref": "main",
                    "head_ref": "plan-pr/01-one",
                    "expected_head_sha": changed_head,
                    "expected_base_oid": base_sha,
                    "marker": "plan-pr-loop:op=op-reviewed-pr",
                    "input_digest": "reviewed-pr-input",
                }
            },
        )
        authorized = self.assert_ok(
            "outbox-authorize",
            state=self.state,
            expected_revision=created_intent["state_revision"],
            expected_phase="publishing",
            fencing_token=self.fence,
            payload={"operation_id": "op-reviewed-pr"},
        )
        self.assertGreater(authorized["state_revision"], created_intent["state_revision"])
        numbered = self.assert_ok(
            "record-pr",
            state=self.state,
            expected_revision=authorized["state_revision"],
            expected_phase="publishing",
            fencing_token=self.fence,
            payload={"current": {"entry_id": "pr-one", "pr_number": 7}},
        )
        request = self.assert_ok(
            "outbox-begin",
            state=self.state,
            expected_revision=numbered["state_revision"],
            expected_phase="publishing",
            fencing_token=self.fence,
            payload={
                "operation": {
                    "operation_id": "op-stale-review-request",
                    "kind": "review-request",
                    "repository_id": "repo-1",
                    "pr_number": 7,
                    "target": "reviewer",
                    "expected_base_oid": base_sha,
                    "expected_head_sha": changed_head,
                    "input_digest": "stale-request-input",
                }
            },
        )
        newer_head = "6" * 40
        moved_again = self.assert_ok(
            "record-pr",
            state=self.state,
            expected_revision=request["state_revision"],
            expected_phase="publishing",
            fencing_token=self.fence,
            payload={"current": {"entry_id": "pr-one", "local_head_sha": newer_head, "remote_head_sha": newer_head}},
        )
        stale_authorization = self.run_helper(
            "outbox-authorize",
            state=self.state,
            expected_revision=moved_again["state_revision"],
            expected_phase="publishing",
            fencing_token=self.fence,
            payload={"operation_id": "op-stale-review-request"},
        )
        self.assertEqual(stale_authorization.returncode, 4)

    def test_queue_dependency_cycle_is_rejected(self) -> None:
        inventory = self.record_requirements(1, [self.requirement("R1"), self.requirement("R2")])
        result = self.run_helper(
            "record-queue",
            state=self.state,
            expected_revision=inventory["state_revision"],
            expected_phase="preflight",
            fencing_token=self.fence,
            payload={
                "queue": [
                    self.queue_entry("pr-one", ["R1"], 1, prerequisites=["pr-two"]),
                    self.queue_entry("pr-two", ["R2"], 2, prerequisites=["pr-one"]),
                ],
                "reason": "invalid queue cycle",
            },
        )
        self.assertEqual(result.returncode, 2)

    def test_completion_requires_terminal_queue_and_requirement_coverage(self) -> None:
        queued = self.seed_single_queue(include_devex=True)
        active = self.transition(queued["state_revision"], "preflight", "queued")
        premature = self.run_helper(
            "transition",
            state=self.state,
            expected_revision=active["state_revision"],
            expected_phase="queued",
            fencing_token=self.fence,
            payload={"to_phase": "complete", "reason": "too early"},
        )
        self.assertEqual(premature.returncode, 4)
        complete = self.finish_seeded_single_queue(active["state_revision"])
        self.assertEqual(complete["phase"], "complete")

    def test_completion_rejects_pending_outbox_and_undisposed_feedback(self) -> None:
        seeded = self.seed_single_queue(include_devex=True)
        queued = self.transition(seeded["state_revision"], "preflight", "queued")
        complete = self.finish_seeded_single_queue(queued["state_revision"])
        state = self.state_data()
        state["phase"] = "queued"
        state["outbox"].append(
            {
                "operation_id": "pending-review-request",
                "kind": "review-request",
                "repository_id": "repo-1",
                "pr_number": 1,
                "target": "reviewer-a",
                "input_digest": "request-input",
                "status": "pending",
            }
        )
        state["feedback"]["issue_comments"]["101"] = {
            "id": 101,
            "updated_at": "2026-08-22T15:00:00Z",
            "body_digest": "feedback-digest",
            "processing_state": "seen",
            "disposition": "actionable",
        }
        self.state.write_text(json.dumps(state), encoding="utf-8")
        result = self.run_helper(
            "transition",
            state=self.state,
            expected_revision=complete["state_revision"],
            expected_phase="queued",
            fencing_token=self.fence,
            payload={"to_phase": "complete", "reason": "must reject unresolved terminal work"},
        )
        self.assertEqual(result.returncode, 2)

    def test_schema_version_and_sensitive_key_rejection(self) -> None:
        state = self.state_data()
        state["schema_version"] = "unknown"
        self.state.write_text(json.dumps(state), encoding="utf-8")
        result = self.run_helper("validate", state=self.state)
        self.assertEqual(result.returncode, 2)

    def test_cli_error_contract(self) -> None:
        unknown = self.run_helper("not-a-command")
        self.assertEqual(unknown.returncode, 64)
        self.assertEqual(unknown.stdout, "")
        self.assertIn("unknown command", unknown.stderr)
        invalid = self.run_helper("feedback-check", state=self.state, payload={"stream": "bad", "item": {}})
        self.assertEqual(invalid.returncode, 2)
        self.assertEqual(invalid.stdout, "")
        self.assertTrue(invalid.stderr.startswith("error:"))


if __name__ == "__main__":
    unittest.main()
