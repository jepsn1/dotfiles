#!/usr/bin/env bash
# Install agent config (tool-neutral source here in .agents/) into Claude's paths.
# Run standalone: bash ~/dotfiles/.agents/install.sh
set -euo pipefail
AGENTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$HOME/.claude/skills"

# behavior file: AGENTS.md -> ~/.claude/CLAUDE.md (where Claude Code reads it)
rm -f "$HOME/.claude/CLAUDE.md"
ln -s "$AGENTS_DIR/AGENTS.md" "$HOME/.claude/CLAUDE.md"

# skills: link per-skill so machine-local skills aren't clobbered
for skill in "$AGENTS_DIR"/skills/*/; do
  name="$(basename "$skill")"
  rm -rf "$HOME/.claude/skills/$name"
  ln -s "$AGENTS_DIR/skills/$name" "$HOME/.claude/skills/$name"
done

echo "linked AGENTS.md + $(find "$AGENTS_DIR/skills" -maxdepth 1 -mindepth 1 -type d | wc -l) skills into ~/.claude"
