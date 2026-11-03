#!/bin/sh
# Sync the current wallpaper -> the whole terminal stack: wezterm, kitty,
# tmux, nvim, the prompt and the TUIs. Uses an isolated matugen config for the
# wezterm/btop half so ml4w/hyprland's own palette is never touched.
#
# `-m smart` lets matugen read the wallpaper's luminance: bright wallpaper ->
# light scheme (dark text), dark wallpaper -> dark scheme (bright text). The
# palette direction lands in colors/matugen.lua and every consumer (wezterm
# custom.lua, tmux colors-from-matugen.sh, nvim terminal-colors.lua) derives
# light/dark from that one file, so the whole stack flips together.
#
# Latency model — wezterm fires this via background_child_process, so a
# keypress never waits on it. Each invocation is short-lived and serialized
# by flock. The quiet-window sleep after acquiring the lock lets rapid
# Alt+</>/+ presses overwrite $target first, so a burst of N presses costs
# ONE matugen run on the FINAL image instead of N queued cascades:
#   * repeat press (image already applied) -> exits in ~1ms
#   * presses during an active sync just update $target; the run holding the
#     lock re-reads it after the quiet window and applies the newest image
img="$1"
[ -n "$img" ] && [ -f "$img" ] || exit 0

cache="$HOME/.cache/wezterm-wallpaper"          # image wezterm restored / shows
target="$HOME/.cache/wezterm-wallpaper.target"  # most recently requested image
synced="$HOME/.cache/wezterm-wallpaper.synced"  # image the last sync applied
lock="$HOME/.cache/wezterm-wallpaper.lock"
wez_palette="$HOME/.config/wezterm/colors/matugen.lua"

# .synced says "this image is already themed", so it is only true while the
# palette it produced is still on disk. Without this second condition a DELETED
# or never-written palette made every guard below no-op forever: the image
# matched $synced, so matugen never re-ran and the theme stayed dead with no
# recovery short of deleting the cache files by hand. Same for the one-shot
# gui-startup check in events/gui-startup.lua.
already_synced() {
   [ "$1" = "$(cat "$synced" 2>/dev/null)" ] && [ -s "$wez_palette" ]
}

# Record the request up-front so whichever run holds the lock converges here.
printf '%s' "$img" > "$target"

# Repeat press (or a wezterm reload re-requesting the current image)?
# Instant no-op — nothing to do, no matugen, no lock.
already_synced "$img" && exit 0

# Serialize. A second press while a sync runs blocks here briefly, then sees
# the target already applied (below) and exits without doing any work.
exec 9>"$lock"
flock -x 9 || exit 0

# Quick check before the quiet window: an earlier run may already have synced
# the latest target while we were waiting for the lock.
t=$(cat "$target" 2>/dev/null) || exit 0
already_synced "$t" && exit 0

# Quiet window: let a burst of presses land and update $target, so only the
# final image of the burst gets themed.
sleep 0.3
t=$(cat "$target" 2>/dev/null) || exit 0
already_synced "$t" && exit 0

# Some wallpapers are PNG data with a .jpg extension (bytes 0x8950 = PNG
# magic). matugen's `-m smart` light/dark detection fails to decode those and
# silently falls back to defaults, so a bright mislabeled image could never
# flip the theme to light. Give matugen a temp copy with the REAL extension.
work="$t"
case "$t" in
   *.png|*.PNG) ;;
   *)
      sig=$(head -c 8 "$t" 2>/dev/null | od -An -tx1 | tr -d ' \n')
      if [ "$sig" = "89504e470d0a1a0a" ]; then
         work="$HOME/.cache/wezterm-wallpaper-work.png"
         cp "$t" "$work"
      fi
      ;;
esac

tmux_palette="$HOME/.config/tmux/colors-matugen.conf"
btop_theme="$HOME/.config/btop/themes/matugen.theme"
# A palette that cannot be read hashes as 'missing', NOT as the empty string.
# `cksum < missing_file` prints nothing at all, so a deleted or unreadable
# palette hashed empty before AND empty after, the guard at the bottom read
# "unchanged" and skipped the reload. 'missing' makes those two sides differ,
# so a palette that appears from nothing still counts as a change.
hash_of() { [ -f "$1" ] && cksum < "$1" 2>/dev/null || echo missing; }
pre_wez=$(hash_of "$wez_palette")
pre_tmux=$(hash_of "$tmux_palette")
pre_btop=$(hash_of "$btop_theme")

matugen_rc=0
# matugen's EXIT CODE IS NOT PROOF IT WROTE THE PALETTE. Verified on 4.2.0
# here: when the output file is read-only it prints
#   "x  <path> file is Read-Only, not writing to it."
# and EXITS 0, leaving the previous palette untouched. A template that does
# not resolve likewise exits 0 with nothing written.
#
# That made this a silent, PERMANENT failure. $synced below is the one value
# every guard in this script compares against, so a run that recorded it
# without producing a palette declared the image "done": re-picking that same
# wallpaper then hit the early-exit at the top forever and the theme stayed
# frozen on the previous palette, with no recovery short of deleting the cache
# file by hand. The user's symptom exactly: wallpaper changes, theme does not.
#
# So success = matugen exited 0, said NOTHING on stdout/stderr, and left a
# non-empty palette. Anything else fails loudly and is left retryable.
matugen_log=$(/usr/bin/matugen -c "$HOME/.config/matugen/wezterm.toml" image "$work" \
   --source-color-index 0 -m smart 2>&1) || matugen_rc=$?

if [ "$matugen_rc" -ne 0 ] || [ -n "$matugen_log" ] || [ ! -s "$wez_palette" ]; then
   echo "sync-wallpaper: matugen failed (rc=$matugen_rc) for $work" >&2
   [ -n "$matugen_log" ] && printf '%s\n' "$matugen_log" >&2
   echo "sync-wallpaper: palette NOT regenerated; leaving $t un-synced so it retries" >&2
   exit 1
fi

# Only mark the image as synced once the palette is genuinely on disk, so a
# failed run is retried on the next pick instead of being recorded as done with
# a stale palette. $cache is what wezterm restores on start, so keep them
# together.
printf '%s' "$t" > "$synced"
printf '%s' "$t" > "$cache"

# Re-derive tmux status colors from the same palette (keeps tmux text in
# lockstep with wezterm/nvim instead of a stale hand-written file).
"$HOME/.config/tmux/colors-from-matugen.sh"

# Re-render the oh-my-posh prompt from the same palette as explicit hexes
# (named ANSI colors would go stale inside tmux, whose palette is frozen at
# attach time). oh-my-posh re-reads the file on every prompt, so the next
# prompt shows the new colors with no restart.
"$HOME/.config/ohmyposh/omp-palette.sh"

# Emit zsh highlight colors computed from the wallpaper (nonexistent
# commands render in the accent's complementary hue). New shells pick this
# up; styles are read live by zsh-syntax-highlighting.
"$HOME/.config/wezterm/utils/zsh-highlight-sync.sh"

# Re-render herdr's chrome from the same palette (config.toml is generated
# from config.template.toml by herdr-palette.sh).
"$HOME/.config/herdr/herdr-palette.sh"

# opencode lives in this cascade (it's a TUI app of the dev stack).
"$HOME/.config/opencode/opencode-palette.sh"

# The Atlas vault's Obsidian snippet is the only non-TUI consumer left; Zed
# keeps its own theme and is deliberately out of this cascade.
"$HOME/.config/wezterm/utils/obsidian-palette.sh"

# lazygit + lazydocker: the last two TUIs still pinned to a hardcoded `blue`.
# Regenerate their config.yml theme from the same palette so they follow the
# wallpaper like everything else. They read config at launch (no live reload),
# so the new accent shows on the next Ctrl+a g / Ctrl+a d — which is fine.
"$HOME/.config/wezterm/utils/lazygit-lazydocker-palette.sh"

# Palette byte-identical (two images mapping to the same colors)? Skip the
# reload cascade — no tmux redraw, no wezterm config reload. btop is included
# so a stale btop file is always regenerated, even on a no-op wallpaper press.
[ "$pre_wez" = "$(hash_of "$wez_palette")" ] \
   && [ "$pre_tmux" = "$(hash_of "$tmux_palette")" ] \
   && [ "$pre_btop" = "$(hash_of "$btop_theme")" ] && exit 0

# Live cascade: tmux status + @thm_* tokens, then touch wezterm.lua so the
# config watcher reloads with the fresh palette (backdrops restores the
# current wallpaper from $cache, so the reload does not reshuffle). herdr
# re-reads its generated config.toml too (silently skipped when not running).
tmux source-file "$HOME/.config/tmux/tmux.conf" 2>/dev/null || true
herdr server reload-config >/dev/null 2>&1 || true
touch "$HOME/.config/wezterm/wezterm.lua"

# Notify running Neovim instances in background jobs so they re-tint immediately
# without stalling this script.
for sock in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/nvim.*.0; do
   [ -S "$sock" ] || continue
   (nvim --server "$sock" --remote-send "<Cmd>lua require('utils.terminal-colors').reassert()<CR>" >/dev/null 2>&1 || true) &
done
exit 0
