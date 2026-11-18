# 08 — Other Tools Layer (fzf, zoxide, atuin, direnv, mise, lazygit, yazi, bat, delta, fd, rg, glow)

This page documents the "other tools" layer: the shell utilities and TUIs that sit
between the terminal emulator (docs 01/02), the multiplexer (doc 03), the editor
(doc 04) and the prompt/reload machinery (00 architecture, 07 live-reload runbook).

All paths are relative to `~/mydotfiles` unless stated otherwise. Every wiring
claim below is backed by a `path:line` citation into the real configs; the
verification method is recorded in section 5. Where a tool is not actually
wired (glow), it is marked UNVERIFIED rather than described.

## 1. Layer at a glance

| Tool | Role in the workflow | Primary wiring | Startup mode |
|---|---|---|---|
| fzf | Fuzzy finder: Ctrl-T files, Alt+C dirs, completion UI | `shell/zshrc:107-124`, `shell/zshrc:173-180`, `shell/zshrc:89-101` | sourced from distro scripts, TTY-only |
| zoxide | Smarter `cd` via the `z` command | `shell/zshrc:154-155` | cached init, synchronous |
| atuin | Synced, searchable shell history (Ctrl+R / Up) | `shell/zshrc:170-171`, `.config/atuin/config.toml` | cached init, deferred to first prompt |
| direnv | Per-directory environment switching | `shell/zshrc:157-158` | cached init, synchronous |
| mise | Per-project tool versions (node/python/go/bun) | `shell/zshrc:160-168` | shims on PATH + lazy `activate` |
| lazygit | Git TUI in a float popup | `shell/zshrc:218`, `.config/tmux/tmux.conf:231`, `.config/lazygit/config.yml` | launch-time config; per-profile env |
| yazi | Terminal file manager, `y` cds on quit | `shell/zshrc:391-401`, `.config/tmux/tmux.conf:234` | wrapper function, guarded |
| bat | Syntax-highlighted `cat` + man pager + previews | `shell/zshrc:341-344`, `shell/zshrc:212`, `shell/zshrc:271` | launch-time env |
| delta | Diff renderer for lazygit (and git pager) | `.config/lazygit/config.yml:2-4`, `.config/lazygit/theme-apple-glass.yml:5` | launch-time config |
| fd | Fast file/dir source behind fzf | `shell/zshrc:174`, `shell/zshrc:176` | env vars |
| rg | grep backend for nvim's picker | `.config/nvim/lua/custom-neovim/health.lua:34`, `.config/nvim/lua/plugins/editor/snacks.lua:430` | on demand |
| glow | Markdown renderer — **absent / UNVERIFIED** | none found | n/a |

## 2. Per-tool wiring

### 2.1 fzf — fuzzy finder

**What it does.** Interactive fuzzy filtering for files, directories, command
history and zsh completion.

**Where it is wired.**

- The stock zsh widgets and completion are sourced from the first existing
  distro directory (`/usr/share/fzf`, Homebrew paths, `~/.fzf/shell`) at
  `shell/zshrc:115-121`; `key-bindings.zsh` is sourced at `shell/zshrc:117` and
  `completion.zsh` at `shell/zshrc:118`. This is what defines the default
  keybindings: **Ctrl-T** (files), **Alt+C** (cd into directory), **Ctrl+R**
  (command history).
- The whole block is TTY-gated at `shell/zshrc:113`, because fzf's scripts
  snapshot and restore every zsh option and that fails on the unchangeable
  `zle` option in a non-TTY (`zsh -i -c`, test harnesses); the rationale is in
  `shell/zshrc:110-112`.
- **Ctrl+R ownership:** when `atuin` is installed, fzf's redundant history
  widget is neutralised by setting `FZF_CTRL_R_COMMAND=""` at
  `shell/zshrc:114` and unsetting it at `shell/zshrc:123`, with the intent
  stated at `shell/zshrc:108-109`. Ctrl-T and Alt+C are deliberately preserved.
- **Sources and previews** are set at `shell/zshrc:173-180`:
  `FZF_DEFAULT_COMMAND` (`shell/zshrc:174`) and `FZF_CTRL_T_COMMAND`
  (`shell/zshrc:175`) use `fd` for files; `FZF_ALT_C_COMMAND` (`shell/zshrc:176`)
  uses `fd` for directories; `FZF_CTRL_T_OPTS` previews files with `bat`
  (`shell/zshrc:179`); `FZF_ALT_C_OPTS` previews directories with `eza`
  (`shell/zshrc:180`). `FZF_DEFAULT_OPTS` (`shell/zshrc:177`) sets height 45%,
  reverse layout, rounded border, inline info and `ctrl-/:toggle-preview`;
  the WezTerm profile appends transparent-background colours at
  `shell/zshrc:305`.
- **fzf-tab plugin** is queued as a deferred source at `shell/zshrc:89`. Its
  completion previews are styled at `shell/zshrc:91-101`: `eza` for `cd` and
  `z` completions (`shell/zshrc:96-97`), `bat` (with an `eza` branch for
  directories) for file arguments to `nvim|vim|nano|bat|cat`
  (`shell/zshrc:98`), `ps` for `kill` (`shell/zshrc:99`), and `/` as the
  continuous trigger (`shell/zshrc:101`).

**Role.** fzf is the interactive selection surface for the shell; `bat` and
`eza` provide its preview panes and `fd` provides its candidate lists.

### 2.2 zoxide — smarter cd

**What it does.** Learns frequently visited directories and exposes `z
<partial-name>` to jump to them.

**Where it is wired.** `shell/zshrc:154-155` calls
`_zsh_cached_init zoxide ... zoxide init zsh`, so `zoxide init zsh` generates
the `z` widget. The comment at `shell/zshrc:314-315` notes that zoxide "defines
`z`" and therefore stays synchronous (unlike the deferred plugins).

**Role.** Primary directory navigation; the `z` completion preview is handled
by `eza` (`shell/zshrc:97`).

### 2.3 atuin — synced shell history

**What it does.** Replaces the ordinary shell history search with a synced,
searchable TUI bound to Ctrl+R and the Up arrow.

**Where it is wired.**

- `shell/zshrc:170-171` initialises it with
  `_zsh_cached_init --defer atuin ... atuin init zsh`. The `--defer` flag
  (parsed at `shell/zshrc:139`, queued at `shell/zshrc:148`) means the cached
  init script is sourced by `_zsh_deferred_init` at first prompt or by the
  one-shot USR1 fallback (`shell/zshrc:318-338`, trap at `shell/zshrc:337`,
  timer at `shell/zshrc:338`).
- The comment at `shell/zshrc:170` states it "takes over Ctrl+R and Up-arrow
  bindings". A compatibility shim keeps the legacy `_atuin_widget` name alive
  for old bindings and the startup probe (`shell/zshrc:329-331`).
- `.config/atuin/config.toml` tunes the search: `search_mode` is `fuzzy` (`:51`),
  `filter_mode` is `global` (`:61`), the Up-arrow filter
  `filter_mode_shell_up_key_binding` is `directory` (`:66`),
  `workspaces = true` (`:74`), `style = "compact"`
  (`:78`), `inline_height = 16` (`:82`), `show_preview = true` (`:94`),
  `secrets_filter = true` (`:170`) and `enter_accept = true` (`:176`).
  The `[keys]` table exists (`:249`) but all entries are commented, so key
  bindings are atuin's defaults.
- Inside tmux, atuin uses a popup: `[tmux] enabled = true`
  (`.config/atuin/config.toml:350`) at width `80%` (`:354`) and height `60%`
  (`:358`).

**Role.** Canonical history search; because it owns Ctrl+R, fzf's own Ctrl+R
widget is suppressed (`shell/zshrc:114`, `shell/zshrc:123`). `secrets_filter`
(`.config/atuin/config.toml:170`) hides commands that look like secrets from
the synced search.

### 2.4 direnv — per-directory environments

**What it does.** Loads or unloads environment variables when entering or
leaving a directory with an `.envrc`.

**Where it is wired.** `shell/zshrc:157-158` calls
`_zsh_cached_init direnv ... direnv hook zsh`, so `direnv hook zsh` installs the
chpwd/prompt hooks. The comment at `shell/zshrc:315` notes direnv "mutates
prompt env", which is why it stays synchronous with zoxide rather than being
deferred.

**Role.** Per-project environment switching before a command runs. No `.envrc`
for the stack itself is committed in this repo (the only `.envrc` found belongs
to a vendored tmux plugin).

### 2.5 mise — per-project tool versions

**What it does.** Manages per-project versions of node/python/go/bun (per the
comment at `shell/zshrc:160`).

**Where it is wired.**

- `shell/zshrc:161` prepends `~/.local/share/mise/shims` to `PATH`, but only if
  that directory exists.
- `shell/zshrc:162-168` defines a lazy `mise()` function: on first invocation
  it removes itself (`shell/zshrc:164`), runs the `mise activate zsh`
  evaluation (`shell/zshrc:165`) and then executes the original command
  (`shell/zshrc:166`). This avoids paying for activation on every
  startup.

**Role.** Version shims are always on PATH; the activate hook is paid only when
`mise` is actually used.

### 2.6 lazygit — git TUI in a float

**What it does.** Terminal UI for git staging, committing, branching and diff
review.

**Where it is wired.**

- **Profile themes via `LG_CONFIG_FILE`.** The Kitty/Apple-Glass profile exports
  `LG_CONFIG_FILE` as the base config plus the Apple-Glass overlay at
  `shell/zshrc:218`; Kitty also sets it at `.config/kitty/custom.conf:19`. On
  tmux attach, `on-client-attached.sh` sets the same value for Kitty
  (`.config/tmux/scripts/on-client-attached.sh:49`, `:51`) and *unsets* it for
  the WezTerm profile (`:67`, `:69`). The overlay is
  `.config/lazygit/theme-apple-glass.yml` (delta with
  `--syntax-theme=ansi` at `:5`, teal border at `:9-11`). Two other theme files
  exist — `theme-kanagawa.yml:5` and `theme-nightfox.yml:5` — but they are not
  referenced by any `LG_CONFIG_FILE` in the repo, so they are alternative
  themes, not active profiles.
- **Base settings** live in `.config/lazygit/config.yml`: rounded border
  (`:7`), side panel width 0.33 (`:16`), `expandFocusedSidePanel` (`:17`),
  `disableStartupPopups` (`:19`) and `notARepository: quit` (`:20`).
- **Float launchers.** tmux `Prefix+g` opens lazygit in a 90%x90% rounded
  `display-popup` at the pane's cwd (`.config/tmux/tmux.conf:231`), with the
  sizing-parity rationale at `:227-230`. Kitty uses `ctrl+shift+g` as an
  overlay (`.config/kitty/custom.conf:179-180`). Inside nvim, the
  `<leader>gg` float is `Snacks.lazygit.open()` (`.config/nvim/lua/plugins/editor/snacks.lua:871`,
  `.config/nvim/lua/plugins/editor/snacks-extras.lua:66`, enabled at `:38`).
- **Theme regeneration.** On the WezTerm side,
  `.config/wezterm/utils/lazygit-lazydocker-palette.sh:50-78` rewrites the
  lazygit config from the matugen wallpaper palette while templating around the
  non-theme settings (delta renderer, quit behaviour) so they are preserved
  (comment at `:17-19`). lazygit reads its config at launch; there is no live
  reload (`:13-15`).

**Role.** Primary git interaction surface, reachable as a float from the shell's
tmux, from Kitty, and from nvim.

### 2.7 yazi — terminal file manager

**What it does.** Full-screen file manager; the stack wraps it so quitting
changes the *shell's* working directory.

**Where it is wired.**

- `shell/zshrc:391-401` defines `y()` (guarded by `command -v yazi` at `:392`).
  It creates a temp cwd file (`:394`), runs `yazi --cwd-file="$tmp"` (`:395`),
  reads the path back and `cd`s if it changed (`:396-397`), then removes the
  temp file (`:399`).
- tmux `Prefix+b` opens yazi in a 90%x90% rounded popup at the pane cwd
  (`.config/tmux/tmux.conf:234`).
- Behaviour config: `.config/yazi/yazi.toml:2-20` (layout ratio `:3`,
  alphabetical sort `:4-8`, preview sizing `:12-15`, and the edit opener using
  `${EDITOR:-nvim}` at `:18-19`). The theme is ANSI-adaptive so it harmonises
  with both Kitty and WezTerm (`.config/yazi/theme.toml:1-2`).

**Role.** Directory browsing with cwd synchronisation back into the interactive
shell.

### 2.8 bat — syntax-highlighted cat and man pager

**What it does.** A `cat` replacement with syntax highlighting, used both
directly and as the pager/previewer for other tools.

**Where it is wired.**

- **Man pager.** `shell/zshrc:341-344` exports a `MANPAGER` that pipes
  `col -bx` into `bat -l man -p` (`:342`) and `MANROFFOPT="-c"` (`:343`),
  guarded by `(( $+commands[bat] ))` at `:341`.
- **Theme.** `BAT_THEME="ansi"` is exported in both the Kitty profile
  (`shell/zshrc:212`) and the WezTerm profile (`shell/zshrc:271`); tmux's attach
  hook also sets it (`on-client-attached.sh:47-48` and `:63-64`).
- **Defaults file.** `.config/bat/config:1-3` sets
  `--style="numbers,changes,header"` (`:2`) and `--paging=auto` (`:3`).
- **As a previewer.** Used by fzf-tab for file completions (`shell/zshrc:98`)
  and by fzf Ctrl-T (`shell/zshrc:179`).

**Role.** Shared syntax-highlighting engine for man pages and fzf previews.

### 2.9 delta — diff renderer

**What it does.** Syntax-highlighted, side-by-side diff renderer.

**Where it is wired.**

- **lazygit (verified, in-repo).** `delta --dark --paging=never` is the git
  diff renderer in `.config/lazygit/config.yml:4`; the Apple-Glass overlay adds
  `--syntax-theme=ansi` at `.config/lazygit/theme-apple-glass.yml:5`. The
  palette regeneration script writes the same command at
  `.config/wezterm/utils/lazygit-lazydocker-palette.sh:60`.
- **git pager (outside this repo).** No git config file is committed in the
  repo, so there is no in-repo `core.pager = delta` setting to cite. The user's
  `~/.gitconfig:24` sets `pager = delta` (and `:28` sets
  `diffFilter = delta --color-only`). This lives outside `~/mydotfiles` and is
  therefore marked UNVERIFIED against the repo.

**Role.** Consistent diff rendering inside lazygit; the git-level pager depends
on the user-level git config, not on this repo.

### 2.10 fd — fzf's candidate source

**What it does.** Fast, user-friendly alternative to `find`.

**Where it is wired.** `shell/zshrc:174` sets `FZF_DEFAULT_COMMAND` to an
`fd --type f --hidden --follow` command that excludes `.git` and
`node_modules`; `shell/zshrc:175` inherits it for Ctrl-T; `shell/zshrc:176`
uses `fd --type d` for `FZF_ALT_C_COMMAND`. No other fd wiring was found in
`shell/`, `bin/` or `.config/`.

**Role.** Supplies all fzf file and directory candidates. Note it is `fd`, not
`rg`, that feeds fzf.

### 2.11 rg — grep/search backend

**What it does.** Fast recursive text search (ripgrep).

**Where it is wired (evidence-limited).**

- `.config/nvim/lua/custom-neovim/health.lua:34` lists `rg` as a required
  executable in the nvim health check.
- nvim's Snacks picker uses rg as its grep engine: the picker entry points are
  at `.config/nvim/lua/plugins/editor/snacks.lua:430` and `:437`, and the
  surrounding comments explicitly describe trimming selections into rg
  patterns (`:426`, `:433`).

**Important correction to the thin documentation:** no reference to `rg` was
found in `shell/`, `bin/`, `install.sh` or the tool configs. It is *not* an fzf
source — fzf uses `fd` (`shell/zshrc:174`, `shell/zshrc:176`). Its documented
role here is the nvim grep backend and a health-checked dependency only.

### 2.12 glow — absent (UNVERIFIED)

`command -v glow` returns nothing, and a repo-wide search of `shell/`, `bin/`,
`install.sh`, `.config/` and these docs found no `glow` invocation or config
(other than the English word "glow" in an unrelated nvim changelog and a tmux
plugin author name). **No glow wiring exists to document; this tool is marked
UNVERIFIED and excluded from the tables above.**

## 3. Cache / init map

The shared helper `_zsh_cached_init` is defined at `shell/zshrc:137-152`. Its
regeneration condition is at `shell/zshrc:143`: rebuild when the cache is
missing or empty (`! -s "$cache"`), when the binary is newer than the cache
(`! "$bin" -ot "$cache"`), or when a dependency file exists and is newer than
the cache. The write-and-fallback logic is at `shell/zshrc:145` (write the
`init`/`hook` output to the cache, or `eval` it directly if generation fails).
The missing-binary short circuit is `shell/zshrc:142`.

| Tool | Cache file | Invalidation trigger | Load mode |
|---|---|---|---|
| zoxide | `~/.cache/zsh-cache/zoxide.zsh` (`shell/zshrc:155`) | cache missing/empty, or `zoxide` binary newer than cache (no dep) | synchronous `source` (`shell/zshrc:150`) |
| direnv | `~/.cache/zsh-cache/direnv.zsh` (`shell/zshrc:158`) | cache missing/empty, or `direnv` binary newer than cache (no dep) | synchronous `source` (`shell/zshrc:150`) |
| atuin | `~/.cache/zsh-cache/atuin.zsh` (`shell/zshrc:171`) | cache missing/empty, or `atuin` binary newer than cache (no dep) | deferred (`--defer`, queued at `:148`, sourced at `:323-325`) |
| oh-my-posh (related) | `omp-apple-glass.zsh` / `omp-zen.zsh` / `omp-fallback.zsh` (`shell/zshrc:210`, `:262`, `:309`) | cache missing/empty, binary newer, **or** config TOML (the `dep` arg at `shell/zshrc:203`) newer than cache | synchronous; `POSH_SESSION_ID` regenerated per shell (`shell/zshrc:205`) |

Both cached-init functions are unset after setup at `shell/zshrc:312`.

## 4. Missing-binary degradation

| Binary missing | Guard that fires | Effect |
|---|---|---|
| zoxide | `shell/zshrc:142` (missing binary returns 0) | no `z` command; plain `cd` still works |
| direnv | `shell/zshrc:142` | no per-directory `.envrc` switching |
| atuin | `shell/zshrc:142`; `shell/zshrc:114` / `:123` | no history TUI; fzf's own Ctrl+R widget is kept instead |
| mise | `shell/zshrc:162` (`$+commands[mise]`) and `:161` (shim dir check) | shims not added to PATH; `mise` command undefined |
| fzf | `shell/zshrc:115-121` (source only if dir exists) | no fuzzy widgets; `bin/terminal-cheatsheet:577` falls back to table mode |
| bat | `shell/zshrc:341` (`$+commands[bat]`) | MANPAGER not exported; fzf/fzf-tab previews at `:98` / `:179` fail silently (stderr redirected) |
| eza | `shell/zshrc:361` (`command -v eza`) | `ls` aliases not installed; fzf Alt+C preview at `:180` fails |
| fd | `shell/zshrc:174`, `:176` (no guard) | fzf file/dir sources break; there is no fallback command |
| lazygit | none in zshrc; tmux bind at `.config/tmux/tmux.conf:231` | `Prefix+g` popup errors on exec; `LG_CONFIG_FILE` becomes inert |
| yazi | `shell/zshrc:392` (`command -v yazi`) | `y()` wrapper not defined; tmux popup at `:234` fails |
| delta | none in repo | lazygit diff renderer fails; user-level git pager (`~/.gitconfig:24`) fails |
| rg | `.config/nvim/lua/custom-neovim/health.lua:34` | health check flags it; nvim Snacks grep picker fails |
| glow | n/a | absent; nothing depends on it |

## 5. Cross-references and verification

- **Architecture:** [00 — Master Index & The 5-Layer Ecosystem Architecture](00-ecosystem-architecture.md), especially the navigation index (§5) and the prompt layer (§6, owned by A1). This doc 08 elaborates the shell-utility layer that 00 indexes.
- **Reload behaviour:** [07 — Live Reload Runbook](07-live-reload-runbook.md). Note that `stack-reload` does **not** re-exec zsh: the cached inits documented above (zoxide, direnv, atuin) are only regenerated when a shell starts, and the runbook's rule is to run `exec zsh` per shell. Palette regeneration of the lazygit theme (§2.6) is a launch-time read, not a live reload.
- **Incidents:** [06 — Hardware, Compositor & Troubleshooting Runbook](06-troubleshooting-runbook.md) for the quality gates and reload mechanics.
- **Master index:** [README.md](README.md) lists docs 00-08.

**Verification method (Gate 1).** Every `path:line` citation above was checked
against the live files with line-numbered reads and `sed -n 'Np'` spot-checks;
a batch check confirmed the exact text at 10+ citations spanning
`shell/zshrc`, `.config/atuin/config.toml`, `.config/lazygit/config.yml`,
`.config/tmux/tmux.conf`, `.config/kitty/custom.conf`, `.config/yazi/yazi.toml`
and `.config/bat/config`. Binary presence was checked with `command -v`:
fzf, zoxide, atuin, direnv, mise, lazygit, yazi, bat, delta, fd, rg and eza
are present; **glow is absent** and is the only tool marked UNVERIFIED/absent.
