#!/usr/bin/env bash
# OMP init correctness gate — standalone: bash tests/shell/check-omp-init.sh
# Asserts: (1/4) zshrc references only OMP configs that exist,
# (2) every config is parseable by oh-my-posh, (3) no segment/prompt has
# foreground == background (invisible text).
set -u

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
ZSHRC="$REPO_ROOT/shell/zshrc"
OMPDIR="$REPO_ROOT/.config/ohmyposh"

pass=0
fail=0
ok()  { printf '  ok    %s\n' "$1"; pass=$((pass + 1)); }
no()  { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }

printf '\nOMP init correctness\n'

# (1/4) every config referenced by _omp_init_cached in zshrc must exist
# shellcheck disable=SC2016  # regex literal, $HOME is matched not expanded
refs="$(grep -oE '_omp_init_cached "\$HOME/\.config/ohmyposh/[^"]+"' "$ZSHRC" \
  | sed -E 's|.*ohmyposh/||; s|"$||' | sort -u)"
[ -n "$refs" ] || no "no _omp_init_cached config references found in zshrc"
for cfg in $refs; do
  if [ -f "$OMPDIR/$cfg" ]; then ok "zshrc ref exists: $cfg"; else no "zshrc ref MISSING: $cfg"; fi
done

# (2) parseability. OMP 32.1.0 has no `config validate` subcommand, and
# `config export` silently falls back to the DEFAULT theme on a parse error
# (rc=0). `debug` renders a literal 'CONFIG PARSE ERROR' segment instead — use
# that as the failure signal so a broken config cannot pass silently.
if command -v oh-my-posh >/dev/null 2>&1; then
  for cfg in "$OMPDIR"/*.toml "$OMPDIR"/*.omp.json; do
    [ -f "$cfg" ] || continue
    if out="$(oh-my-posh debug --config "$cfg" --shell zsh --plain 2>/dev/null)" \
       && ! grep -q 'CONFIG PARSE ERROR' <<<"$out"; then
      ok "OMP parses: $(basename "$cfg")"
    else
      no "OMP parse error: $(basename "$cfg")"
    fi
  done
else
  printf '  SKIP  oh-my-posh not installed; parse check skipped\n'
fi

# (3) no segment or prompt renders foreground == background
python3 - "$OMPDIR" <<'PY'
import pathlib, re, sys, json, tomllib

d = pathlib.Path(sys.argv[1])
files = sorted([*d.glob('*.toml'), *d.glob('*.json')])
hex_re = re.compile(r'#[0-9a-fA-F]{6}')

def norm(v):
    return v.strip().lower() if isinstance(v, str) else v

def check(node, where, bad):
    if isinstance(node, dict):
        bg = node.get('background')
        fg = node.get('foreground')
        fgt = node.get('foreground_templates') or []
        if isinstance(fg, str) and isinstance(bg, str) and norm(fg) == norm(bg):
            bad.append(f'{where}: foreground==background {fg}')
        if isinstance(bg, str) and hex_re.fullmatch(norm(bg)):
            for t in fgt:
                if isinstance(t, str) and norm(bg) in [m.lower() for m in hex_re.findall(t)]:
                    bad.append(f'{where}: foreground_template==background {bg}')
        for k, v in node.items():
            check(v, f'{where}.{k}', bad)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            check(v, f'{where}[{i}]', bad)

bad = []
for f in files:
    try:
        data = tomllib.loads(f.read_text()) if f.suffix == '.toml' else json.loads(f.read_text())
    except Exception as e:
        bad.append(f'{f.name}: cannot parse for fg/bg audit: {e}')
        continue
    check(data, f.name, bad)

if bad:
    for b in bad:
        print(f'  FAIL  {b}')
    sys.exit(1)
print(f'  ok    no foreground==background in {len(files)} config file(s)')
PY
py_status=$?
if [ "$py_status" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi

printf 'RESULT: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
