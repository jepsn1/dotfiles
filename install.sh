mkdir -p ~/.config/i3
rm -f ~/.config/i3/config
ln -s ~/dotfiles/i3/config ~/.config/i3/config

sudo mkdir -p /etc/keyd
sudo rm -f /etc/keyd/default.conf
sudo ln -s ~/dotfiles/keyd/default.conf /etc/keyd/default.conf

