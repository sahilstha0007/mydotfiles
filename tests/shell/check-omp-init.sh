#!/usr/bin/env bash
# OMP init correctness gate — standalone: bash tests/shell/check-omp-init.sh
# Asserts: (1) zshrc references only OMP configs that exist,
# (2) every config is parseable by oh-my-posh, (3) no segment/prompt has
# foreground == background (invisible text), (4) the zshrc profile-detection
# matrix selects the right config + cache per branch, with no cache collision.
# OMP_ZSHRC_OVERRIDE points this gate at a mutated COPY of zshrc (fault injection)
# without touching the real file.
set -u

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
ZSHRC="${OMP_ZSHRC_OVERRIDE:-$REPO_ROOT/shell/zshrc}"
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

# (4) profile-detection matrix. Structural parse of zshrc — a functional
# `zsh -i -c` probe is unreliable here because OMP_CONFIG is never exported and
# the cached init writes files instead. Parse the detection if/elif chain and
# each branch's _omp_init_cached call site instead.
profile_out="$(python3 - "$ZSHRC" <<'PY'
import pathlib, re, sys

src = pathlib.Path(sys.argv[1]).read_text()

def ok(m):   print(f'  ok    {m}')
def bad(m):  print(f'  FAIL  {m}')
errors = []
def expect(cond, good, otherwise):
    if cond: ok(good)
    else: bad(otherwise); errors.append(otherwise)

try:
    # --- detection chain: explicit profile wins, then env-var fallbacks ---
    det = src[src.index('_is_kitty=0'):src.index('_omp_init_cached()')]
    conds = [re.sub(r'\s+', ' ', c.strip())
             for c in re.findall(r'(?:if|elif)\s+\[\[\s*(.+?)\s*\]\]', det)]
    expected_conds = [
        '"$TERMINAL_STACK_PROFILE" == "kitty"',
        '"$TERMINAL_STACK_PROFILE" == "wezterm"',
        '-n "$KITTY_WINDOW_ID"',
        '-n "$WEZTERM_PANE"',
    ]
    expect(conds == expected_conds,
           'detection order: TERMINAL_STACK_PROFILE > KITTY_WINDOW_ID > WEZTERM_PANE',
           f'detection chain order wrong: {conds}')

    assigns = re.findall(r'_is_(?:kitty|wezterm)=1', det)
    expect(assigns == ['_is_kitty=1', '_is_wezterm=1', '_is_kitty=1', '_is_wezterm=1'],
           'detection assignments map both profile branches and both env fallbacks',
           f'detection assignments wrong: {assigns}')

    # --- branch call sites: config + cache per branch ---
    call_re = r'_omp_init_cached\s+"([^"]+)"\s+"([^"]+)"'
    all_calls = re.findall(call_re, src)
    expect(len(all_calls) == 3,
           'exactly 3 _omp_init_cached call sites (kitty/wezterm/fallback)',
           f'expected 3 _omp_init_cached call sites, found {len(all_calls)}')

    branch = src[src.index('if [[ "$_is_kitty" -eq 1 ]]'):]
    branch = branch[:branch.index('\nfi\n')]
    kitty_at = branch.index('if [[ "$_is_kitty" -eq 1 ]]')
    wez_at   = branch.index('elif [[ "$_is_wezterm" -eq 1 ]]')
    else_at  = branch.index('\nelse\n', wez_at)
    expect(kitty_at < wez_at < else_at,
           'branch order: kitty -> wezterm -> fallback',
           f'branch header order wrong: {kitty_at} {wez_at} {else_at}')

    segs = {
        'kitty':    branch[kitty_at:wez_at],
        'wezterm':  branch[wez_at:else_at],
        'fallback': branch[else_at:],
    }
    expected = {
        'kitty':    ('$HOME/.config/ohmyposh/zen-apple-glass.toml', '$HOME/.cache/zsh-cache/omp-apple-glass.zsh'),
        'wezterm':  ('$HOME/.config/ohmyposh/zen.toml',             '$HOME/.cache/zsh-cache/omp-zen.zsh'),
        'fallback': ('$HOME/.config/ohmyposh/zen.toml',             '$HOME/.cache/zsh-cache/omp-fallback.zsh'),
    }
    actual = {}
    for name, seg in segs.items():
        calls = re.findall(call_re, seg)
        actual[name] = calls[0] if len(calls) == 1 else None
        cfg, cache = actual[name] if actual[name] else ('<none>', '<none>')
        exp_cfg, exp_cache = expected[name]
        expect(actual[name] == expected[name],
               f'{name} branch selects {pathlib.Path(exp_cfg).name} (cache {pathlib.Path(exp_cache).name})',
               f'{name} branch wrong: got cfg={cfg} cache={cache}, want cfg={exp_cfg} cache={exp_cache}')

    caches = [a[1] for a in actual.values() if a]
    expect(len(caches) == 3 and len(set(caches)) == 3,
           '3 distinct profile caches (no cache collision)',
           f'cache collision or missing cache: {caches}')
except Exception as e:
    bad(f'profile matrix parse failed: {e}')
    errors.append(str(e))

sys.exit(1 if errors else 0)
PY
)"
profile_rc=$?
[ -n "$profile_out" ] && printf '%s\n' "$profile_out"
_pok="$(grep -c '^  ok ' <<<"$profile_out")"
_pfail="$(grep -c '^  FAIL ' <<<"$profile_out")"
pass=$((pass + _pok))
fail=$((fail + _pfail))
if [ "$profile_rc" -ne 0 ] && [ "$_pfail" -eq 0 ]; then
  no "profile matrix check crashed (rc=$profile_rc) without a FAIL line"
fi

printf 'RESULT: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
