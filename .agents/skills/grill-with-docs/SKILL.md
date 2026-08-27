---
name: grill-with-docs
description: Relentlessly stress-test a plan or design while capturing resolved domain language in CONTEXT.md and durable architectural decisions in ADRs. Use only when the user explicitly asks to be grilled with documentation.
---

# Grill With Docs

Interview the user until the plan's decision tree is exhausted and shared understanding is reached. While the design is being sharpened, keep its domain language and durable decisions synchronized with the repository. This skill is stateful: invoking it authorizes the documentation updates described below, but not implementation of the plan.

## Establish the repository context

Before asking design questions:

1. Derive the plan, design, decision, or idea to examine from the conversation or an explicit path. If there is no identifiable target, ask the user for it.
2. Read relevant plans, code, tests, and existing documentation.
3. If `CONTEXT-MAP.md` exists at the repository root, use it to locate the applicable bounded context and its `CONTEXT.md` and ADR directory.
4. Otherwise, use the root `CONTEXT.md` and `docs/adr/` if present.
5. Resolve discoverable facts from the environment. Delegate independent research when subagents are available and doing so reduces latency; never ask the user for facts that can be inspected directly.

Do not create documentation directories or files until there is resolved content to record.

## Grill the design

Represent the discussion as a decision tree. A decision becomes eligible only after its prerequisites are settled. In each round:

1. Recompute the frontier: all currently eligible, unresolved decisions.
2. Ask every frontier question, numbered, with a concise title and a recommended answer. Include alternatives and material trade-offs when useful.
3. Wait for the user's answers before advancing dependent branches.
4. Treat decisions as the user's to make. Challenge contradictions and weak assumptions; do not silently choose for them.

Start each round with a compact progress line such as `Round 2 · 4 settled · 3 on frontier`. Group questions by decision-tree branch when a round spans several branches, label discrete choices `A`, `B`, `C`, separate question blocks with a horizontal rule, and finish with a minimal reply skeleton such as `Q1: …; Q2: …`.

Use this shape:

```md
**Q1 — <title>**

<question and relevant options>

Recommendation: <answer and brief rationale>

---

**Q2 — <title>**

<question and relevant options>

Recommendation: <answer and brief rationale>
```

Keep independent questions in the same round. Move a question to a later round whenever its answer depends on another open question. A pending fact-finding task also counts as an unresolved prerequisite, but it should block only its downstream branch.

The interview is complete when the frontier is empty: every meaningful branch has been visited and no consequential assumption remains implicit. Ask the user to confirm that shared understanding has been reached. Do not implement the plan during this workflow.

## Model the domain as answers crystallize

Apply these rules during the interview, not as a cleanup pass:

- **Challenge inconsistent vocabulary.** If the user's term conflicts with an existing glossary definition, quote the conflict and resolve it.
- **Sharpen overloaded terms.** Propose one canonical name when a word refers to multiple concepts or multiple words refer to the same concept.
- **Probe concrete scenarios.** Invent edge cases that expose unclear boundaries, ownership, lifecycle, or relationships.
- **Check statements against the repository.** Surface contradictions between the proposed model, existing docs, and actual behavior in code or tests.
- **Record resolved terms immediately.** Update the applicable `CONTEXT.md` as soon as the user settles the concept.
- **Keep the glossary conceptual.** Exclude implementation details, specifications, scratch notes, and general programming terms.

If multiple contexts exist and the correct target is genuinely ambiguous, make context ownership the next eligible decision.

## `CONTEXT.md` format

For a single-context repository, create `CONTEXT.md` at the root when the first term is settled. In a multi-context repository, follow `CONTEXT-MAP.md` and update the context-specific file.

```md
# <Context Name>

<One or two sentences describing this domain context.>

## Language

**<Canonical Term>**:
<A one- or two-sentence definition of what the concept is.>
_Avoid_: <ambiguous or deprecated synonyms>
```

Only add `_Avoid_` when alternatives are worth calling out. Choose an opinionated canonical term, keep definitions short, and group terms under additional headings only when stable clusters emerge.

## ADR rules and format

Offer an ADR only when the decision meets all three tests:

1. Reversing it later would be materially expensive.
2. A future maintainer would find the choice surprising without its rationale.
3. The choice resolved a real trade-off between credible alternatives.

When the user accepts the offer, honor an ADR directory explicitly declared by `CONTEXT-MAP.md`. Otherwise, place a context-owned decision in that context's `docs/adr/` and a system-wide or cross-context decision in the repository-root `docs/adr/`. If ownership is ambiguous, make scope the next frontier decision. Create the directory lazily. Scan the target directory's existing ADRs, increment the highest numeric prefix, and use `NNNN-kebab-case-title.md`.

Default to the smallest useful record:

```md
# <Decision title>

<One to three sentences describing the context, decision, and rationale.>
```

Add status frontmatter (`proposed | accepted | deprecated | superseded by ADR-NNNN`), considered options, or consequences only when they preserve information a future reader is likely to need. Architecture, context boundaries, integration patterns, high-lock-in technology choices, non-obvious constraints, and deliberate deviations commonly qualify. Routine or easily reversed choices do not.

## Completion

Once the user confirms shared understanding:

1. Ensure every settled domain term and accepted ADR is already written.
2. Summarize the agreed design, important trade-offs, documentation changed, and any explicitly deferred decisions.
3. Stop without implementing unless the user separately asks for implementation.

## Provenance

Adapted for Codex from Matt Pocock's `grill-with-docs`, `grilling`, and `domain-modeling` skills: <https://github.com/mattpocock/skills>.

```text
MIT License

Copyright (c) 2026 Matt Pocock

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
