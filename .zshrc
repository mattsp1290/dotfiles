# Path to your dotfiles.
export DOTFILES=$HOME/git/.dotfiles

export PATH="$HOME/.local/bin:$PATH"
export PATH=$DOTFILES/bin:$PATH

# START OMZ BLOCK
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source $ZSH/oh-my-zsh.sh
# END OMZ BLOCK
