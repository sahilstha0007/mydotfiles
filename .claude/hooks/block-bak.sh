#!/usr/bin/env bash
# PreToolUse (Edit, Write) — refuse edits to intentional .bak backups.
# Per CLAUDE.md: lua/*.bak*, lua/plugins/coding/*.bak* are deliberate backups.
input=$(cat)
if printf '%s' "$input" | grep -Eq '\.bak[^" ]*"'; then
  echo "Blocked: that file is an intentional .bak backup — leave it alone."
  exit 2
fi
exit 0