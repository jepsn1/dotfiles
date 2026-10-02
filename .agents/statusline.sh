#!/usr/bin/env bash
# Claude Code status line: current dir, ~-shortened.
dir="$(jq -r '.workspace.current_dir // .cwd')"
printf '%s' "${dir/#$HOME/\~}"
