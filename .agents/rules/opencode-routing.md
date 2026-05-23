# OpenCode Routing

You have access to OpenCode CLI as a fourth delegation target via the `/opencode` skill.
OpenCode gives you access to other AI models (ChatGPT via OpenAI, Gemini via Google).

## When to consider OpenCode

Use `/opencode` when the user **explicitly asks** for a second opinion, alternative perspective,
or specific non-Claude model. Do not auto-delegate without being asked.

Suggested uses (only when the user requests them):
- Code review with a different perspective: `/opencode review "..."`
- UI/front-end feedback where Gemini excels: `/opencode ui "..."`
- Side-by-side comparison: run the same prompt through OpenCode and compare to your own answer
- Tasks where the user explicitly mentions ChatGPT or Gemini

## When NOT to use OpenCode

- Routine coding tasks: use Sonnet sub-agents directly
- Search/exploration tasks: use Haiku
- When the user hasn't asked for an external model

## Proactive suggestion (light touch only)

For code review tasks where the user asks for a thorough review, you MAY offer:
> "I can also get a second opinion from ChatGPT via `/opencode review`. Want me to run that too?"

Do NOT make this offer more than once per conversation. If the user declines, drop it.

## Model routing

When the user invokes `/opencode` with a task type:
- `review` → `openai/gpt-5.4` (latest ChatGPT confirmed working)
- `ui` → `google/gemini-3-pro-preview` (requires Gemini configuration)

For direct model specification, trust the user's input. If the model fails, show the error and
suggest checking `opencode models <provider>` for valid model names.

## Calling OpenCode from within skills

When a skill (e.g., `/review`, `/pr-ready`) needs to call OpenCode as part of its execution,
call the wrapper script directly via Bash — do NOT invoke the `/opencode` skill via the Skill tool.
The `/opencode` skill is designed for user-invoked delegation, not for skill-to-skill chaining.

Direct invocation pattern:
```bash
bash $HOME/.claude/skills/opencode/opencode_run.sh \
  --task-name "<name>" \
  --model "openai/gpt-5.4" \
  --timeout 120 \
  "<prompt>"
```

**Timeout guidance**: Use the wrapper's `--timeout` flag for the actual process timeout.
Keep the Bash tool timeout moderate (120000-300000ms). Very high Bash timeouts (600000ms)
cause the Bash tool to auto-background the command, which breaks the NDJSON stream parsing
in `opencode_run.sh` — output stays empty. For long-running OpenCode tasks (reviews with
tool use), the files written to disk by the model matter more than stdout.

## Sanctioned auto-delegation exception

`/big-change` and `/new-project` auto-invoke a GPT review pass as a sanctioned, opt-out part of their defined workflow. They call `$HOME/.claude/skills/opencode/opencode_run.sh` directly for clean exit-code-based failure handling; this direct-wrapper invocation is the only auto-delegation path sanctioned by this rule. The general 'do not auto-delegate without an explicit user request' rule still applies to every other use of `/opencode` and inside every other skill. If the initial review wrapper call fails with a non-zero exit for any reason, these two skills are authorized to retry once with `openai/gpt-5.4-fast` in a fresh session before giving up; this is the only sanctioned model fallback.
