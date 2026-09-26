# Changelog

## overlays: colored glass, not gray (terminal-colors.lua)

- **Every overlay now shares one colored glass language** (glassmorphism
  skill, translated to the terminal palette) instead of gray surfaces:
  `FloatBorder` is a luminous blue-tinted rim (`surface2`→`blue` blend) that
  cascades through catppuccin's links to telescope, snacks picker, which-key,
  hover docs, and dressing; the selected row everywhere is a raised blue-tinted
  pill (`surface1`→`blue`); bodies stay transparent so the wallpaper glows
  through (winblend frosts).
- **Telescope:** selection = pill, match text = bold blue, prompt prefix =
  flamingo, corner titles = blue/lavender/green per section.
- **Snacks picker:** same language as telescope (selection pill, blue match,
  flamingo prompt, per-section titles).
- **Notifications:** each level is a tinted glass card — faint blue/yellow/
  red/peach/rosewater body (readable text on top) under catppuccin's full-
  color icon/title/border.
- **Completion (Pmenu + blink.cmp):** body is a faint blue-tinted glass
  instead of gray `surface0`; selected row is the blue pill; borders/scroll
  bars tinted blue to match the floats.
- Verified headless: `FloatBorder fg=#6e6e7f`, `TelescopeSelection bg`=pill,
  `SnacksNotifierInfo bg`=blue-tinted card; all Lua parses, no keymap
  collisions, .bak untouched.

## ponytail: kill the boxy line + unify footer colors

- **Header (`bufferline.lua`):** the "thin horizontal line" under the active tab was the underline indicator (`indicator.style='underline'` + `sp`/`underline` in the highlights) — it read as the bottom edge of a rectangle, the boxy look from before. Deleted it: `indicator = { style='icon', icon='' }` and no `underline`/`sp` on `buffer_selected`. Active tab is now just a raised background + bold text. Verified: `BufferLineBufferSelected=#dee3e6/#243e46` with no underline flag.
- **Footer (`lualine-theme.lua`):** unified the rainbow — `vtsls`, `1:1`, the clock, and the branch chip all use one calm `subtext0` tone. Only the mode chip (mode color), file icon (devicon), and error/warn counts carry color. Verified: `Info/Clock/Lsp=#9ec3c5`.

## clean header + footer pass

- **Header (`bufferline.lua`):** removed the per-tab **close (x) buttons** and the **per-tab diagnostic counts** — the tab strip is now just icons + titles with thin dividers (diagnostics live in the statusline where they're readable). Title still always visible, active tab still raised.
- **Footer (`lualine.lua`):** the language icon now hugs the filename (removed the extra padding between them) so the pair reads as one unit; everything else (mode chip, branch chip, filename, E/W, LSP, line:col, clock) keeps its purpose and only shows when relevant.
- Verified headless: `show_buffer_close_icons=false`, `diagnostics=false`, `separator_style=thin`, `always_show_bufferline=true`.

## drop the cursorline

- Removed the dark current-line highlight (`cursorline` back to `false`, `CursorLine` override deleted from `matugen.lua`) — the line under the cursor stays clean, relative numbers still show position. Smoothscroll, hidden `~` filler, and the glass bars all stay.

## Apple frosted-glass header + footer

- **The bars are now genuinely frosted, not bare transparency** (apple-design skill). Key insight: the terminal runs at `background_opacity < 1`, so nvim's bg colors are composited over the wallpaper — a *subtle* bg reads as frosted glass, while `NONE` reads as nothing and a full `surface0` reads as a heavy band. Both bars now sit on a computed **glass tint** — a 40% blend of `base` (#0f1416) toward `surface0` (#1d343a) = `#152125` — so the wallpaper glows through a faint tinted layer.
  - **Footer (`lualine-theme.lua`):** every section now on the glass tint (`LualineB/Clock/... bg=#152125`); the **mode chip** (mode color) and **git chip** (`surface1` pill) float raised on top. Added a small hex `mix()` helper (shared logic with the strip) so the tint stays cohesive if the wallpaper/palette changes.
  - **Header (`bufferline.lua`):** `fill`, inactive tabs, separators, and diagnostics all on the same glass tint; the **active tab stays the raised core** (`surface1` + cyan hairline). Header and footer now read as one continuous glass surface.
- Verified headless: `LualineB=#dee3e6/#152125`, `LualineChip=#9ec3c5/#243e46`, `BufferLineFill=#9ec3c5/#152125`, `BufferLineBuffer=#4c4c4d/#152125`, `BufferLineBufferSelected=#dee3e6/#243e46`, `BufferLineSeparator=#2e4e57/#152125`.
- Tune knob: the `0.4` in the `mix()` calls (both files) is the glass strength — lower = more transparent, higher = closer to the old band.

## transparent glass header + footer

- **Both bars are now transparent.** The `surface0` band backgrounds are gone — the terminal's own opacity (kitty 0.7) shows through the tab strip and statusline as glass.
  - **Footer (`lualine-theme.lua`):** every section is transparent (`bg=nil`); the only backgrounds left are the **mode chip** (mode color) and the **git chip** (raised `surface1`). Colors unchanged — text now floats on the glass.
  - **Header (`bufferline.lua`):** `fill`, inactive tabs, separators, and diagnostics all transparent; the **active tab keeps its raised `surface1` background + cyan hairline** — it's the single raised element on the glass, so the file you're editing still pops. Verified headless: `BufferLineBuffer=#4c4c4d/nil`, `BufferLineBufferSelected=#dee3e6/#243e46`, `LualineB=#dee3e6/nil`, `LualineChip=#9ec3c5/#243e46`.

## header + footer as one system: flat chips, themed diagnostics, feel & motion

- **Footer (`lualine.lua`) — flat modern bar.** Dropped the Powerline wedge (`section_separators` now empty): the mode block is a clean colored chip (icon, symmetric padding) that flows straight into the elevated band. The bar and the tab strip now share one flat language — no angled element fighting the theme. (Wedge still one line away if you want it back.) The git chip lost its bold so the mode chip is the only loud element; the filename is now bold so the file you're editing reads as primary.
- **Header (`bufferline.lua`) — tab diagnostics finally themed.** Same root cause as the white triangles: bufferline derives diagnostic-icon colors from the transparent `Normal` bg → they rendered in terminal defaults. Pinned all `error`/`warning`/`info`/`hint` + `*_selected`/`*_visible` variants to the palette (red/yellow/cyan on `surface0`, raised variants on `surface1`). Verified headless through the real lazy load.
- **Polish everywhere (`matugen.lua`):** `FloatBorder` = `surface2`, `NormalFloat` = `surface0` body — hover, diagnostics popup, and dressing windows are now elevated-but-in-palette instead of default-grey.
- **Feel & motion (`options.lua`):** `smoothscroll = true` (wheel glides instead of jumping), `cursorline = true` themed to the quiet `surface0` band tone (also makes the current line number absolute), and `fillchars = { eob = ' ' }` — the `~` filler lines at the end of every buffer are gone for a cleaner look.
- Verified headless: `sep=` (flat), `BufferLineError=#ffb4ac/#1d343a`, `BufferLineWarning=#c4c19f`, `BufferLineInfoSelected=#84d2e7/#243e45`, `FloatBorder=#2e4e56`, `NormalFloat=#dee3e5/#1d343a`, `CursorLine=#1d343a`, `smoothscroll=true`, `cursorline=true`.

## audit loop: 4 tracks clean, startup error killed

- **Full config audit loop complete** — four parallel tracks run against the live config: (1) glyph audit, (2) keymap-conflict audit, (3) dead-code audit, (4) startup-error audit. Fixes landed after each loop and re-verified.
- **Killed the `Invalid plugin spec ... phpstan` error that printed on every launch.** Root cause: `plugins/linting/phpstan.lua` is a **nvim-lint linter definition** (loaded via `require()` from `linting/core.lua`), not a plugin spec — it was mistakenly added to `lazy-init.lua`'s import list earlier, so lazy.nvim rejected it as a spec. Removed the import, documented it in `lua/lazy-init.lua`, and added `plugins.linting.phpstan` to the check-imports hook's exceptions list so the hook no longer flags it.
- **Glyph audit findings validated with the font's own glyph-name table** (post table, not just codepoint presence): the DAP signs, diagnostics signs, fold icons, and node icon are all correct glyphs in the font. The one real bug was the **emoji table** in `lazy-init.lua` (fallback for `have_nerd_font=false`) — emoji aren't in the font and would render as boxes. Replaced all of them with verified Nerd Fonts 3.5 codepoints via `nr2char()`.
- **Keymap audit clean**: `<C-j>/<C-k>/<C-l>` in overseer are disables (`= false`), and `<leader>cD`/`co` are intentional per-language buffer-local overrides — no conflicts.
- Verified: hook exit 0, all `lua/**` files parse, and a headless load of the real config now prints `LOAD_OK` with zero errors.

## Latest — slanted Powerline mode block (the "cool" statusline)

- **The statusline now has the classic pointed Powerline look** (`lua/plugins/editor/lualine.lua`): `section_separators = { left = '', right = '' }` makes the mode block a slanted segment — a mode-colored pointed block that flows into the elevated bar (mode icon inside, per-mode theme colors: red normal / green insert / blue visual / magenta command / violet replace).
- Verified the Powerline glyphs (U+E0B0/E0B2) exist in the installed Nerd Font before using them; headless checks confirm the separators are wired (`seps=,`) and the per-mode block colors load (`themeA=#ffb4ac|#9ec4a0|#84d2e7`). The git chip, dimmed metadata, and clock accent all stay.

## Apple premium pass on the statusline

- **Applied the apple-design skill's principles** (restraint, whitespace, typographic hierarchy, chip grouping) to the statusline (`lualine.lua` + `lualine-theme.lua`):
  - **Git branch is now a soft raised chip** — `LualineChip` sits on `surface1` (`#243e46`) with padding, reading as a grouped pill (Apple segmented-control feel) instead of loose text.
  - **Typographic hierarchy**: primary info stays bright (`file #dee3e6`, mode block), while the cursor position recedes to a quiet warm `overlay1` (`#aca98b`) and the clock keeps its warm yellow accent. Breathing room via component padding.
  - True frosted blur isn't renderable in a statusline row — the terminal's own transparency already provides the glass, so the pass focused on the elements that read as premium.
- **Fixed a latent bug**: `get_palette()` in `lualine-theme.lua` never returned `subtext0`/`overlay0`/`overlay1`, so several component foregrounds were silently nil (falling back to default). Added them to the palette map — all groups verified populated headless.

## the "frame" design: tab strip + statusline as one elevated band

- **Both surfaces now share one design language** (double-bezel, translated from the design skills): the editor sits inside a continuous `surface0` band — tab strip on top, statusline on the bottom — instead of text floating on the transparent background.
  - **Statusline** (`lualine-theme.lua`): every section now sits on `surface0` (`#1d343a`) — a defined bar, with the mode block and colored accents (branch, diagnostics, clock) popping on top.
  - **Tab strip** (`bufferline.lua`): the whole strip is the `surface0` band; the **active tab is the raised inner core** on `surface1` (`#243e45`) with bold text and the cyan hairline; inactive tabs recess dimmed onto the band; dividers are subtle `surface2` tone-on-tone bars; the Explorer offset shares the band.
- Verified headless: `LualineB/Z/Clock/Branch bg=#1d343a`, `BufferLineFill/Buffer bg=#1d343a`, `BufferLineBufferSelected bg=#243e45 sp=#84d2e7`.

## icon-only mode block

- **The statusline mode block is now pure icon** (`lua/plugins/editor/lualine.lua`): no more written `NORMAL` / `INSERT` text — just the mode glyph on the mode-colored background (`󰀫` red for normal, `󰦨` green for insert, `󰒅` blue for visual, `󰆍` magenta for command, `󰏫` violet for replace, `󰒉` orange for select). The color + glyph carry the signal.
- Verified: mode block output contains no text label, lualine loads clean against the real config.

## UI icon audit: every glyph now verified against Nerd Fonts 3.5.0

- **Root-cause icon fix across the whole UI.** Ran a three-track pass (research → design-system → ponytail restraint) and the audit found the real source of the "weird icon" glitches: the config was full of **legacy v2 codepoints** that don't exist (or render as unrelated glyphs) in the installed **Nerd Fonts 3.5.0** font.
  - The dashboard's Quit icon was literally a **clock** (`md-clock`), Lazy was **"zzz"** (`md-sleep`), and Find-Text/Tests/Session/AI/LazyGit codepoints had **no v3 mapping at all** (unpredictable glyphs).
  - **Fixed** in `lua/plugins/editor/snacks.lua` with verified v3.5 glyphs, built via `nr2char()` so the file holds no literal surrogate chars: find-file `fa-search`, new-file `fa-file`, find-text `md-magnify`, tests `md-flask`, lazygit `md-git`, session `md-history`, lazy `md-package`, AI `md-robot`, quit `md-power`, git-status terminal `md-console`, recent-files `md-history`.
  - **bufferline** Explorer offset icon → `md-folder` (was an unmapped codepoint).
- **File title always on top:** the tab strip stays visible even with a single buffer (`always_show_bufferline = true`) — an earlier pass had hidden it entirely on one-file sessions, which removed the file name from the top; reverted per request. The clean thin-separator design and active-tab highlight remain.
- Every icon verified two ways: present in the font's format-12 cmap AND round-tripping through `nr2char`/`str2list` headless. Lua parses, snacks + bufferline load clean against the real config.

## statusline rebuilt: mode icons, only the understandable stuff

- **Mode block now shows an icon + the label** (`lua/plugins/editor/lualine.lua`): e.g. `󰀫 NORMAL`, `󰦨 INSERT`, `󰒅 VISUAL`, `󰆍 COMMAND`, `󰏫 REPLACE` — on the same mode-colored background.
- **Every icon is verified to exist in the installed JetBrainsMono Nerd Font** before use (the older "vim-mode" codepoints map to bell/apple glyphs in current Nerd Fonts — checking the font's charset + glyph names avoided another mystery-glyph regression). Icons are built with `nr2char()` so the file holds no literal surrogate characters.
- **Decluttered to only understandable components.** Removed: diff counts, encoding/line-ending (`utf-8 LF`), and file percentage. Diagnostics now use readable letter labels (`E1 W2`) instead of bare colored numbers.
- **Kept:** filetype icon + filename, git branch (proper `nf-md-git` logo icon), active LSP client, cursor position `line:col`, clock. Inactive windows stay minimal.
- Verified headless against the real config: lualine loads without errors, all mode icons resolve to their exact codepoints, every `Lualine*` highlight group present.

## enhanced active-tab highlight (UI/UX pass)

- **The active file now gets a real design system** (`lua/plugins/editor/bufferline.lua`), built from the high-end-visual-design playbook: hierarchy via contrast, one accent used sparingly, tone-on-tone precision.
  - **Active tab**: raised on the palette's selection tone (`surface0` `#1d343a`) with bold light text, crowned by a **cyan accent hairline** underneath (`indicator = { style = 'underline' }`, `sp = c.blue` `#84d2e6`) — the classic premium "current tab" signature (VS Code/Linear style).
  - **Inactive tabs**: recessed to a dim `overlay0` tone — clear contrast hierarchy, the active file is unmistakable at a glance.
  - **Separators**: thin tone-on-tone dark bars; `underline` explicitly off on them (the underline indicator would otherwise paint a light line on the dividers).
- Kept from the previous pass: `separator_style = 'thin'` (no slanted boxes), no unsaved-changes dot.
- Verified headless: `BufferLineBufferSelected bg=#1d343a sp=#84d2e7 ul=true`, separators `underline=false`, inactive tabs `fg=#4c4c4c`.

## clean tab strip, active file highlighted

- **Slanted tab boxes are gone.** In `lua/plugins/editor/bufferline.lua`, `separator_style` changed from `'slant'` (angled triangles/rectangles between tabs) to `'thin'` — clean, minimal vertical dividers.
- **The current file is now unmistakable.** Every tab used to be fully transparent, so with 2+ files open nothing clearly showed which one was active. `BufferLineBufferSelected` now gets a real background — the palette's `surface0` (matugen `#1d343a`, the "selection bg" color) — plus bold light text, so the active file reads as a raised, highlighted tab.
- **Per-tab indicator bar removed** (`indicator = { icon = '' }`) — redundant now that the background highlights the active tab.
- Separator groups stay pinned to the dark matugen tone (from the transparent-`Normal` fix) so nothing renders in default white. Verified headless: `separator_style=thin`, `BufferLineBufferSelected bg=#1d343a fg=#dee3e6`, inactive tabs transparent with grey text.

## fix the white triangles on tabs

- **The slant-separator triangles on the tab bar were rendering white.** In `lua/plugins/editor/bufferline.lua`, `separator_style = 'slant'` draws a triangle on each tab edge. The theme sets `Normal` bg to transparent, so bufferline derived *nil* colors for the `BufferLineSeparator*` groups — and nvim fell back to the terminal's default (white) foreground.
- **Fixed** by pinning the five separator groups to a dark matugen tone via bufferline's `highlights` override: `separator` / `separator_selected` / `separator_visible` / `tab_separator` / `tab_separator_selected` → `fg = surface0` (`#1d343a`), derived live from the catppuccin palette so it tracks future matugen wallpapers. Verified headless: every group now reports `fg=#1d343a` (was `nil`), transparent bg preserved.

## statusline upgrade

- **The statusline is now a proper sectioned layout** (`lua/plugins/editor/lualine.lua` + `lualine-theme.lua`), rebuilt with the same matugen palette:
  - **Mode block**: shows the actual mode as readable text — `NORMAL` (red), `INSERT` (green), `VISUAL` (blue), `COMMAND` (magenta), plus SELECT/REPLACE/PROMPT/TERM — on a mode-colored background instead of a silent color block.
  - **Left**: mode block → git branch + diff counts → filetype icon + filename → diagnostics.
  - **Right**: LSP client (vtsls) → encoding + line-ending (`utf-8 LF`) → cursor position `line:col` → file percentage → clock.
  - Inactive windows show a dimmed, minimal strip (icon + filename).
- Verified against the real config headless: all `Lualine*` groups defined, no statusline errors.

## theme polish (verified against the real config in headless nvim)

- **Fixed dead completion theming.** `lua/plugins/ui/matugen.lua` styled nvim-cmp's `CmpItem*` highlight groups, but this setup uses blink.cmp — the whole block was ignored, so the completion popup was unstyled. Replaced it with the real `BlinkCmp*` groups (kind colors, menu selection, label match, doc window, ghost text) using the same palette intent.
- **Enabled the correct catppuccin integrations.** Swapped the dead `cmp` flag for `blink_cmp`, and added `snacks` (picker/dashboard), `lsp_trouble`, `treesitter_context`, `ufo`, and `flash` — all verified to exist in the installed catppuccin. Removed dead flags for plugins that aren't installed (`notify`, `noice`, `dashboard`, `indent_blankline`).
- **Contrast polish for the dim palette:** `Search` now uses the cyan accent (clear highlight when searching), `Visual` bumped to `surface1`, `MatchParen` gets a visible bg + accent fg (it was just re-enabled), `WinSeparator` brightened.
- Verified by loading the real config headless: `Search bg=#84d2e7`, `Visual bg=#243e46`, `BlinkCmpKindFunction fg=#84d2e7`, `BlinkCmpMenuSelection bg=#243e46` all applied. (Note: this also recompiled catppuccin's cache, which regenerates on next launch.)

## filetype icon restored

- **The statusline icon is back — and now it's correct per file.** The old constant glyph (always the same JS logo, whatever file you were in) is replaced with lualine's `filetype` component in `lua/plugins/editor/lualine.lua`: it shows the **current file's real language icon** (yellow JS for `.js`, Lua for `.lua`, …) in its native devicon color, so it always tells you what you're working on.
- The green tab dot and `[+]` modified markers stay removed (per the earlier declutter pass).

## declutter the file name

- **No green dot on tabs.** `lua/plugins/editor/bufferline.lua`: `modified_icon = ''` — the `●` unsaved-changes indicator no longer shows next to the buffer name (the file in the screenshot had uncommitted `<Space>` garbage, which is what lit it up).
- **No `[+]` after the file name.** `lua/plugins/editor/lualine.lua`: filename component now passes `symbols = { modified = '' }`.

## kill the hit-enter prompt

- **No more "Press ENTER or type command to continue".** In `lua/options.lua`: `vim.opt.more = false` makes long message output scroll through instead of blocking the editor (full history still in `:messages`), and `shortmess:append 'aAcFIst'` silences the chatty messages that triggered it (completion-menu msgs, "[New File]", intro, search-hit notices, truncated file msgs). With `cmdheight = 0`, messages used to queue up and force the pause on the first stray error or long output — that's gone now.

## space-glitch fix (v2, verified in headless nvim)

- **Space no longer fights the completion menu.** In `lua/plugins/coding/cmp.lua`, typing space in insert mode used to re-filter the open blink.cmp menu on every keystroke — causing flicker, cursor jumps, and "no matches" flashing while coding. Space now hides the menu and inserts the space cleanly.
- **Gotchas learned (both verified in headless nvim):** a plain `{ 'hide', 'fallback' }` keymap *eats* the space when the menu is open (blink's `hide()` returns true when it hid something). And the callback must return the **literal `' '`** — expr-mapping results are not termcode-expanded, so the first attempt (returning `'<Space>'`) typed the literal text `<Space>` into the buffer. Returning `' '` types a real space with no recursion (`a  b   c` round-trips exactly).

## nvim × tmux polish

- **E37-free buffer cycling.** `vim.opt.hidden = true` (`lua/options.lua`) — `]b` / `<S-h>` / `bd` no longer error when you switch away from a buffer with unsaved changes.
- **Auto-reload on focus.** `autoread` + a `FocusGained → :checktime` autocmd — edits made outside nvim (git, formatters) appear without a manual `:e!`. Pairs with `set -g focus-events on` in tmux.
- **tmux (`~/.config/tmux/tmux.conf`, backed up to `tmux.conf.bak-<date>`):** `focus-events on` (nvim sync), `set-clipboard on` (OSC52 copy-mode yanks → OS clipboard), vi copy-mode `v`/`V`/`C-v`, `C-a C-a` → last window, and resurrect now captures pane contents + shell history so in-progress work survives restarts.
- **Minor:** wrapped lines show a `↪` continuation marker (`showbreak`).

## The "cooler" pass

- **Auto-sessions.** `mini.sessions` now saves your workspace on exit and restores it when you open a directory (`nvim <dir>`) — no keypress needed. Bare `nvim` still shows the dashboard. Manual keys `<leader>qq`/`ql`/`qs` unchanged.
- **flash.nvim** (`lua/plugins/editor/flash.lua`) — jump to any visible word with 1–2 letters. Bound to `<leader>fj` (jump), `<leader>ft` (treesitter node), `R` (treesitter search) instead of the stock `s`, because `sh`/`sv` already own that key for splits.
- **Startup speed.** `nvim-tree` is now lazy-loaded (`cmd` + `<leader>e`), so it no longer loads on every launch. `nvim <dir>` still opens the tree via a lightweight startup autocmd.
- **Dashboard terminal pane.** The start screen now renders `git status` live next to the recent-files list (graceful fallback when not in a repo).
- **diffview.nvim** (`lua/plugins/editor/diffview.lua`) — side-by-side branch/PR diffs: `<leader>gD` open, `<leader>gH` file history, `<leader>gq` close.
- **bufferline.nvim** (`lua/plugins/editor/bufferline.lua`) — browser-style tab strip of open buffers; `<leader>bp` picks one.
- **Treesitter textobjects.** `af`/`if`/`ac`/`ic`/`ab`/`ib`/`aa`/`ia` now resolve against the syntax tree via `MiniAi.gen_spec.treesitter()` (mini.ai's native integration — no key conflicts). `nvim-treesitter-textobjects` adds `]f`/`[f` next/previous function motions (`]c`/`[c` deliberately skipped — gitsigns owns them).

## The "make it cool" pass

- **Dashboard start screen.** snacks.nvim now powers a dashboard (big ASCII header, key hints, recent files, session restore, lazy status). It owns the empty-launch screen; the file tree no longer auto-opens over it.
- **Modern & smooth.** Enabled snacks `animate` (UI animations), `dim` (dim unfocused windows), `indent` (thin indent guides), `notifier` (fancy notifications), `scroll` (smooth scrolling), `words` (word-under-cursor highlight).
- **Session persistence.** `mini.sessions` (via `lua/plugins/editor/mini.lua`): `<leader>qq` save, `<leader>ql` load last, `<leader>qs` select. The dashboard's Restore Session reads these too.
- **Harpoon-style file ring.** `mini.visits` — `<leader>fr` picks from recently visited files (module renamed from `mini.visited-file-ring` in mini.nvim v0.11.0).
- **Clipboard history.** Added `yanky.nvim` (`lua/plugins/editor/yanky.lua`): `<leader>sy` opens the yank history ring in Telescope; survives restarts via shada.
- **which-key** learned the new `<leader>q` (Session) group.

## Recent session — config fixes & docs

- **Python: ruff is now the single Python server.** `pyright` removed from the servers list in `lua/plugins/coding/lspconfig.lua` and from mason-tool-installer. `lua/plugins/languages/python.lua` now enables only `ruff` (lint + type-checking + format), and its stale pyright hover-disable setup block was removed. One server, no duplicate diagnostics.
- **Fixed broken LSP navigation.** `lua/plugins/coding/lspconfig.lua` had `gd`/`gy`/`grr`/`gri` bound to `fzf-lua` — a plugin whose import is commented out in `lua/lazy-init.lua`, so those keys errored on LSP buffers. Removed the fzf-lua bindings; go-to-definition/type/references/impl are now handled by telescope's global maps plus nvim 0.11 defaults (`grr` refs, `gri` impl). `<leader>ca` code action stays.
- **DAP debuggers now auto-install.** `lua/plugins/dap/core.lua` `ensure_installed` was empty — added `python` (debugpy) and `delve` (Go) DAP adapter names. JS/TS debugging is wired separately in `lua/plugins/languages/typescript.lua` (`pwa-node` + `js-debug-adapter`).
- **Go debugging launch config added.** `lua/plugins/languages/go.lua` now defines a delve launch config, so `Space d c` works on Go files.
- **Re-enabled `matchit`, `matchparen`, `shada`.** Removed from `disabled_plugins` in `lua/lazy-init.lua`: bracket-match highlight works again, `%` crosses HTML tags / if-else pairs, and marks/registers/jumplist persist across restarts (undo already persisted via `undofile`).
- **Removed duplicate `<leader>gbl`** in `lua/plugins/editor/gitsigns.lua` (was bound to both `blame_line` and `toggle_current_line_blame`; the toggle now wins, matching docs).
- **Snippets.** Added `rafamadriz/friendly-snippets` as a dependency of blink.cmp in `lua/plugins/coding/cmp.lua` — loaded automatically by blink's native `vim.snippet` engine, so the `snippets` completion source finally has content.
- **Docs filled in.** `docs/keymaps.md` was a placeholder ("ignore") — now a full keymap reference. Added `docs/cheatsheet.md` and this changelog; all files referenced by `docs/index.md` now exist.

## keymap audit: every claim machine-verified

- **Fixed a real bug**: `textobjects.lua` used master-branch config keys that main-branch mini.nvim silently ignores — `]f`/`[f` never existed at runtime. Rewrote with explicit `vim.keymap.set` calls to `move.goto_next_start`/`goto_previous_start`; verified headless (both maps resolve with descs).
- **Fixed a second latent bug of the same class**: `gsn` (surround "set N lines") never existed either — mini.surround's `apply_config` never maps `update_n_lines`, so the config key was silently ignored. Now bound explicitly in `mini.lua`; verified in the fresh dump (291 global maps).
- **Removed phantom claims** (documented, never bound): `te` (new tab) → replaced with `:tabnew`; `<Tab>`/`<S-Tab>` tab switching (Tab is deliberately unmapped to protect `<C-i>` jumplist); `Ctrl+\` prev tmux pane.
- **Dumped all resolved keymaps headless** (`nvim --headless`) to `~/.cache/nvim/keymaps_dump.json`: 291 global + 24 buffer-local normal-mode maps (gitsigns requires a *tracked* git file to attach). Saved the generator as `scripts/keymaps-dump.lua` so the dump can be regenerated anytime. Verified owners: ` sr` = grug-far, `<leader>sy` = yanky, `<leader>vs` = venv-selector (buffer-local, Python), `H`/`L`/`]b`/`[b` = keymaps.lua buffer nav, hardtime off by default, `maplocalleader = ' '` (Space, so octo in-buffer maps are `Space+po/pm/pc/pf`, not `\po`).
- **Key semantic correction**: tmux `prefix+h`/`v` split directions match nvim `sh`/`sv` exactly (h = side-by-side, v = stacked). Only the command *names* (`:vsplit` vs `split-window -v`) contradict. Notes updated so users trust the keys, not the names.
- **Second audit round (docs + remaining vault notes)**: removed the `<C-\>` "tmux previous pane" phantom from `keymaps.md` and `learn-nvim.html` (no such map exists in tmux.nvim or the dump), fixed the stale `learn-nvim.html` tmux code block (old `TmuxNavigateLeft/Right` commands replaced by tmux.nvim's actual `require"tmux".move_left()/move_right()` maps), corrected `lsp.md` `gi` → `gI` (implementation), and fixed `03 - Neovim.md`'s `Space+th` description (toggle inlay hints, not "hover helpers"). Everything else the sweep flagged was verified fine: `<S-h>`/`<S-l>` really are bound (nvim normalizes them to `H`/`L` in dumps), mini.ai `aa/af/ab/ac`-style textobjects resolve via the `a`/`i` operator + custom treesitter specs, tmux `1..9` window jumps and copy-mode keys confirmed live, octo `po/pm/pc/pf/pd` + `gf` + `Enter` confirmed against plugin defaults.
- **Reverse-coverage round (the other direction — what's in the dump but missing from docs)**: built a second checker (`/tmp/keycheck2.py`, variant-matching: `Space+x`/`<leader>x`/case forms; first two token-based attempts were defeated by a literal backtick in note 03's smart-skip row and family-shorthand rows, so no span-tokenizing). Found 57 genuinely undocumented user-facing maps and documented them in note 03 + `keymaps.md`: tmux.nvim `Alt+h/j/k/l` resize + `Alt+Ctrl+h/j/k/l` swap, `]d`/`[d` diagnostics, `Ctrl+w d` diagnostics float, `grt`/`grx` (nvim 0.12 builtin LSP), mini.bracketed `]q/[q` `]l/[l` `]t/[t` `]a/[a` (+ uppercase first/last), `[ `/`] ` empty-line, mini.ai `g[`/`g]` around-edges, surround `gsn` + the `n`/`l` next/last suffix family, `Space+qq/ql/qs` autosave. Remaining dump maps were verified as not-ours (nvim core defaults `gc/gcc/grt/grx/[<C-L>` family, matchit `[%/g%`, python ftplugin `[m/[[`) or already covered by family rows. Final state: **0 undocumented user-facing maps, 0 false doc claims** — both checker directions clean.

## Dump tool hardened (side effects of headless runs)

- **It self-bootstraps now.** The old header said "run from a TRACKED git repo" but the script always used its own `/tmp/probe_repo` (created manually, untracked `main.py`). It now `git init`s that probe repo itself, so it runs from any cwd, no prep.
- **It no longer clobbers your session.** A headless dump run was triggering the user config's `mini-sessions` VimLeavePre autocmd (probe `main.py` is a named buffer), overwriting `sessions/last` with dashboard-only junk. The script now clears the `mini-sessions` autocmd group before `qa!` (root cause was our own `lua/plugins/editor/mini.lua:73` autocmd, *not* mini.sessions' `autowrite`, which only fires on an active session). Verified: marker content in `sessions/last` survives a full dump run untouched.
- **Re-verified end-to-end** after both fixes: probe repo self-created, session preserved, dump byte-identical at 688 maps (g=291 / b=24), `gsn` + gitsigns `]c` present. Also confirmed the config is unchanged since the dump — no config file is newer than `keymaps_dump.json`, so the docs describe current reality.

## Prior

- Added `learn-nvim.html` — a standalone interactive walkthrough of the whole setup (basic → intermediate), styled to mirror the lualine mode colors.
