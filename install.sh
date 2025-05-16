mkdir -p "$HOME/.config/i3"
rm -f "$HOME/.config/i3/config"
ln -s "$HOME/dotfiles/i3/config" "$HOME/.config/i3/config"

sudo mkdir -p /etc/keyd
sudo rm -f /etc/keyd/default.conf
sudo ln -s "$HOME/dotfiles/keyd/default.conf" /etc/keyd/default.conf

