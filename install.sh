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

# Claude Code Bash sandbox deps: bubblewrap enforces the filesystem fence,
# socat backs the network proxy.
sudo apt-get install -y bubblewrap socat

# Claude Code Bash sandbox: on Ubuntu 24.04+ AppArmor blocks unprivileged user
# namespaces, which bubblewrap needs. Without this the sandbox silently falls
# back to running commands UNSANDBOXED -- no error, no warning.
if [ "$(sysctl -n kernel.apparmor_restrict_unprivileged_userns 2>/dev/null)" = "1" ]; then
  sudo tee /etc/apparmor.d/bwrap > /dev/null <<'EOF'
abi <abi/4.0>,
include <tunables/global>

profile bwrap /usr/bin/bwrap flags=(unconfined) {
  userns,
  include if exists <local/bwrap>
}
EOF
  sudo systemctl reload apparmor || sudo apparmor_parser -r /etc/apparmor.d/bwrap
fi
