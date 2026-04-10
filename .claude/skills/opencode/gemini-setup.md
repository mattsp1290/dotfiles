# Gemini Setup for OpenCode

OpenCode supports Google Gemini models via the `google/` provider prefix.
This requires the `opencode-gemini-auth` plugin and a one-time OAuth login.

## Step 1: Install the plugin

Create or edit `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["opencode-gemini-auth@latest"]
}
```

If you already have other plugins, add `"opencode-gemini-auth@latest"` to the existing array.

## Step 2: Authenticate

Run:

```bash
$HOME/.opencode/bin/opencode providers login
```

1. Select **Google** from the provider list
2. Choose **OAuth with Google (Gemini CLI)**
3. A browser window opens — approve the request
4. The plugin captures the callback automatically

## Step 3: Verify

Check that Google appears in your providers:

```bash
$HOME/.opencode/bin/opencode providers list
```

List available Gemini models:

```bash
$HOME/.opencode/bin/opencode models google
```

## Step 4: Test

```bash
$HOME/.opencode/bin/opencode run "Say hello" -m google/gemini-2.5-pro --format json
```

You should see NDJSON output with a text response.

## Available Models

Once configured, common models include:
- `google/gemini-2.5-flash` — fast, cheap
- `google/gemini-2.5-pro` — more capable
- `google/gemini-3-flash-preview` — latest fast model
- `google/gemini-3-pro-preview` — latest capable model (used by `/opencode ui`)

Run `$HOME/.opencode/bin/opencode models google` for the full current list.

## Optional: Project ID

If using an organization Google Workspace account or Gemini Code Assist subscription,
you may need to configure a project ID:

```json
{
  "provider": {
    "google": {
      "options": {
        "projectId": "your-project-id"
      }
    }
  }
}
```

Or set via environment variable: `OPENCODE_GEMINI_PROJECT_ID="your-project-id"`

Individual Google accounts typically do not need this.

## Troubleshooting

- **"Provider not found: google"** — plugin not installed. Check step 1.
- **OAuth flow hangs** — try `opencode providers logout` then re-login.
- **"Model not found"** — run `opencode models google` to check available model IDs.
- **Rate limit errors** — free tier has per-minute limits. Wait or switch models.
- **Quota info** — use `/gquota` inside the OpenCode TUI to check remaining quota.
