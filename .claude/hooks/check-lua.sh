#!/usr/bin/env bash
# PostToolUse (Edit, Write) — fail loudly if an edited .lua file has a syntax
# error. Lua is this repo's only "language": a broken file breaks nvim at next
# launch, so catch it the moment it's written (luac -p is the same check used
# manually throughout this repo's history).
input=$(cat)
file=$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[ -n "$file" ] || file=$(printf '%s' "$input" | sed -n 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[ -n "$file" ] || exit 0

case "$file" in
  *.lua) ;;
  *) exit 0 ;;
esac

command -v luac >/dev/null 2>&1 || exit 0 # no luac installed: skip silently
cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0

if ! err=$(luac -p "$file" 2>&1); then
  echo "Lua syntax error in $file — fix before continuing:"
  echo "$err"
  exit 2
fi
exit 0
