# Implementation Notes

## Review Feedback Applied

Two independent subagents reviewed the Linux plan. Both requested changes before implementation. Accepted feedback included:

- Suppress upstream NVM installer startup-file mutation with `PROFILE=/dev/null`.
- Remove full `pyenv init -` from setup-time and shell-startup paths.
- Use `pyenv init --no-rehash` for lazy zsh and bash pyenv integration.
- Account for bash login-file precedence across `~/.bash_profile`, `~/.bash_login`, and `~/.profile`.
- Strengthen SSH verification guidance to exercise login and interactive shells, not just `ssh host true`.
- Gate the bash login banner with `shopt -q login_shell`.
- Dedupe pyenv `PATH` entries in `.profile`.

The full review notes are in `.agents/reviews/profile-loading-slow-linux/`.

## Tracked Changes

- `.zshrc` lazy pyenv loader now uses `pyenv init --no-rehash - zsh`.
- `setup-linux.sh` installs NVM with startup-file mutation disabled:
  - `curl ... | PROFILE=/dev/null bash`
- `setup-linux.sh` no longer evaluates full `pyenv init -` during pyenv installation.
- `setup-linux.sh` removes old `eval "$(pyenv init -)"` lines from bash login files when run.
- `setup-linux.sh` appends only fast, POSIX-compatible pyenv path setup to `~/.profile`.

## Local Host Migration

Backups were created before editing:

- `~/.profile.backup-profile-loading-slow-linux-*`
- `~/.bashrc.backup-profile-loading-slow-linux-*`

Local `~/.profile`:

- Removed eager `eval "$(pyenv init -)"`.
- Replaced `[[ ... ]]` pyenv path setup with POSIX-compatible deduped path setup.
- Added pyenv shims to `PATH` without invoking shell integration.

Local `~/.bashrc`:

- Removed eager bash completion sourcing from startup.
- Gated the Infrastructure Control Center banner to login bash shells with a TTY.
- Added lazy no-rehash pyenv integration.
- Replaced eager NVM and NVM completion loading with wrappers for `nvm`, `node`, `npm`, `npx`, `corepack`, and `pnpm`.

## Verification

Syntax checks passed:

```sh
zsh -n .zshrc
bash -n setup-linux.sh
bash -n ~/.bashrc
bash -n ~/.profile
```

Startup timing after migration:

```text
zsh -i -c exit:   0.06s to 0.10s
zsh -lic exit:    0.05s to 0.10s
bash -lic exit:   0.11s to 0.16s
bash -i -c exit:  0.09s to 0.12s
```

First-use checks passed for:

- zsh pyenv: `python --version`, `pyenv version-name`
- bash pyenv: `python --version`, `pyenv version-name`
- zsh NVM: `node --version`, `nvm current`
- bash NVM: `node --version`, `nvm current`

No lingering `pyenv-rehash`, `bash -lic`, or `zsh -lic` startup processes remained after verification.

SSH-to-self verification could not be completed in BatchMode from this session:

- Default known-hosts path failed host key verification.
- Temporary known-hosts with `StrictHostKeyChecking=accept-new` reached SSH auth, then failed with `Permission denied (publickey,keyboard-interactive)`.

The shell startup files were verified directly with local login and interactive shell commands.
