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

# model + usage: context window, plan limits (5h/7d, only on subscription plans)
out+="$(printf ' \e[2m|\e[0m \e[36m%s\e[0m' "$(j .model.display_name)")"
ctx="$(j .context_window.used_percentage)"; [[ -n $ctx ]] && out+=" ctx ${ctx}%"
h5="$(j .rate_limits.five_hour.used_percentage)"; [[ -n $h5 ]] && out+=" 5h ${h5}%"
d7="$(j .rate_limits.seven_day.used_percentage)"; [[ -n $d7 ]] && out+=" 7d ${d7}%"
printf '%s' "$out"
