---
name: opencode
description: Delegate a task to OpenCode CLI, routing to ChatGPT or Gemini as subagents
user-invocable: true
allowed-tools: Bash, Read
---

# OpenCode Subagent Skill

Delegate tasks to non-Claude AI models via the OpenCode CLI. Gives you access to ChatGPT (OpenAI) and Gemini (Google) as subagents.

## Usage

```
/opencode <task-type> <prompt>
/opencode --model <provider/model> <prompt>
/opencode --continue <task-name> <prompt>
/opencode --task-name <name> [--model ...] [--permissions full] <prompt>
```

### Examples

```
/opencode review Review this PR for security issues
/opencode ui Review this React component for accessibility
/opencode --model openai/o4-mini Explain this algorithm concisely
/opencode --continue review Now also check the test coverage
/opencode --task-name auth-refactor --permissions full Refactor auth to use JWT
```

## Task-Type → Model Routing

| Task type | Model | Provider |
|-----------|-------|----------|
| `review` | `openai/gpt-5.4` | OpenAI (ChatGPT) |
| `ui` | `google/gemini-3-pro-preview` | Google (Gemini) |

Update these model IDs as newer models become available. Check valid models with:
```bash
$HOME/.opencode/bin/opencode models openai
$HOME/.opencode/bin/opencode models google
```

## Instructions

### Phase 1 — Parse arguments

Parse `$ARGUMENTS` to extract:

1. **Flags** (consume before the prompt):
   - `--continue <name>`: continue an existing session by task name
   - `--task-name <name>`: set the session persistence key
   - `--model <provider/model>`: override the model (bypasses task-type routing)
   - `--permissions full`: allow OpenCode to edit files and run commands

2. **Task type** (first non-flag word, if it matches a known type):
   - `review` → model `openai/gpt-5.4`, task-name defaults to `review`
   - `ui` → model `google/gemini-3-pro-preview`, task-name defaults to `ui`
   - If no task type matches, use default model `openai/gpt-5.4`

3. **Prompt**: everything remaining after flags and task type

If `--continue` is provided without `--model`, the model from the saved session is reused. If `--model` is also provided, it overrides for this turn.

If no arguments are provided, ask the user what they'd like to delegate.

### Phase 2 — Validate

1. Check `$HOME/.opencode/bin/opencode` exists. If not:
   > OpenCode is not installed. Expected at `$HOME/.opencode/bin/opencode`.

2. If the resolved model starts with `google/`, verify Gemini is configured:
   ```bash
   $HOME/.opencode/bin/opencode providers list 2>&1
   ```
   If no Google credentials appear, stop and tell the user:
   > Gemini is not configured. See `$HOME/.claude/skills/opencode/gemini-setup.md` for setup instructions.
   >
   > Read and present the setup steps from that file to the user.

3. If `--permissions full` is set, warn the user before proceeding:
   > This will run OpenCode with `--dangerously-skip-permissions`, allowing it to modify files and run terminal commands. Proceed?

   Wait for confirmation. Do NOT proceed without it.

### Phase 3 — Execute

Run the wrapper script:

```bash
bash $HOME/.claude/skills/opencode/opencode_run.sh \
  --task-name "<task-name>" \
  --model "<model>" \
  [--permissions full] \
  "<prompt>"
```

Capture stdout (response text) and stderr (cost/session metadata).

If the script exits non-zero, read the stderr output and present the error. Common fixes:
- "Model not found" → check model name with `opencode models <provider>`
- Auth errors → check API key environment variable
- No output → model may have refused the prompt or timed out

### Phase 4 — Present output

1. Show the response text from OpenCode (stdout)
2. Show the model used and cost (from stderr)
3. Show the continuation hint:
   > Session saved as `<task-name>`. To continue: `/opencode --continue <task-name> "followup"`

If continuing an existing session, note that context was preserved:
   > Continued session `<task-name>` (turn N). Full conversation context was available to the model.
