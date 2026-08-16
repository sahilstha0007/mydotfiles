#!/usr/bin/env bash
# PostToolUse (Edit, Write) — stylua-format any Lua file Claude touched.
# Silently skips if stylua isn't installed (it's not, right now).
# ponytail: broad matcher, per-CLI shadow; fine at this size.
input=$(cat)
file=$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -n "$file" ] || exit 0
case "$file" in
  *.lua) ;;
  *) exit 0 ;;
esac
command -v stylua >/dev/null 2>&1 || exit 0
cd "$CLAUDE_PROJECT_DIR" && stylua "$file"