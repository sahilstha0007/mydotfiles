#!/usr/bin/env bash
# Live consumer check — catches the drift class `check_wallpaper_cascade.sh`
# cannot: a consumer that is generated but never enabled, or text that fails
# its own readability gate. The cascade test uses a throwaway HOME and proves
# files are WRITTEN; it cannot see whether Obsidian actually loads matugen.css.
#
# Read-only: reports findings, never fixes them.
set -u

VAULT="$HOME/Documents/Notes/Atlas"
SNIPPET="$VAULT/.obsidian/snippets/matugen.css"
APPEARANCE="$VAULT/.obsidian/appearance.json"
PAL="$HOME/.config/wezterm/colors/matugen.lua"
LEGIBLE="$HOME/.config/wezterm/utils/legible.py"

pass=0
fail=0
ok()  { printf '  ok    %s\n' "$1"; pass=$((pass + 1)); }
no()  { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }

printf '\nLive palette consumers\n'

# 1. the generated snippet exists
[ -s "$SNIPPET" ] && ok "matugen.css generated" || no "matugen.css missing/empty"

# 2. THE gap that bit twice: generated but not enabled in appearance.json
if [ -f "$APPEARANCE" ] && python3 -c "
import json,sys
d=json.load(open('$APPEARANCE'))
sys.exit(0 if 'matugen' in d.get('enabledCssSnippets',[]) else 1)
" 2>/dev/null; then
  ok "matugen snippet enabled in appearance.json"
else
  no "matugen.css generated but NOT enabled — vault is not re-themed"
fi

# 3. every text token in the snippet clears 4.5:1 on every surface it can sit on
if [ -f "$PAL" ] && [ -f "$LEGIBLE" ] && [ -s "$SNIPPET" ]; then
  if python3 - "$PAL" "$SNIPPET" "$LEGIBLE" <<'PY'
import re, sys, subprocess
pal, snip, legible = sys.argv[1:]

def load(path):
    return dict(re.findall(r'\s*(\w+)\s*=\s*"(#[0-9a-fA-F]{6})"', open(path).read()))

p = load(pal)
s = dict(re.findall(r'--([\w-]+):\s*(#[0-9a-fA-F]{6})', open(snip).read()))
refs = ','.join(p[k] for k in ('background','surface0','surface1','surface2'))
fbs = '#cdd6f4 #4c4f69 #a6adc8 #6c6f85 #ffffff #000000'
checks = {
    'text-normal': p['foreground'], 'text-muted': p['outline'],
    'text-accent': p['primary'], 'text-error': p['error'],
    'text-success': p['secondary'], 'text-warning': p['tertiary'],
}
out = subprocess.run([sys.executable, legible, '--batch'],
    input='\n'.join(f'{k} 4.5 {v} {refs} {fbs}' for k, v in checks.items()),
    capture_output=True, text=True, check=True).stdout
bad = []
for line in out.splitlines():
    key, hexv = line.split()
    actual = s.get(key)
    if actual and actual.lower() != hexv.lower():
        bad.append(f'{key}: snippet {actual} != guarded {hexv}')
for b in bad:
    print('  FAIL  ' + b, file=sys.stderr)
sys.exit(1 if bad else 0)
PY
  then
    ok "all snippet text tokens clear 4.5:1"
  else
    no "a snippet text token fails 4.5:1 (see above)"
  fi
fi

# 4. the static kitty palette include exists (v12: matugen/sanitizer removed)
if [ -s "$HOME/.config/kitty/themes/apple-glass.conf" ]; then
  ok "kitty static apple-glass palette present"
else
  no "kitty themes/apple-glass.conf missing — static include dead"
fi

printf '\nresult: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
printf 'PASS  live consumers healthy\n\n'
