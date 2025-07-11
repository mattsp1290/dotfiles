# Minimal Dotfiles Test Configuration

This is a minimal dotfiles configuration used for integration testing. It provides a realistic but simple set of configuration files that can be used to test the installation, upgrade, and rollback procedures.

## Structure

```
minimal-dotfiles/
├── README.md                    # This file
├── .version                     # Version marker
├── scripts/
│   └── bootstrap.sh            # Test bootstrap script
├── vim/
│   ├── .vimrc                  # Vim configuration
│   └── .vim/
│       └── colors/
│           └── test.vim        # Test color scheme
├── zsh/
│   ├── .zshrc                  # Zsh configuration
│   ├── .zsh/
│   │   └── functions.zsh       # Zsh functions
│   └── .zshenv                 # Zsh environment
├── git/
│   ├── .gitconfig              # Git configuration
│   └── .gitignore_global       # Global gitignore
├── tmux/
│   └── .tmux.conf              # Tmux configuration
└── templates/
    ├── ssh-config.tmpl         # SSH config template
    └── git-credentials.tmpl    # Git credentials template
```

## Usage

This configuration is used by integration tests to:

1. **Fresh Installation Testing**: Test installing from a clean state
2. **Upgrade Testing**: Simulate upgrading from this configuration
3. **Rollback Testing**: Test rolling back to this configuration
4. **Template Testing**: Test secret injection with templates

## Version

Version: 1.0.0

This version marker is used by upgrade tests to simulate version transitions. 