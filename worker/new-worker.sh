#!/usr/bin/env bash
# Create or update an isolated agent user (work1..work9). Idempotent, safe to re-run.
# Usage (from your admin user): sudo ~/dotfiles/worker/new-worker.sh workN [git-email]
#
# Does: user + ssh key, chmod 700 home, `agents` group + /srv/agent-claims,
# tmux/neovim/gh, dotfiles + install.sh, Claude Code, worker env in ~/.bashrc.
# Leaves interactive logins to you (printed at the end).
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run with sudo" >&2; exit 1; }
NAME="${1:?usage: new-worker.sh workN [git-email]}"
[[ $NAME =~ ^work[1-9]$ ]] || { echo "name must be work1..work9 (dev ports 4N00-4N09)" >&2; exit 1; }
EMAIL="${2:-}"
ADMIN="${SUDO_USER:?run via sudo from your admin user}"
ADMIN_HOME="$(getent passwd "$ADMIN" | cut -d: -f6)"
USER_HOME="/home/$NAME"
N="${NAME#work}"

log() { echo -e "\n==> $*"; }
as_user() { sudo -u "$NAME" -H bash -lc "$1"; }

log "Packages"
need=()
for p in git curl tmux neovim gh build-essential ripgrep fd-find unzip; do dpkg -s "$p" >/dev/null 2>&1 || need+=("$p"); done
if ((${#need[@]})); then apt-get install -yq "${need[@]}"; fi


log "User $NAME"
getent passwd "$NAME" >/dev/null || adduser --disabled-password --gecos "" "$NAME"
chmod 700 "$USER_HOME"
install -d -m 700 -o "$NAME" -g "$NAME" "$USER_HOME/.ssh"
if [[ -s "$ADMIN_HOME/.ssh/authorized_keys" && ! -s "$USER_HOME/.ssh/authorized_keys" ]]; then
  install -m 600 -o "$NAME" -g "$NAME" "$ADMIN_HOME/.ssh/authorized_keys" "$USER_HOME/.ssh/authorized_keys"
fi

log "Shared claims dir (parallel-work)"
getent group agents >/dev/null || groupadd agents
usermod -aG agents "$NAME"
install -d -m 2770 -o root -g agents /srv/agent-claims

log "Dotfiles"
as_user "if [ -d ~/dotfiles/.git ]; then git -C ~/dotfiles pull -q --ff-only; else git clone -q https://github.com/jepsn1/dotfiles ~/dotfiles; fi"
as_user "bash ~/dotfiles/install.sh </dev/null"

log "Claude Code"
as_user "[ -x ~/.local/bin/claude ] || curl -fsSL https://claude.ai/install.sh | bash"
if [[ ! -f "$USER_HOME/.claude/settings.json" ]]; then
  install -d -o "$NAME" -g "$NAME" "$USER_HOME/.claude"
  cat > "$USER_HOME/.claude/settings.json" <<'EOF'
{
  "permissions": { "allow": ["Bash"] },
  "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" }
}
EOF
  chown "$NAME:$NAME" "$USER_HOME/.claude/settings.json"
fi

log "Worker env"
if ! grep -q ">>> worker" "$USER_HOME/.bashrc"; then
  cat >> "$USER_HOME/.bashrc" <<EOF

# >>> worker (dotfiles/worker/new-worker.sh)
export AGENT_CLAIMS_ROOT=/srv/agent-claims
export DEV_PORT_BASE=4${N}00   # dev ports 4${N}00-4${N}09 -> ${NAME}[-M].dev.jepsn.com (tailnet)
infocmp "\$TERM" >/dev/null 2>&1 || export TERM=xterm-256color
# <<< worker
EOF
fi

log "Git identity"
GIT_NAME="$(sudo -u "$ADMIN" -H git config --global user.name || true)"
[[ -n $GIT_NAME ]] && as_user "git config --global user.name '$GIT_NAME'"
[[ -n $EMAIL ]] && as_user "git config --global user.email '$EMAIL'"

cat <<EOF

Done. Next, as $NAME (ssh $NAME@<host>):
  claude                    # log in with this worker's seat
  gh auth login && gh auth setup-git
  git clone <repo> ~/...    # repos + .env files
EOF
