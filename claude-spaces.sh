# Workspace isolation: ~/visma and ~/private must never see each other.
#
# Claude Code reads a project's .claude/settings.json only from the session's
# primary working directory -- it does not walk up parent directories. So a
# session started in ~/visma/some-project-1 would never load ~/visma/.claude/
# settings.json. These wrappers pass it explicitly, which also lands it in a
# higher-precedence scope than project settings, so a repo checked out inside a
# space cannot weaken the policy.
#
# gh gets the same treatment via GH_CONFIG_DIR, so each space has its own login.

# Print the space the cwd belongs to (visma|private), or fail if neither.
_space() {
  local d space
  d="$(cd -P -- "$PWD" 2>/dev/null && pwd -P)" || d="$PWD"
  for space in visma private; do
    case "$d" in
      "$HOME/$space"|"$HOME/$space"/*) printf '%s' "$space"; return 0 ;;
    esac
  done
  return 1
}

claude() {
  local s
  if s="$(_space)"; then
    command claude --add-dir "$HOME/$s" \
      --settings "$HOME/$s/.claude/settings.json" "$@"
  else
    command claude "$@"
  fi
}

gh() {
  local s
  if s="$(_space)"; then
    GH_CONFIG_DIR="$HOME/$s/.gh" command gh "$@"
  else
    command gh "$@"
  fi
}
