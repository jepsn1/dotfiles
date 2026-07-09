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

# agent config (tool-neutral source in .agents/, linked into Claude's paths)
mkdir -p "$HOME/.claude/skills"
rm -f "$HOME/.claude/CLAUDE.md"
ln -s "$HOME/dotfiles/.agents/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

for skill in "$HOME"/dotfiles/.agents/skills/*/; do
  name="$(basename "$skill")"
  rm -rf "$HOME/.claude/skills/$name"
  ln -s "$HOME/dotfiles/.agents/skills/$name" "$HOME/.claude/skills/$name"
done

sudo systemctl restart keyd
