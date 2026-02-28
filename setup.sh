#!/bin/sh

if [ "$PWD" != "$HOME/git/dotfiles" ]; then
  echo "Error: setup.sh must be run from \$HOME/git/dotfiles" >&2
  exit 1
fi

echo "Setting up your Mac..."

