#!/usr/bin/env bash
# Claude Code status line: user@host:dir (branch) [worktree] | model ctx% 5h% 7d%, colored like a bash prompt.
input="$(cat)"
j() { jq -r "$1 // empty" <<<"$input"; }
dir="$(j '.workspace.current_dir // .cwd')"
out="$(printf '\e[1;32m%s@%s\e[0m:\e[1;34m%s\e[0m' "$USER" "$(hostname -s)" "${dir/#$HOME/\~}")"

if git -C "$dir" rev-parse --is-inside-work-tree &>/dev/null; then
  g() { git -C "$dir" --no-optional-locks "$@" 2>/dev/null; }
  branch="$(g symbolic-ref --short HEAD || g rev-parse --short HEAD)"
  out+="$(printf ' \e[33m(%s)\e[0m' "$branch")"
  # linked worktree: git-dir differs from common dir
  if [[ "$(g rev-parse --absolute-git-dir)" != "$(cd "$dir" && realpath "$(g rev-parse --git-common-dir)")" ]]; then
    out+="$(printf ' \e[35m[wt:%s]\e[0m' "$(basename "$(g rev-parse --show-toplevel)")")"
  fi
fi

# model + usage. bar: 5 cells, green <50, yellow <80, red; plan limits only on subscription plans
bar() {
  local p=$1 c=32 f i b=""
  ((p >= 50)) && c=33; ((p >= 80)) && c=31
  f=$(((p + 10) / 20)); ((f > 5)) && f=5
  for ((i = 0; i < 5; i++)); do ((i < f)) && b+="█" || b+="░"; done
  printf '\e[%sm%s\e[0m %s%%' "$c" "$b" "$p"
}
ago() { # seconds until epoch -> 2h10m / 3d4h
  local s=$(($1 - $(date +%s))); ((s < 0)) && s=0
  ((s >= 86400)) && printf '%dd%dh' $((s / 86400)) $((s % 86400 / 3600)) || printf '%dh%02dm' $((s / 3600)) $((s % 3600 / 60))
}
sep=$' \e[2m│\e[0m '
out+="$sep$(printf '\e[36m%s\e[0m' "$(j .model.display_name)")"
ctx="$(j .context_window.used_percentage)"
[[ -n $ctx ]] && out+="$sep$(printf '\e[2mctx\e[0m ')$(bar "$ctx")"
# every rate_limits window (five_hour, seven_day, any per-model ones like seven_day_<model>)
while read -r key pct reset; do
  label="${key/five_hour/5h}"; label="${label/seven_day/7d}"; label="${label//_/ }"
  out+="$sep$(printf '\e[2m%s\e[0m ' "$label")$(bar "${pct%.*}")"
  [[ -n $reset && $reset != null ]] && out+="$(printf ' \e[2m↻%s\e[0m' "$(ago "${reset%.*}")")"
done < <(jq -r '.rate_limits // {} | to_entries[] | select(.value.used_percentage != null) | "\(.key) \(.value.used_percentage) \(.value.resets_at)"' <<<"$input")
printf '%s' "$out"
