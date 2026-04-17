#!/usr/bin/env bash
# Claude Code status line
# Reads JSON from stdin and outputs a formatted status line.

input=$(cat)

user=$(whoami)
host=$(hostname -s)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

# Git branch — skip index.lock contention by using --no-optional-locks
branch=""
if [ -n "$cwd" ] && command -v git >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
fi

# Build output with ANSI colors (terminal will dim them in the status bar)
out=""

# user@host in green
out="${out}$(printf '\033[32m%s@%s\033[0m' "$user" "$host")"

# cwd in blue
if [ -n "$cwd" ]; then
  # Shorten $HOME to ~
  short_cwd="${cwd/#$HOME/\~}"
  out="${out}$(printf ':\033[34m%s\033[0m' "$short_cwd")"
fi

# git branch in yellow
if [ -n "$branch" ]; then
  out="${out}$(printf ' \033[33m(%s)\033[0m' "$branch")"
fi

# model in dim white
if [ -n "$model" ]; then
  out="${out}$(printf '  \033[2m%s\033[0m' "$model")"
fi

# context remaining in cyan (only when available)
if [ -n "$remaining" ]; then
  out="${out}$(printf '  \033[36m%s%% ctx\033[0m' "$(printf '%.0f' "$remaining")")"
fi

printf '%s' "$out"
