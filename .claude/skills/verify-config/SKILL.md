---
name: verify-config
description: Run the full QA battery on this nvim dotfiles repo — Lua syntax, HTML well-formedness, docs cross-references, spec/import drift, dead requires, keymap collisions, .bak safety. Use before finishing any config edit session or claiming the config is healthy.
---

# verify-config

One pass that catches every failure mode this repo has actually hit: broken
Lua (breaks the editor at next launch), a spec file lazy.nvim silently never
loads, a keymap bound twice, docs pointing at files that don't exist, a dead
`require()` of an unloaded plugin, or an accidentally-touched `.bak`.

## When to run

- Before ending a session that touched `lua/` or `docs/`
- Before claiming "the config is fine" after edits
- After adding/removing any plugin or keymap

## Steps (run all; stop and fix on the first failure)

### 1. Lua syntax — every file

```bash
fail=0; while IFS= read -r f; do
  luac -p "$f" 2>/dev/null || { echo "SYNTAX: $f"; fail=1; }
done < <(find lua -name '*.lua' | grep -v '\.bak')
[ "$fail" -eq 0 ] && echo "lua: all parse"
```
If `luac` is missing, fall back to `luajit -bl "$f"` or note the gap.

### 2. HTML well-formedness (learn-nvim.html)

```bash
python3 - <<'PY'
from html.parser import HTMLParser
class P(HTMLParser):
    def __init__(self):
        super().__init__(); self.s = []; self.e = []
    def handle_starttag(self, t, a):
        if t not in ('meta', 'br', 'img', 'input', 'link', 'hr'): self.s.append(t)
    def handle_endtag(self, t):
        if self.s and self.s[-1] == t: self.s.pop()
        else: self.e.append('</%s>' % t)
p = P(); p.feed(open('learn-nvim.html').read())
assert not p.s and not p.e, ('unclosed: %s' % (p.s or p.e))
print('html: ok')
PY
```

### 3. Docs cross-references (docs/index.md → files exist)

```bash
grep -oE '\]\([a-z-]+\.md\)' docs/index.md | sed -E 's/.*\(([^)]*)\)/\1/' | sort -u \
  | while read -r d; do [ -f "docs/$d" ] || echo "MISSING DOC: docs/$d (linked from docs/index.md)"; done
```

### 4. Spec/import drift

Same logic as `.claude/hooks/check-imports.sh`: every `lua/plugins/<cat>/<name>.lua`
must have an **active** (non-commented) `{ import = 'plugins.<cat>.<name>' },`
in `lua/lazy-init.lua`.

Known exceptions (specs kept without an active import):
`plugins.editor.fzf`, `plugins.editor.lualine-theme`, `plugins.formatting.prettier`,
`plugins.languages.laravel`, `plugins.ui.colorscheme`.

Anything else flagged is a spec lazy.nvim will silently never load — fix the
import or delete the spec.

### 5. Dead requires

```bash
grep -rn "require('fzf-lua')" lua/ docs/ --include='*.lua' --include='*.md' | grep -v '\.bak'
```
Generalize: any `require('<plugin>')` whose spec has no active import and isn't
a declared dependency of a loaded plugin. Historical bug: `gd`/`gy`/`grr`
bound to fzf-lua while its import was commented out.

### 6. Keymap collisions

```bash
grep -rhoE "keymap.set\('n', '<[^>]*>'" lua/keymaps.lua lua/plugins --include='*.lua' | sort | uniq -d
grep -rhoE "\{ '<leader>[a-z0-9]*'" lua/plugins --include='*.lua' | sort | uniq -d
```
Buffer-local overrides (gitsigns `]c`, telescope `gd`) are legitimate; two
*global* bindings of the same lhs are a silent last-loaded-wins bug (historical:
double `<leader>gbl`).

### 7. `.bak` backups untouched

```bash
git status --short | grep -E '\.bak' && echo "BAK files touched — do not modify these (CLAUDE.md)"
```

## Output

- All green → `config verified: lua ✓ html ✓ docs ✓ imports ✓ no dead requires ✓ no keymap collisions ✓ bak ✓`
- Any red → print the exact command output and fix it before continuing.
