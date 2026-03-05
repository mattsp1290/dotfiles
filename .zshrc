# Path to your dotfiles.
export DOTFILES=$HOME/git/.dotfiles
export PATH=$DOTFILES/bin:$PATH

export PATH="$HOME/.local/bin:$PATH"
export DOCKER_BUILDKIT=1

# START GO BLOCK
export GOPATH="$HOME/go"
export PATH="$HOME/go/bin:$PATH"
# END GO BLOCK

# START NODE BLOCK
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm 
# END NODE BLOCK

# START OMZ BLOCK
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source $ZSH/oh-my-zsh.sh
# END OMZ BLOCK

# START ZSH BLOCK
# History prefix search: type a prefix, then up/down arrow cycles through matches
autoload -U history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^[[A" history-beginning-search-backward-end
bindkey "^[[B" history-beginning-search-forward-end
# END ZSH BLOCK

source $HOME/.profile
