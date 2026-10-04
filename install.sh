#!/usr/bin/env bash
# Personal setup. No sudo needed except the optional keyd step, so it also
# runs as a worker user (see worker/new-worker.sh).

DOTFILES="$HOME/dotfiles"

if command -v i3 >/dev/null 2>&1; then
  mkdir -p "$HOME/.config/i3"
  rm -f "$HOME/.config/i3/config"
  ln -s "$DOTFILES/i3/config" "$HOME/.config/i3/config"
fi

ln -sfn "$DOTFILES/.tmux.conf" "$HOME/.tmux.conf"

# ghostty terminfo, so tmux works over ssh from ghostty (installs to ~/.terminfo)
infocmp -x xterm-ghostty >/dev/null 2>&1 || tic -x "$DOTFILES/terminfo/ghostty.terminfo"

mkdir -p "$HOME/.local/bin"
rm -f "$HOME/.local/bin/dev-tmux"
ln -s "$DOTFILES/dev-tmux" "$HOME/.local/bin/dev-tmux"

# neovim config (public fork of kickstart.nvim)
if command -v nvim >/dev/null 2>&1 && [ ! -e "$HOME/.config/nvim" ]; then
  git clone -q https://github.com/jepsn1/kickstart.nvim "$HOME/.config/nvim"
fi

# claude: AGENTS.md, skills, statusline
bash "$DOTFILES/.agents/install.sh"

# keyd (optional): only offer if installed and interactive; binary may not be on PATH, so also check the unit
if command -v keyd >/dev/null 2>&1 || systemctl cat keyd.service >/dev/null 2>&1; then
  if [ -t 0 ]; then
    read -rp "keyd found. Link keyd config + restart keyd? [y/N] " ans
  fi
  if [[ ${ans:-} =~ ^[Yy]$ ]]; then
    sudo mkdir -p /etc/keyd
    sudo rm -f /etc/keyd/default.conf
    sudo ln -s "$DOTFILES/keyd/default.conf" /etc/keyd/default.conf
    sudo systemctl restart keyd || echo "warn: keyd restart failed; check 'systemctl status keyd'" >&2
  else
    echo "skipping keyd"
  fi
else
  echo "keyd not installed, skipping (https://github.com/rvaiya/keyd)"
fi
