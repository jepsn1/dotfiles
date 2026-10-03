#!/usr/bin/env bash

mkdir -p "$HOME/.config/i3"
rm -f "$HOME/.config/i3/config"
ln -s "$HOME/dotfiles/i3/config" "$HOME/.config/i3/config"

sudo rm -f ~/.tmux.conf
sudo ln -s "$HOME/dotfiles/.tmux.conf" ~/.tmux.conf

mkdir -p "$HOME/.local/bin"
rm -f "$HOME/.local/bin/dev-tmux"
ln -s "$HOME/dotfiles/dev-tmux" "$HOME/.local/bin/dev-tmux"

# keyd (optional): only offer if installed; binary may not be on PATH, so also check the unit
if command -v keyd >/dev/null 2>&1 || systemctl cat keyd.service >/dev/null 2>&1; then
  read -rp "keyd found. Link keyd config + restart keyd? [y/N] " ans
  if [[ $ans =~ ^[Yy]$ ]]; then
    sudo mkdir -p /etc/keyd
    sudo rm -f /etc/keyd/default.conf
    sudo ln -s "$HOME/dotfiles/keyd/default.conf" /etc/keyd/default.conf
    sudo systemctl restart keyd || echo "warn: keyd restart failed; check 'systemctl status keyd'" >&2
  else
    echo "skipping keyd"
  fi
else
  echo "keyd not installed, skipping (https://github.com/rvaiya/keyd)"
fi
