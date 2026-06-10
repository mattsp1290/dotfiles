# Profile Slow Linux Shell Startup

## Goal

Fix slow Linux terminal and SSH session readiness after the macOS zsh startup cleanup in commit `6b51baf Speed up zsh startup`.

The Linux target is:

- `zsh -i -c exit` under 200ms.
- `zsh -lic exit` under 200ms.
- `bash -lic exit` under 300ms when bash is used directly or indirectly.
- No startup or first-use shell integration path should run `pyenv rehash`, load NVM eagerly, run shell completion setup eagerly, or print login banners from non-login interactive shells.

## What Was Already Fixed For zsh

The latest commit changed tracked `.zshrc` to:

- Stop sourcing `~/.profile`.
- Lazy-load NVM through wrappers for `nvm`, `node`, `npm`, `npx`, `corepack`, and `pnpm`.
- Keep pyenv shims on `PATH`, while lazy-loading heavier pyenv shell integration only when `pyenv` is called. The Linux fix should update this lazy loader to use `--no-rehash`.
- Replace eager Oh My Zsh and `compinit` with a lightweight prompt and lazy completion initialization.

Current Linux zsh timings after that commit:

```text
zsh -i -c exit:
  real 0.10
  real 0.21
  real 0.09
  real 0.06
  real 0.06

zsh -lic exit:
  real 0.12
  real 0.05
  real 0.09
```

Conclusion: tracked `.zshrc` is no longer the primary Linux startup problem.

## Reproduced Linux Problem

The reported SSH target `10.0.0.106` is this host:

```text
wlo1 UP 10.0.0.106/24
ip route get 10.0.0.106 -> local 10.0.0.106 dev lo
```

The user-facing delay was reproduced with bash login startup:

```sh
for i in 1 2 3; do /usr/bin/time -p bash -lic exit; done
```

One run blocked inside:

```text
bash /home/infra-admin/.pyenv/libexec/pyenv-rehash
```

After 60 seconds it printed the same error from the report:

```text
pyenv: cannot rehash: couldn't acquire lock /home/infra-admin/.pyenv/shims/.pyenv-shim for 60 seconds. Last error message:
/home/infra-admin/.pyenv/libexec/pyenv-rehash: line 22: /home/infra-admin/.pyenv/shims/.pyenv-shim: cannot overwrite existing file
logout
real 62.18
```

Current `pyenv init -` output includes an unconditional rehash:

```sh
command pyenv rehash
```

So any shell startup file that evaluates `pyenv init -` can block for up to 60 seconds on the pyenv shim lock.

## Current Linux Startup Sources

Tracked files:

- `.zshrc` is symlinked from `~/.zshrc` and is now fast.
- `setup-linux.sh` still appends eager pyenv initialization to `~/.profile`.
- `setup-linux.sh` runs the upstream NVM installer without suppressing profile mutation.
- `setup-linux.sh` still evaluates full `pyenv init -` while installing pyenv.

Machine-local files:

- `~/.profile` contains secrets and local project environment variables.
- `~/.profile` still contains:

```sh
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
```

- `~/.bashrc` still contains eager NVM and NVM bash completion:

```sh
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
```

- `~/.bashrc` also prints an Infrastructure Control Center banner and runs:

```sh
ip route get 1 | awk '{print $7; exit}'
date
```

Those banner commands are not the 60-second bug, but they should not run for every interactive bash shell.

Bash login files on this host:

- `~/.profile` exists.
- `~/.bash_profile` and `~/.bash_login` were not present during profiling.

Future migrations should still check all three files because bash reads the first existing file among `~/.bash_profile`, `~/.bash_login`, and `~/.profile`.

## Root Cause

Linux setup diverged from the macOS fix:

1. `setup-linux.sh` installs pyenv and writes eager `eval "$(pyenv init -)"` into `~/.profile`.
2. `pyenv init -` emits `command pyenv rehash`.
3. Rehash rewrites `~/.pyenv/shims/.pyenv-shim`, which is also used as pyenv's lock target.
4. Concurrent login shells, SSH sessions, or terminal tabs contend on that lock.
5. One blocked startup waits 60 seconds, then prints the reported error.

Secondary issues:

- Bash still eagerly loads NVM and bash completion.
- Bash login startup sources `~/.profile`, which sources `~/.bashrc` when `$BASH_VERSION` is set, so login bash can pay both profile and interactive bashrc costs.
- `~/.profile` mixes POSIX login environment, shell-specific init, secrets, project env, and tool initialization. That makes it easy for setup scripts to reintroduce slow startup work.
- Fresh Linux setup can reintroduce eager NVM startup because the upstream NVM installer appends shell startup snippets by default.
- zsh first-use pyenv integration can still run `pyenv rehash` unless the lazy loader uses `pyenv init --no-rehash`.

## Plan

### 1. Suppress NVM installer profile mutation

Edit `setup-linux.sh` so future Linux setup runs do not let the upstream NVM installer append eager startup code.

Change:

```sh
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
```

to:

```sh
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | PROFILE=/dev/null bash
```

The script may still source `nvm.sh` inside setup because setup needs `nvm install node` and `npm install -g pnpm`; that setup-time cost is acceptable. The important invariant is that setup must not write eager NVM loading into `~/.profile`, `~/.bashrc`, or `~/.zshrc`.

During migration, remove old generated NVM blocks from any user startup files that contain them, especially:

- `~/.bashrc`
- `~/.profile`
- `~/.bash_profile`
- `~/.bash_login`
- `~/.zshrc`

### 2. Stop writing eager pyenv init from Linux setup

Edit `setup-linux.sh` so it no longer appends `eval "$(pyenv init -)"` to `~/.profile`.

Also replace setup-time `eval "$(pyenv init -)"` with explicit fast path setup:

```sh
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"
```

Setup may run explicit pyenv commands such as `pyenv install`, `pyenv global`, and a final intentional `pyenv rehash` after installation if needed. It must not evaluate full shell integration as a side effect of setup.

Replace the current block:

```sh
# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
```

with fast POSIX-compatible path setup only:

```sh
# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[ -d "$PYENV_ROOT/bin" ] && case ":$PATH:" in *":$PYENV_ROOT/bin:"*) ;; *) PATH="$PYENV_ROOT/bin:$PATH" ;; esac
[ -d "$PYENV_ROOT/shims" ] && case ":$PATH:" in *":$PYENV_ROOT/shims:"*) ;; *) PATH="$PYENV_ROOT/shims:$PATH" ;; esac
export PATH
```

Do not use `[[ ... ]]` in `.profile`; it is not POSIX and `.profile` can be read by `sh` or bash.

Also make the installer idempotence check specific enough that machines with the old block are migrated:

- Do not use only `grep -qF 'PYENV_ROOT' "$HOME/.profile"`.
- Detect and remove or replace lines containing `pyenv init -`.
- Add a marker pair such as `# BEGIN dotfiles pyenv path` and `# END dotfiles pyenv path` for future updates.
- Check `~/.bash_profile`, `~/.bash_login`, and `~/.profile`, because bash login startup only reads the first one that exists.

### 3. Migrate the current machine-local bash login files

On this host, `~/.profile` is the active bash login file. Remove the eager pyenv init line:

```sh
eval "$(pyenv init -)"
```

Keep these fast exports:

```sh
export PYENV_ROOT="$HOME/.pyenv"
[ -d "$PYENV_ROOT/bin" ] && case ":$PATH:" in *":$PYENV_ROOT/bin:"*) ;; *) PATH="$PYENV_ROOT/bin:$PATH" ;; esac
[ -d "$PYENV_ROOT/shims" ] && case ":$PATH:" in *":$PYENV_ROOT/shims:"*) ;; *) PATH="$PYENV_ROOT/shims:$PATH" ;; esac
export PATH
```

Keep `~/.profile` as an untracked local file because it contains secrets and deployment-specific environment variables.

If `~/.bash_profile` or `~/.bash_login` exists on another Linux host, inspect and migrate those first, because they take precedence over `~/.profile`.

Expected result: bash login startup no longer runs `pyenv rehash`, so the 60-second lock failure disappears.

### 4. Add no-rehash lazy pyenv integration for zsh and bash

Tracked `.zshrc` already lazy-loads pyenv, but its loader should use `--no-rehash` so first `pyenv` use does not hit the same lock.

Use this zsh pattern:

```zsh
_load_pyenv() {
  unfunction _load_pyenv pyenv 2>/dev/null
  command -v pyenv >/dev/null 2>&1 || return
  eval "$(pyenv init --no-rehash - zsh)"
}
```

Bash needs equivalent behavior because `~/.profile` can source `~/.bashrc` for login bash.

Add a bash-compatible lazy wrapper in an untracked shell-local file such as `~/.config/bash/local-tools.bash`, or in `~/.bashrc` if this repo starts managing bash startup:

```bash
export PYENV_ROOT="$HOME/.pyenv"
if [ -d "$PYENV_ROOT/bin" ]; then
  case ":$PATH:" in *":$PYENV_ROOT/bin:"*) ;; *) PATH="$PYENV_ROOT/bin:$PATH" ;; esac
fi
if [ -d "$PYENV_ROOT/shims" ]; then
  case ":$PATH:" in *":$PYENV_ROOT/shims:"*) ;; *) PATH="$PYENV_ROOT/shims:$PATH" ;; esac
fi
export PATH

_load_pyenv() {
  unset -f _load_pyenv pyenv
  command -v pyenv >/dev/null 2>&1 || return
  if pyenv init --help 2>&1 | grep -q -- '--no-rehash'; then
    eval "$(pyenv init --no-rehash - bash)"
  fi
}

pyenv() {
  _load_pyenv
  command pyenv "$@"
}
```

Important: do not fall back to `pyenv init - bash` or `pyenv init - zsh`; that emits `command pyenv rehash` on this installed version. If `--no-rehash` is unsupported, skip shell integration and call `command pyenv "$@"`.

### 5. Lazy-load NVM in bash

Replace eager NVM in `~/.bashrc`:

```sh
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
```

with:

```bash
export NVM_DIR="$HOME/.nvm"

_load_nvm() {
  unset -f _load_nvm nvm node npm npx corepack pnpm
  [ -s "$NVM_DIR/nvm.sh" ] || return 127
  . "$NVM_DIR/nvm.sh"
}

nvm() { _load_nvm; nvm "$@"; }
node() { _load_nvm; command node "$@"; }
npm() { _load_nvm; command npm "$@"; }
npx() { _load_nvm; command npx "$@"; }
corepack() { _load_nvm; command corepack "$@"; }
pnpm() { _load_nvm; command pnpm "$@"; }
```

Do not source NVM bash completion during startup. If NVM completion is needed, source it inside `_load_nvm` after first NVM-related use.

### 6. Move bash completion out of the hot path

The default `~/.bashrc` sources `/usr/share/bash-completion/bash_completion` for every interactive bash shell.

For this machine, disable it or lazy-load it behind programmable completion use. Since zsh is the default shell, the pragmatic first step is to remove eager bash completion from `~/.bashrc` and only re-add it if there is a specific bash workflow that needs it.

### 7. Gate login banners

The Infrastructure Control Center banner in `~/.bashrc` should not run for every shell. Keep it only for a real terminal login and make it opt-out for automation:

```bash
if shopt -q login_shell && [ -t 1 ] && [ -z "${DOTFILES_QUIET_LOGIN:-}" ]; then
  echo "Infrastructure Control Center - $(hostname)"
  echo "   IP: $(ip route get 1 | awk '{print $7; exit}') | $(date)"
  echo "   Infrastructure: /opt/infrastructure | Logs: tail -f /opt/infrastructure/logs/*.log"
fi
```

This is not the main delay, but it reduces noisy and unnecessary process startup.

### 8. Keep `.profile` boring

Going forward, `.profile` should only contain:

- Fast `export` statements.
- Fast `PATH` setup.
- Bash's standard `if [ -n "$BASH_VERSION" ]; then . ~/.bashrc; fi` block if wanted.

It should not contain:

- `eval "$(tool init ...)"`.
- `pyenv init`, `nvm.sh`, `rbenv init`, `direnv hook`, `mise activate`, or completion setup.
- Network calls.
- Banners.
- Commands that can block on locks.

If a variable is secret or host-specific, keep it untracked under `~/.config/profile/local-env.sh` or `~/.config/profile/local-secrets.sh` and source those from `~/.profile`.

## Proposed Implementation Order

1. Patch `setup-linux.sh` so future NVM installs use `PROFILE=/dev/null`.
2. Patch `setup-linux.sh` so future pyenv installs use explicit `PATH` setup, not `pyenv init -`, and append only no-rehash path setup to `.profile`.
3. Patch tracked `.zshrc` so lazy pyenv integration uses `pyenv init --no-rehash - zsh`.
4. Verify whether `~/.bash_profile`, `~/.bash_login`, or `~/.profile` is active on this host; migrate the active bash login file and any other files containing `pyenv init -`.
5. Apply the same migration on this host's `~/.profile`.
6. Replace eager NVM in `~/.bashrc` with lazy wrappers.
7. Remove or lazy-load eager bash completion from `~/.bashrc`.
8. Gate the Infrastructure Control Center banner with `shopt -q login_shell`.
9. Re-profile zsh, bash, and SSH-to-self startup with commands that exercise login and interactive shells.
10. Only if zsh regresses, inspect `.zshrc` again; current zsh measurements are already within budget.

## Verification Commands

Use timeouts when testing bash login startup until the pyenv lock issue is fixed:

```sh
for i in 1 2 3 4 5; do /usr/bin/time -p zsh -i -c exit; done
for i in 1 2 3 4 5; do /usr/bin/time -p zsh -lic exit; done
for i in 1 2 3; do timeout 8 /usr/bin/time -p bash -lic exit; done
for i in 1 2 3; do timeout 8 /usr/bin/time -p bash -i -c exit; done
```

Verify bash login source order:

```sh
for f in ~/.bash_profile ~/.bash_login ~/.profile; do [ -e "$f" ] && printf '%s\n' "$f"; done
```

Confirm no startup rehash is running:

```sh
ps -eo pid,ppid,stat,etime,cmd | rg 'pyenv|rehash|bash -lic|zsh -lic' || true
```

Confirm pyenv still works on first use:

```sh
timeout 8 zsh -lic 'command -v python; python --version; pyenv version-name 2>/dev/null || true'
timeout 8 bash -lic 'command -v python; python --version; pyenv version-name 2>/dev/null || true'
```

Confirm NVM still works on first use:

```sh
zsh -lic 'command -v node; node --version; nvm current'
bash -lic 'command -v node; node --version; nvm current'
```

Confirm SSH-to-self no longer waits on pyenv:

```sh
for i in 1 2 3; do /usr/bin/time -p ssh infra-admin@10.0.0.106 'bash -lic exit'; done
for i in 1 2 3; do /usr/bin/time -p ssh infra-admin@10.0.0.106 'zsh -lic exit'; done
ssh -tt infra-admin@10.0.0.106 'bash -lic exit'
```

If Ghostty still prints `Setting up xterm-ghostty terminfo on 10.0.0.106...` on every SSH, verify terminfo separately:

```sh
infocmp xterm-ghostty >/dev/null
find ~/.terminfo -type f | sort | rg 'ghostty|xterm'
```

Ghostty's terminfo setup is separate from the pyenv 60-second lock. Treat it as a follow-up only if it repeats after pyenv startup is fixed.

## Risks

- Removing eager `pyenv init -` changes shell function availability at startup, but pyenv shims still keep `python`, `python3`, and `pip` working.
- Some bash users may expect NVM globals to be on `PATH` immediately. Add explicit wrappers for required globals rather than loading all of NVM at startup.
- `~/.profile` contains secrets. Do not copy it into this repo.
- `setup-linux.sh` currently has broad idempotence checks. If they remain broad, future setup runs can fail to repair old slow blocks.
