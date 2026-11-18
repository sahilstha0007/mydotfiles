# 07 — Live Reload Runbook

Safe, non-destructive procedure for making running terminals pick up committed config.
All paths are relative to `~/mydotfiles` unless noted.

## Golden rule

**Never kill pane shells to reload them.** Interactive zsh shells are children of the
tmux server; killing them empties every pane, closes every session, and exits the server.
Use `exec zsh` from *inside* each shell instead. Do not use `pkill -f zsh` or `pkill -f kitty`
for a reload — `-f` matches full command lines and catches unrelated processes.

## One-command reload

```bash
stack-reload          # non-destructive: tmux + kitty + wezterm
stack-reload --dry-run   # preview without mutating
```

`bin/stack-reload` does, in order:
1. **tmux** — `source-file ~/.config/tmux/tmux.conf` (sessions/windows/panes preserved,
   server not restarted) + attached-profile sync.
2. **kitty** — sends `load-config` over each `@kitty-*` unix socket, falling back to
   `SIGUSR1` if no socket answered. (No remote-control socket is configured — this uses
   kitty's signal path; see the lockdown note below.)
3. **wezterm** — `touch`es `wezterm.lua` to trip its config mtime watcher.
4. Records reload stamps in `~/.cache/terminal-stack-reload/` so the freshness
   gate can verify a reload actually happened.

## What `stack-reload` does NOT do

- **zsh** — it only prints a note. Each open interactive shell must run `exec zsh`
  itself to adopt a new `.zshrc` / prompt. There is no safe external way to re-exec
  another shell's process.
- **nvim** — running instances keep old config until restarted, or you can trigger
  a palette re-tint live via `:lua require('utils.terminal-colors').reassert()`
  (sent by the palette reassert path to each socket in `$XDG_RUNTIME_DIR/nvim.*.0`).
- **Theme** — the stack uses a static Apple Glass palette. There is no wallpaper-driven
  regeneration (`sync-wallpaper.sh` and the matugen/sanitizer chain were removed in v10/v12).
  Palette changes are committed config, picked up by the same reload.

## Per-layer reference

| Layer | Reload action | Preserves sessions? |
|---|---|---|
| tmux | `stack-reload` (source-file) or `tmux source-file ~/.config/tmux/tmux.conf` | Yes |
| kitty | `stack-reload` (`load-config` / SIGUSR1) | Yes — windows stay open |
| wezterm | `stack-reload` (mtime touch, auto-reload) | Yes |
| zsh | `exec zsh` in each affected shell | Yes — but you must do it per shell |
| nvim | restart, or `:lua require('utils.terminal-colors').reassert()` | Yes (no restart needed for palette) |
| theme/palette | static committed files; reloaded with the layers above | n/a |

## Verify after reload

```bash
bin/devcheck            # 39/39 gates (fast tier)
bin/devcheck --all      # adds clean-clone, mutation, wiki lint, tmp-leak gate
tests/clean-clone.sh    # fresh clone must pass end-to-end
install.sh --doctor     # symlink/permission health
```

Freshness warnings (`STALE [zsh]`, `STALE [nvim]`) in `devcheck --all` are advisory:
they name a PID and the action to take. Defunct/zombie processes are ignored by the
checker (they cannot be reloaded). A `STALE [tmux]` means run `stack-reload`.

## Recovery: tmux sessions were lost

If sessions were killed (e.g. by killing pane shells), tmux-resurrect/continuum keeps
snapshots in `~/.local/share/tmux/resurrect/`. Restore with the smart wrapper:

```bash
tmux            # bare `tmux` in a terminal -> tmux-smart-attach, which restores
                # from the latest snapshot into a fresh server, then attaches
```

`~/.local/bin/tmux` (from `bin/tmux`) intercepts bare `tmux` / `tmux a` and calls
`tmux-smart-attach`, which starts a cold server with a dummy session "0", runs the
resurrect restore script, removes the dummy, and attaches to the last session.
The snapshot at the time of an incident is at `~/.local/share/tmux/resurrect/last`.

## Known gotchas

- **IPC & clipboard policy:** Kitty uses `allow_remote_control socket-only` + `listen_on unix:@kitty-{kitty_pid}`
  (required by `pass_keys.py`, `broadcast`, and `stack-reload`) with write-only clipboard
  (`clipboard_control write-clipboard write-primary`; clipboard reads stay blocked). Tmux enables
  OSC52 clipboard (`Ms`, `:clipboard`, `set -s set-clipboard on`) for cross-pane/SSH yanks.
- **Static palette (v10/v12):** `colors.json` under `.config/ohmyposh/` is dead (removed);
  the oh-my-posh prompt uses `zen.toml` / `zen-apple-glass.toml` directly. `colors-matugen.conf`
  in tmux is a committed static copy of `apple-glass.conf`, sourced by tmux.conf.
- A background `nvim --server ... --remote-send` job inherits flock fd 9 from the
  palette reassert path; fd 9 is closed in those children (`exec 9>&-`) so a dead
  nvim cannot block the next reload.
