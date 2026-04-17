#!/usr/bin/env bash
# Claude Code status line
# Reads JSON from stdin and outputs a formatted status line.

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

out=""

# folder name only (not full path)
if [ -n "$cwd" ]; then
  folder=$(basename "$cwd")
  out="${out}$(printf '\033[34m%s\033[0m' "$folder")"
fi

# model in dim white
if [ -n "$model" ]; then
  out="${out}$(printf '  \033[2m%s\033[0m' "$model")"
fi

# context bar — 10-block visual bar
if [ -n "$remaining" ]; then
  pct=$(printf '%.0f' "$remaining")
  filled=$(( pct / 10 ))
  empty=$(( 10 - filled ))
  bar=""
  for i in $(seq 1 $filled); do bar="${bar}█"; done
  for i in $(seq 1 $empty);  do bar="${bar}░"; done
  # color: green >50%, yellow 20-50%, red <20%
  if [ "$pct" -gt 50 ]; then
    color="\033[32m"
  elif [ "$pct" -gt 20 ]; then
    color="\033[33m"
  else
    color="\033[31m"
  fi
  out="${out}$(printf "  ${color}%s\033[0m" "$bar")"
fi

printf '%s' "$out"
