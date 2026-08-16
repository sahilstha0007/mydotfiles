#!/usr/bin/env bash
# PostToolUse (Edit, Write) — verify every lua/plugins/<cat>/<name>.lua spec
# has an ACTIVE (non-commented) import in lua/lazy-init.lua. Catches the
# "spec exists but lazy.nvim silently never loads it" class of bug (historical
# case: fzf.lua's import was commented out while other specs required it).
input=$(cat)
file=$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[ -n "$file" ] || file=$(printf '%s' "$input" | sed -n 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[ -n "$file" ] || exit 0

case "$file" in
  lua/plugins/*.lua | lua/lazy-init.lua) ;;
  *) exit 0 ;;
esac

cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0

# Spec files deliberately kept WITHOUT an active import (helper modules loaded
# by a sibling spec, or plugins intentionally commented out). Add here if you
# intentionally keep a spec that lazy.nvim should not load.
exceptions="plugins.editor.fzf plugins.editor.lualine-theme plugins.formatting.prettier plugins.languages.laravel plugins.linting.phpstan"

fail=0
for spec in $(find lua/plugins -name '*.lua' | sort); do
  mod="plugins.$(basename "$(dirname "$spec")").$(basename "$spec" .lua)"
  # active import = a line like:    { import = 'plugins.coding.autopairs' },
  if grep -qE "^\s*\{ import = '$mod' \}," lua/lazy-init.lua; then
    continue
  fi
  case " $exceptions " in
    *" $mod "*) continue ;;
  esac
  echo "NOT IMPORTED in lua/lazy-init.lua: $spec"
  fail=1
done

if [ "$fail" -ne 0 ]; then
  echo "If intentional, add the module to the exceptions list in .claude/hooks/check-imports.sh"
  exit 2
fi
exit 0
