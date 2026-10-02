#!/usr/bin/env bash
# Claude Code status line: user@host:dir (branch) [worktree], colored like a bash prompt.
dir="$(jq -r '.workspace.current_dir // .cwd')"
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
printf '%s' "$out"
