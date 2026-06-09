# Profile Slow Shell Startup

## Goal

Reduce new terminal tab readiness time by moving expensive shell startup work out of the eager path. The target is both interactive `zsh -i -c exit` and macOS-style login interactive `zsh -lic exit` startup under 200ms on this machine, while preserving existing commands through lazy loading. If `~/.zprofile` remains above that budget, document the remaining login-shell cost explicitly.

## Current Startup Path

Tracked repo file:

- `.zshrc` is linked from `~/.zshrc`.
- It sets base paths and environment, then eagerly loads Cargo, NVM, NVM bash completion, Oh My Zsh, history bindings, opencode path, and finally `source $HOME/.profile`.

Login shell file outside this repo:

- `~/.zprofile` runs Homebrew shellenv and `rbenv init`.

Additional local file outside this repo:

- `~/.profile` is sourced by `.zshrc` on every interactive shell.
- It contains many environment exports, several duplicate path entries, `pyenv init --path`, `pyenv init -`, another Cargo load, and a network call via `curl -4 -s ifconfig.me`.
- It also contains sensitive credentials, so the fix should avoid copying it into tracked repo files.

## Measurements

Commands used:

```sh
for i in 1 2 3 4 5; do /usr/bin/time -p zsh -i -c exit; done
for i in 1 2 3; do /usr/bin/time -p zsh -lic exit; done
```

Observed startup:

- Interactive non-login shell: about 1.0s to 1.3s.
- Login interactive shell: about 1.0s to 1.3s.

Function-level `zprof` top costs:

- `nvm_auto`: about 514ms total, about 275ms self.
- `nvm`: about 211ms total.
- `compinit`: about 336ms total.
- `compdump`: about 115ms total.
- `compdef`: about 116ms total across 1657 calls.

`zprof` total times include callees, so these rows are not additive. Use self time and controlled startup variants for prioritization.

Isolated command timings:

- `nvm.sh`: about 380ms to 400ms.
- Oh My Zsh with `plugins=(git)`: about 70ms.
- `pyenv init --path`: about 110ms.
- `pyenv init -`: about 120ms to 140ms.
- `source ~/.profile`: about 310ms to 320ms.
- `curl -4 -s ifconfig.me`: about 100ms in this run, with potential for much worse latency when the network is slow.
- `brew shellenv`: about 30ms.
- `rbenv init - --no-rehash zsh`: about 30ms to 40ms.
- Cargo env load: effectively 0ms.

Controlled startup variants:

| Variant | Average startup |
| --- | ---: |
| Baseline | 1.176s |
| Without NVM block | 0.602s |
| Without `source ~/.profile` | 0.740s |
| Without Oh My Zsh | 1.046s |
| Without NVM and `~/.profile` | 0.118s |
| Without NVM, `~/.profile`, and Oh My Zsh | 0.010s |

Conclusion: the first fixes should be lazy NVM and removing eager `~/.profile` sourcing. Oh My Zsh/completion optimization is useful but lower priority once those are fixed.

## Plan

### 1. Split local environment from interactive startup

Stop sourcing all of `~/.profile` from `.zshrc`.

Do not delete or overwrite `~/.profile` during this migration. First stop sourcing it from `.zshrc`, keep the file as a rollback/reference artifact, and only archive it after environment parity checks pass.

Split local state by purpose:

- `~/.config/zsh/local-env.zsh` for non-secret fast exports.
- `~/.config/zsh/local-secrets.zsh` for terminal-required secrets, with mode `600`.

Rules for those files:

- Only `export` statements and cheap path setup.
- No network calls.
- No `eval "$(tool init ...)"`.
- No command substitutions except trivial local file reads that are known to be fast.
- Keep both files outside the dotfiles repo. Prefer tool-specific credential stores or wrappers for secrets only needed by one workflow.

Then change `.zshrc` to source only those fast local files if they exist:

```zsh
[[ -r "$HOME/.config/zsh/local-env.zsh" ]] && source "$HOME/.config/zsh/local-env.zsh"
[[ -r "$HOME/.config/zsh/local-secrets.zsh" ]] && source "$HOME/.config/zsh/local-secrets.zsh"
```

Move expensive `~/.profile` work into lazy wrappers or tool-specific files instead of preserving it as one global startup file.

Before cutting over, inventory which variable names are currently added by `~/.profile` without printing secret values:

```sh
zsh -i -c 'env | cut -d= -f1 | sort' > /tmp/env.with-profile
# After temporarily disabling source ~/.profile:
zsh -i -c 'env | cut -d= -f1 | sort' > /tmp/env.without-profile
comm -23 /tmp/env.with-profile /tmp/env.without-profile
```

Categorize each missing variable as fast local env, secret local env, lazy wrapper, login-only, or obsolete.

Expected impact: about 300ms average saved, more when network is slow.

### 2. Lazy-load NVM

Replace eager NVM loading:

```zsh
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
```

with a lazy wrapper:

```zsh
export NVM_DIR="$HOME/.nvm"

_load_nvm() {
  unset -f _load_nvm nvm node npm npx corepack
  [[ -s "$NVM_DIR/nvm.sh" ]] || return 127
  source "$NVM_DIR/nvm.sh"
}

nvm() { _load_nvm; nvm "$@"; }
node() { _load_nvm; node "$@"; }
npm() { _load_nvm; npm "$@"; }
npx() { _load_nvm; npx "$@"; }
corepack() { _load_nvm; corepack "$@"; }
```

Do not source NVM bash completion at startup. If NVM command completion is important, load it inside `_load_nvm` after the first NVM-related command. Completion for `node`, `npm`, and `npx` does not need to block terminal readiness.

This preserves `nvm`, `node`, `npm`, `npx`, and `corepack` on first use, but it does not automatically preserve every global binary installed under the active NVM version. Before implementation, inventory global Node workflows:

```sh
zsh -i -c 'command -v node npm npx pnpm yarn vite tsx eslint codex opencode; npm prefix -g; npm ls -g --depth=0'
```

For required global CLIs such as `pnpm`, `yarn`, `vite`, `tsx`, or `eslint`, either add explicit wrappers, keep a stable non-NVM Node installation on `PATH`, or document that those commands become available after the first NVM/Node command loads NVM.

Expected impact: about 500ms to 600ms average saved.

### 3. Lazy-load Pyenv

Keep `PYENV_ROOT` and path setup cheap:

```zsh
export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && path=("$PYENV_ROOT/bin" $path)
[[ -d "$PYENV_ROOT/shims" ]] && path=("$PYENV_ROOT/shims" $path)
```

Keep pyenv shims on `PATH` so `python`, `python3`, `pip`, and shebangs still use pyenv-selected versions. Replace eager shell integration with a wrapper for the `pyenv` command itself:

```zsh
_load_pyenv() {
  unset -f _load_pyenv pyenv
  command -v pyenv >/dev/null 2>&1 || return
  eval "$(pyenv init - zsh)"
}

pyenv() { _load_pyenv; pyenv "$@"; }
```

If automatic Python version switching requires more than shims in a specific workflow, defer the heavier shell integration until after the first prompt or use a directory-change hook that loads pyenv only when a `.python-version` file is present.

Expected impact if removed from `~/.profile`: about 220ms to 250ms.

### 4. Remove network calls from startup

Do not compute `TF_VAR_namecheap_client_ip` during shell startup.

Replace it with one of these:

- A function, for interactive use:

```zsh
refresh_namecheap_client_ip() {
  export TF_VAR_namecheap_client_ip="$(curl -4 -s ifconfig.me)"
}
```

- A Terraform wrapper that computes the value only before Terraform commands that need it.
- A cached file with a TTL if the value is needed often.

Expected impact in this run: about 100ms. More importantly, this prevents terminal startup from blocking on network problems.

### 5. Clean up PATH and duplicate tool initialization

Normalize path handling in `.zshrc` with zsh's `path` array and dedupe:

```zsh
typeset -U path PATH
path=(
  "$HOME/.local/bin"
  "$HOME/.opencode/bin"
  "$HOME/go/bin"
  "$HOME/.nimble/bin"
  $path
)
export PATH
```

Also avoid loading Cargo twice:

- `.zshrc` already loads `~/.cargo/env`.
- `~/.profile` currently loads it again.

Expected impact: small, but this reduces confusing state and avoids future startup regressions.

### 6. Optimize completions after the major fixes

Oh My Zsh is not the primary issue, but completions are still visible in `zprof`.

Options:

- Keep Oh My Zsh for now and investigate why `compdump` is visible on every run: stale/missing `.zcompdump`, a changing `$ZSH_COMPDUMP`, or completion audit work.
- Disable `compfix` if the completion directories are trusted:

```zsh
ZSH_DISABLE_COMPFIX=true
```

Set `ZSH_DISABLE_COMPFIX=true` before `source $ZSH/oh-my-zsh.sh`.

- Consider replacing Oh My Zsh with direct `compinit` plus the small subset of features actually used.

Because removing NVM and `~/.profile` already brings startup to about 118ms, do this only after verifying the first two changes.

## Proposed Implementation Order

1. Add timing helpers for repeatable local profiling, either as `.agents/scripts/profile-zsh-startup.sh` or documented commands in this plan.
2. Edit `.zshrc` to remove eager NVM and replace it with lazy wrappers.
3. Inventory env names added by `~/.profile` and categorize each as fast local env, secret local env, lazy wrapper, login-only, or obsolete.
4. Edit `.zshrc` to stop sourcing `~/.profile`; source optional fast local env and local secrets files instead.
5. Move required fast exports and terminal-required secrets into local untracked files, without deleting `~/.profile`.
6. Preserve pyenv shims while lazy-loading heavier pyenv shell integration.
7. Remove or lazy-wrap the Namecheap IP lookup from the local startup path.
8. Re-profile.
9. Only then decide whether to optimize or replace Oh My Zsh.

## Verification

Before and after each change:

```sh
for i in 1 2 3 4 5; do /usr/bin/time -p zsh -i -c exit; done
for i in 1 2 3; do /usr/bin/time -p zsh -lic exit; done
```

After lazy loading:

```sh
zsh -lic 'command -v node; node --version; nvm current'
zsh -lic 'command -v npm; npm --version'
zsh -lic 'command -v npx; npx --version'
zsh -lic 'command -v python; python --version; pyenv version-name 2>/dev/null || true'
zsh -lic 'command -v pip; pip --version'
zsh -lic 'command -v pnpm yarn vite tsx eslint codex opencode || true'
```

Verify project-local version files if those workflows matter:

```sh
tmp=$(mktemp -d)
printf '%s\n' 'lts/*' > "$tmp/.nvmrc"
zsh -lic "cd $tmp && node --version && nvm current"

tmp=$(mktemp -d)
pyver="$(pyenv version-name 2>/dev/null || true)"
[[ -n "$pyver" ]] && printf '%s\n' "$pyver" > "$tmp/.python-version"
[[ -n "$pyver" ]] && zsh -lic "cd $tmp && command -v python && python --version && pyenv version-name"
```

Expected result:

- `zsh -i -c exit` and `zsh -lic exit` should be under 200ms, or any remaining login-shell cost should be explained.
- `node`, `npm`, `nvm`, and `pyenv` should still work on first invocation.
- `python` and `pip` should resolve through pyenv shims when pyenv is installed.
- Required NVM global CLIs should either work directly or have a documented first-use loading requirement.
- New tabs should no longer block on `curl ifconfig.me`.

## Risks

- Removing `source ~/.profile` may hide environment variables that some old workflows expect in every terminal. Mitigation: migrate only the needed fast exports into an untracked local env file and move workflow-specific secrets into tool-specific wrappers.
- Lazy NVM means the active Node version is not selected until the first Node-related command. If prompt code or startup hooks call `node`, that first prompt may still pay the NVM cost. Current `.zshrc` does not appear to require Node during prompt setup.
- Pyenv shims and automatic directory switching may need extra handling if current workflows rely on immediate `pyenv init` behavior.
