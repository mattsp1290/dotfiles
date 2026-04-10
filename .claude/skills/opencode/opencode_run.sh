#!/usr/bin/env bash
set -euo pipefail

OPENCODE="$HOME/.opencode/bin/opencode"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
SESSIONS_FILE="$SCRIPT_DIR/../../opencode-sessions.json"

# --- Argument parsing ---
# Usage: opencode_run.sh [--task-name NAME] [--session-id ID] [--model MODEL]
#                        [--permissions full|readonly] PROMPT...
TASK_NAME="default"
SESSION_ID=""
MODEL="openai/gpt-5.4"
PERMISSIONS="readonly"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --task-name) TASK_NAME="$2"; shift 2 ;;
        --session-id) SESSION_ID="$2"; shift 2 ;;
        --model) MODEL="$2"; shift 2 ;;
        --permissions) PERMISSIONS="$2"; shift 2 ;;
        --) shift; break ;;
        -*) echo "Error: unknown flag: $1" >&2; exit 1 ;;
        *) break ;;
    esac
done

PROMPT="${*}"
if [[ -z "$PROMPT" ]]; then
    echo "Error: no prompt provided" >&2
    echo "Usage: opencode_run.sh [--task-name NAME] [--model MODEL] [--permissions full|readonly] PROMPT..." >&2
    exit 1
fi

# --- Session ID resolution ---
if [[ -z "$SESSION_ID" && -f "$SESSIONS_FILE" ]]; then
    SESSION_ID=$(python3 -c "
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    print(data.get(sys.argv[2], {}).get('session_id', ''))
except Exception:
    print('')
" "$SESSIONS_FILE" "$TASK_NAME" 2>/dev/null || echo "")
fi

# --- Build opencode command ---
CMD=("$OPENCODE" run)

if [[ -n "$SESSION_ID" ]]; then
    CMD+=(-s "$SESSION_ID")
fi

CMD+=(-m "$MODEL" --format json)

if [[ "$PERMISSIONS" == "full" ]]; then
    CMD+=(--dangerously-skip-permissions)
fi

CMD+=("$PROMPT")

# --- Run and parse NDJSON ---
OUTPUT_TEXT=""
OUTPUT_SESSION_ID=""
ERROR_MSG=""
COST=""
TOKENS_IN=""
TOKENS_OUT=""

while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    TYPE=$(echo "$line" | jq -r '.type // empty' 2>/dev/null) || continue

    case "$TYPE" in
        text)
            CHUNK=$(echo "$line" | jq -r '.part.text // empty' 2>/dev/null)
            OUTPUT_TEXT+="$CHUNK"
            if [[ -z "$OUTPUT_SESSION_ID" ]]; then
                OUTPUT_SESSION_ID=$(echo "$line" | jq -r '.sessionID // empty' 2>/dev/null)
            fi
            ;;
        step_start)
            if [[ -z "$OUTPUT_SESSION_ID" ]]; then
                OUTPUT_SESSION_ID=$(echo "$line" | jq -r '.sessionID // empty' 2>/dev/null)
            fi
            ;;
        step_finish)
            COST=$(echo "$line" | jq -r '.part.cost // empty' 2>/dev/null)
            TOKENS_IN=$(echo "$line" | jq -r '.part.tokens.input // empty' 2>/dev/null)
            TOKENS_OUT=$(echo "$line" | jq -r '.part.tokens.output // empty' 2>/dev/null)
            ;;
        tool_call)
            TOOL_NAME=$(echo "$line" | jq -r '.part.tool // empty' 2>/dev/null)
            [[ -n "$TOOL_NAME" ]] && echo "[opencode] tool use: $TOOL_NAME" >&2
            ;;
        error)
            ERROR_MSG=$(echo "$line" | jq -r '.error.data.message // .error.name // "unknown error"' 2>/dev/null)
            ;;
    esac
done < <("${CMD[@]}" 2>/dev/null)

# --- Error handling ---
if [[ -n "$ERROR_MSG" ]]; then
    echo "Error from OpenCode: $ERROR_MSG" >&2
    exit 1
fi

if [[ -z "$OUTPUT_TEXT" ]]; then
    echo "Error: no text output received from OpenCode" >&2
    exit 1
fi

# --- Persist session ID ---
if [[ -n "$OUTPUT_SESSION_ID" ]]; then
    python3 - "$SESSIONS_FILE" "$TASK_NAME" "$OUTPUT_SESSION_ID" "$MODEL" <<'PYEOF'
import json, os, sys
from datetime import datetime, timezone

path = sys.argv[1]
task_name = sys.argv[2]
session_id = sys.argv[3]
model = sys.argv[4]

data = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except (json.JSONDecodeError, IOError):
        data = {}

data[task_name] = {
    "session_id": session_id,
    "model": model,
    "last_updated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
}

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PYEOF
fi

# --- Output ---
echo "$OUTPUT_TEXT"

# Metadata to stderr
{
    [[ -n "$COST" ]] && printf "[cost: \$%s]" "$COST"
    [[ -n "$TOKENS_IN" ]] && printf " [tokens: %s in, %s out]" "$TOKENS_IN" "$TOKENS_OUT"
    [[ -n "$OUTPUT_SESSION_ID" ]] && printf " [session: %s]" "$OUTPUT_SESSION_ID"
    printf "\n"
} >&2
