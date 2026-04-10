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
