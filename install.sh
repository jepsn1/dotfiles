mkdir -p "$HOME/.config/i3"
rm -f "$HOME/.config/i3/config"
ln -s "$HOME/dotfiles/i3/config" "$HOME/.config/i3/config"

sudo mkdir -p /etc/keyd
sudo rm -f /etc/keyd/default.conf
sudo ln -s "$HOME/dotfiles/keyd/default.conf" /etc/keyd/default.conf

sudo rm -f ~/.tmux.conf
sudo ln -s "$HOME/dotfiles/.tmux.conf" ~/.tmux.conf

mkdir -p "$HOME/.local/bin"
rm -f "$HOME/.local/bin/dev-tmux"
ln -s "$HOME/dotfiles/dev-tmux" "$HOME/.local/bin/dev-tmux"

sudo systemctl restart keyd

# claude workspace isolation (visma <-> private): source the shell wrapper
LINE='[ -f "$HOME/dotfiles/claude-spaces.sh" ] && . "$HOME/dotfiles/claude-spaces.sh"'
grep -qF "claude-spaces.sh" "$HOME/.bashrc" || printf '\n%s\n' "$LINE" >> "$HOME/.bashrc"
