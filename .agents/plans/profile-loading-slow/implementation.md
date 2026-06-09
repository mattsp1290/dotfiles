# Implementation Notes

## Changes

- `.zshrc` no longer sources `~/.profile`.
- `.zshrc` now sources fast, untracked local files:
  - `~/.config/zsh/local-env.zsh`
  - `~/.config/zsh/local-secrets.zsh`
- NVM is lazy-loaded through wrappers for `nvm`, `node`, `npm`, `npx`, `corepack`, and the installed global `pnpm`.
- Pyenv keeps shims on `PATH`, while heavier shell integration is lazy-loaded when `pyenv` is used.
- The Namecheap client IP lookup is no longer run during startup. Use `refresh_namecheap_client_ip` when that value is needed.
- Oh My Zsh is no longer eagerly loaded. `.zshrc` now provides a lightweight robbyrussell-style prompt and initializes zsh completions lazily on first Tab.
- `~/.zprofile` no longer runs `brew shellenv` or `rbenv init` on every login shell. It sets Homebrew environment variables directly and lazy-loads rbenv shell integration.

## Local Files

`~/.profile` was kept intact as a rollback/reference file.

`~/.config/zsh/local-env.zsh` contains fast non-secret local exports and cheap path setup.

`~/.config/zsh/local-secrets.zsh` was generated from existing secret-shaped `~/.profile` exports, excludes the old network IP lookup, and is mode `600`.

## Verification

Syntax checks passed:

```sh
zsh -n .zshrc
zsh -n ~/.zprofile
zsh -n ~/.config/zsh/local-env.zsh
zsh -n ~/.config/zsh/local-secrets.zsh
```

Startup timing after implementation:

```text
interactive avg 0.012s min 0.010s max 0.020s
login avg       0.013s min 0.010s max 0.020s
```

Runtime checks passed for:

- `node`, `npm`, `npx`, `nvm current`, and `pnpm`.
- `.nvmrc` directory behavior.
- `python`, `pip`, `pyenv version-name`, and `.python-version` directory behavior.
- `brew`, `rbenv`, `ruby`, `codex`, and `opencode`.
- Clean login shell leaves `TF_VAR_namecheap_client_ip` unset and defines `refresh_namecheap_client_ip`.

Environment-name parity compared to the old eager `~/.profile` startup is preserved except for deliberate lazy/runtime variables:

- `NVM_BIN`
- `NVM_CD_FLAGS`
- `NVM_INC`
- `PYENV_SHELL`
- `TF_VAR_namecheap_client_ip`
- `ZDOTDIR` from the isolated test harness
