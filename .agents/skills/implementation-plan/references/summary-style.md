# Final Summary Style

Write for a senior software engineer with ADHD. Preserve technical precision. Reduce the effort required to locate the state, decisions, risks, and next action.

This style combines action-oriented ADHD guidance from [i-have-adhd](https://github.com/ayghri/i-have-adhd/blob/main/skills/i-have-adhd/SKILL.md) with controlled-language principles from [asd-ste100-skill](https://github.com/danyuchn/asd-ste100-skill).

## Required shape

Start with one small mechanical action that takes less than two minutes. Include an exact link, path, or command. Put only one instruction in the sentence:

> Open `<linked first work file>`.

On the next line, state one status:

> Plan ready: `<plan-name>` in `<repo-relative-path>`. First work package: `<name>`.

If a blocking decision remains, use this status instead:

> Plan blocked: `<plan-name>` in `<repo-relative-path>`. Unblock it by `<exact decision or action>`.

Then use compact sections in this order:

1. **Outcome**: one or two sentences that define what the implementation delivers.
2. **Key decisions**: at most five bullets, ranked by architectural impact.
3. **Execution path**: a numbered list of phases or work packages. Each item names one bounded result. If the plan has more than five phases, group them under `Do first` and `Then`.
4. **Gates and risks**: at most five bullets. Put blockers and stop/go decisions before ordinary risks.
5. **Next action**: repeat one concrete action that takes less than two minutes. Link `00-overview.md` or the first work file. State the first gate or work package as context, not as the action itself. For a blocked plan, name the smallest action that advances the blocking decision.

Mention that two independent reviews and one adversarial review completed. State that accepted findings were incorporated only when at least one finding was accepted. Do not narrate the review process or list rejected feedback unless it changes user scope.

## Language rules

- Lead with the result. Do not open with a greeting, plan announcement, or generic praise.
- Assume the reader understands software architecture, testing, delivery, and version control. Explain repository-specific decisions, not standard engineering concepts.
- Use direct verbs, active voice, and one main idea per sentence.
- Use one term consistently for each component.
- Avoid idioms, marketing adjectives, stacked hedges, semicolons, and long noun clusters.
- Preserve scope qualifiers, uncertainty, and conditions. Shorter text must not change the claim.
- Use exact paths, commands, symbols, and numeric gates when the plan establishes them.
- Give effort estimates only when repository evidence supports them. State the assumptions and use concrete ranges. Otherwise omit estimates.
- Do not add tangents, a duplicate recap, or a closing invitation.

Before sending, verify that a reader who scans only the first line, section headings, and final line can identify the result, major decisions, risks, and next action.
