# Path to your dotfiles.
export DOTFILES=$HOME/git/.dotfiles
export DOCKER_BUILDKIT=1
export ENABLE_TOOL_SEARCH=true
export ZSH="$HOME/.oh-my-zsh"
export PAGER="${PAGER:-less}"
export LESS="${LESS:--R}"
export LSCOLORS="${LSCOLORS:-Gxfxcxdxbxegedabagacad}"
export LS_COLORS="${LS_COLORS:-di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43}"

typeset -U path PATH
path=(
  "$DOTFILES/bin"
  "$HOME/.local/bin"
  "$HOME/.opencode/bin"
  "$HOME/go/bin"
  "$HOME/.nimble/bin"
  $path
)
export PATH

# Point DOCKER_HOST at colima socket when colima is active
if [ -S "$HOME/.colima/default/docker.sock" ]; then
  export DOCKER_HOST="unix://$HOME/.colima/default/docker.sock"
fi

# Load Rust/Cargo environment
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# START GO BLOCK
export GOPATH="$HOME/go"
# END GO BLOCK

# START NIM BLOCK
# END NIM BLOCK

# START NODE BLOCK
export NVM_DIR="$HOME/.nvm"

_load_nvm() {
  local nvm_sh="$NVM_DIR/nvm.sh"
  unfunction _load_nvm nvm node npm npx corepack pnpm 2>/dev/null
  [[ -s "$nvm_sh" ]] && source "$nvm_sh"
}

nvm() { _load_nvm; nvm "$@"; }
node() { _load_nvm; command node "$@"; }
npm() { _load_nvm; command npm "$@"; }
npx() { _load_nvm; command npx "$@"; }
corepack() { _load_nvm; command corepack "$@"; }
pnpm() { _load_nvm; command pnpm "$@"; }
# END NODE BLOCK

# START PYENV BLOCK
export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && path=("$PYENV_ROOT/bin" $path)
[[ -d "$PYENV_ROOT/shims" ]] && path=("$PYENV_ROOT/shims" $path)

_load_pyenv() {
  unfunction _load_pyenv pyenv 2>/dev/null
  command -v pyenv >/dev/null 2>&1 || return
  eval "$(pyenv init --no-rehash - zsh)"
}

pyenv() { _load_pyenv; pyenv "$@"; }
# END PYENV BLOCK

# Local machine state is intentionally untracked. Keep these files fast:
# exports and path setup only, no network calls or tool init evals.
[[ -r "$HOME/.config/zsh/local-env.zsh" ]] && source "$HOME/.config/zsh/local-env.zsh"
[[ -r "$HOME/.config/zsh/local-secrets.zsh" ]] && source "$HOME/.config/zsh/local-secrets.zsh"

# START PROMPT BLOCK
autoload -U colors && colors
setopt prompt_subst

_git_prompt_info() {
  local ref dirty
  ref=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null) || return
  [[ -n "$(git status --porcelain 2>/dev/null)" ]] && dirty="%{$fg[yellow]%}✗"
  print -r -- "%{$fg_bold[blue]%}git:(%{$fg[red]%}${ref}%{$fg[blue]%})${dirty}%{$reset_color%} "
}

PROMPT='%(?:%{$fg_bold[green]%}➜ :%{$fg_bold[red]%}➜ ) %{$fg[cyan]%}%c%{$reset_color%} $(_git_prompt_info)'

_lazy_complete() {
  unfunction _lazy_complete 2>/dev/null
  autoload -Uz compinit
  compinit -C -d "${ZDOTDIR:-$HOME}/.zcompdump"
  zle expand-or-complete
}

zle -N _lazy_complete
bindkey "^I" _lazy_complete
# END PROMPT BLOCK

# START ZSH BLOCK
# History prefix search: type a prefix, then up/down arrow cycles through matches
autoload -U history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end

# Bind terminfo values (terminal-agnostic) plus both common escape sequences
# to cover xterm normal mode (^[[A), application mode (^[OA), tmux, and SSH
[[ -n "${terminfo[kcuu1]}" ]] && bindkey "${terminfo[kcuu1]}" history-beginning-search-backward-end
[[ -n "${terminfo[kcud1]}" ]] && bindkey "${terminfo[kcud1]}" history-beginning-search-forward-end
bindkey "^[[A" history-beginning-search-backward-end
bindkey "^[OA" history-beginning-search-backward-end
bindkey "^[[B" history-beginning-search-forward-end
bindkey "^[OB" history-beginning-search-forward-end
# END ZSH BLOCK
