# ML4W vs Noctalia: exhaustive parity tally

Generated 2026-11-24 from local configs and upstream docs (ML4W OS 2.17, Noctalia v5.6.0).
Sources: ML4W backup `/home/sahil/mydotfiles/backups-noctalia-2026-11-22/hypr/`; cached ML4W settings `/home/sahil/.cache/ml4w/`; live Noctalia `~/.config/noctalia/config.toml`, `~/.local/state/noctalia/settings.toml`, `state.toml`, `~/.config/hypr-noctalia/hyprland.conf`, `hypridle.conf`, `session/`.

## Tally

| Sheet | Rows | Breakdown |
|---|---:|---|
| ML4W parameters | 981 | 963 active + 18 disabled/commented |
| Noctalia parameters | 664 | config.toml 255, settings.toml 82, state.toml 30, hyprland.conf 289, hypridle 7, plugins 6; 10 conflict flags (5 keys) |
| Keybinds cross-comparison | 114 | 54 SAME, 35 REMAP, 3 REPURPOSED, 13 LOST, 9 NEW (plus full per-side tables with every option verbatim) |
| Rules / workspaces / effects / services | 177 | 45 PORTED, 37 CHANGED, 73 DROPPED, 22 NEW |

## Contents

1. [Keybinds: full per-side tables + 114-row cross-comparison](#keybinds)
2. [Rules, workspaces, layouts, effects, idle, autostart, env, portals](#rules)
3. [ML4W parameters (981 rows)](#ml4w-parameters)
4. [Noctalia parameters (664 rows, conflicts flagged)](#noctalia-parameters)

---

<a id="keybinds"></a>
# Keybinding Extraction — ML4W (backup) vs Noctalia (test session)

Research-only extraction. All commands/dispatchers and options are reproduced verbatim from source. Nothing re-derived or simplified.

Sources read:

| Label | Path |
|---|---|
| ML4W default | `/home/sahil/mydotfiles/backups-noctalia-2026-11-22/hypr/conf/keybindings/default.lua` |
| ML4W custom | `/home/sahil/mydotfiles/backups-noctalia-2026-11-22/hypr/custom.lua` |
| ML4W GUI (top level) | `/home/sahil/mydotfiles/backups-noctalia-2026-11-22/hypr/hyprland-gui.lua` |
| ML4W GUI (hyprmod profile) | `/home/sahil/mydotfiles/backups-noctalia-2026-11-22/hypr/hyprmod/profiles/946cfc33be85/hyprland-gui.lua` |
| ML4W gestures | `/home/sahil/mydotfiles/backups-noctalia-2026-11-22/hypr/gestures.lua` |
| ML4W input (layout resolution) | `/home/sahil/mydotfiles/backups-noctalia-2026-11-22/hypr/input.lua` |
| ML4W load order | `/home/sahil/mydotfiles/backups-noctalia-2026-11-22/hypr/hyprland.lua` |
| Noctalia | `/home/sahil/mydotfiles/.config/hypr-noctalia/hyprland.conf` |

Load order (ML4W `hyprland.lua:9-49`): `functions` → `monitors` → `input` → `gestures` → `autostart` → colors/config → `conf.keybinding` (loads `default.lua`) → `conf.ml4w` → `hyprland-gui` → `custom` (last, overrides everything). The hyprmod-profile `hyprland-gui.lua` is byte-identical to the top-level one; both are listed as sources and counted once for effective binds.

---

## 1. ML4W keybind table

### 1.0 Resolution metadata

- `default.lua:2` — `local mainMod = "SUPER" -- Sets "Windows" key as main modifier`. All `mainMod .. " + ..."` combos below are expanded to `SUPER + ...`.
- Workspace key resolution (`default.lua:14-49`): `detect_azerty()` reads `~/.config/hypr/input.lua`, matches `kb_layout` / `kb_variant`.
  - Live `/home/sahil/.config/hypr/input.lua` does **not** exist → `detect_azerty()` returns `nil` → `ws_keys = nil` → `key = i % 10` → digits `1 2 3 4 5 6 7 8 9 0`.
  - Backup `input.lua:7-8` has `kb_layout = "us"`, `kb_variant = ""` → `azerty_keys["us"]` is nil → same result: digits `1 2 3 4 5 6 7 8 9 0`.
  - AZERTY fallback keysyms (only if layout is `fr`/`be` with a non-excluded variant): `fr` = `ampersand, eacute, quotedbl, apostrophe, parenleft, minus, egrave, underscore, ccedilla, agrave`; `be` = `ampersand, eacute, quotedbl, apostrophe, parenleft, section, egrave, exclam, ccedilla, agrave`. Excluded variants (`default.lua:22-25`): `fr` → `us, bepo, bepo_afnor, dvorak`; `be` → `wang` (these fall back to digits).
  - All 20 rows below use the **effective digit** keysyms; AZERTY aliases are noted per row.

### 1.1 Active binds — `default.lua` (95 rows)

| # | Exact key combo | Exact command/dispatcher (verbatim) | All options verbatim | Source file:line | Notes |
|---:|---|---|---|---|---|
| 1 | `SUPER + RETURN` | `hl.dsp.exec_cmd("~/.config/ml4w/settings/terminal.sh")` | `{ description = "Open the terminal" }` | default.lua:5 | Overridden by custom.lua:23 → `kitty` (final effective). |
| 2 | `SUPER + B` | `hl.dsp.exec_cmd("~/.config/ml4w/settings/browser.sh")` | `{ description = "Open the browser" }` | default.lua:6 | — |
| 3 | `SUPER + E` | `hl.dsp.exec_cmd("~/.config/ml4w/settings/filemanager")` | `{ description = "Open the filemanager" }` | default.lua:7 | — |
| 4 | `SUPER + CTRL + E` | `hl.dsp.exec_cmd("~/.config/ml4w/settings/emojipicker.sh")` | `{ description = "Open the emoji picker" }` | default.lua:8 | — |
| 5 | `SUPER + C` | `hl.dsp.exec_cmd("~/.config/ml4w/settings/calculator.sh")` | `{ description = "Open the calculator" }` | default.lua:9 | — |
| 6 | `SUPER + 1` | `hl.dsp.focus({ workspace = i})` with `i = 1` | `{ description = "Focus workspace " .. i }` | default.lua:50 (loop 48-52) | Workspace loop bind 1/20. AZERTY `fr`/`be` alias: `ampersand`. |
| 7 | `SUPER + SHIFT + 1` | `hl.dsp.window.move({ workspace = i })` with `i = 1` | `{ description = "Move window to workspace " .. i }` | default.lua:51 (loop 48-52) | Workspace loop bind 2/20. AZERTY alias: `ampersand`. |
| 8 | `SUPER + 2` | `hl.dsp.focus({ workspace = i})` with `i = 2` | `{ description = "Focus workspace " .. i }` | default.lua:50 (loop 48-52) | Workspace loop bind 3/20. AZERTY alias: `eacute`. |
| 9 | `SUPER + SHIFT + 2` | `hl.dsp.window.move({ workspace = i })` with `i = 2` | `{ description = "Move window to workspace " .. i }` | default.lua:51 (loop 48-52) | Workspace loop bind 4/20. AZERTY alias: `eacute`. |
| 10 | `SUPER + 3` | `hl.dsp.focus({ workspace = i})` with `i = 3` | `{ description = "Focus workspace " .. i }` | default.lua:50 (loop 48-52) | Workspace loop bind 5/20. AZERTY alias: `quotedbl`. |
| 11 | `SUPER + SHIFT + 3` | `hl.dsp.window.move({ workspace = i })` with `i = 3` | `{ description = "Move window to workspace " .. i }` | default.lua:51 (loop 48-52) | Workspace loop bind 6/20. AZERTY alias: `quotedbl`. |
| 12 | `SUPER + 4` | `hl.dsp.focus({ workspace = i})` with `i = 4` | `{ description = "Focus workspace " .. i }` | default.lua:50 (loop 48-52) | Workspace loop bind 7/20. AZERTY alias: `apostrophe`. |
| 13 | `SUPER + SHIFT + 4` | `hl.dsp.window.move({ workspace = i })` with `i = 4` | `{ description = "Move window to workspace " .. i }` | default.lua:51 (loop 48-52) | Workspace loop bind 8/20. AZERTY alias: `apostrophe`. |
| 14 | `SUPER + 5` | `hl.dsp.focus({ workspace = i})` with `i = 5` | `{ description = "Focus workspace " .. i }` | default.lua:50 (loop 48-52) | Workspace loop bind 9/20. AZERTY alias: `parenleft`. |
| 15 | `SUPER + SHIFT + 5` | `hl.dsp.window.move({ workspace = i })` with `i = 5` | `{ description = "Move window to workspace " .. i }` | default.lua:51 (loop 48-52) | Workspace loop bind 10/20. AZERTY alias: `parenleft`. |
| 16 | `SUPER + 6` | `hl.dsp.focus({ workspace = i})` with `i = 6` | `{ description = "Focus workspace " .. i }` | default.lua:50 (loop 48-52) | Workspace loop bind 11/20. AZERTY alias: `minus` (fr) / `section` (be). |
| 17 | `SUPER + SHIFT + 6` | `hl.dsp.window.move({ workspace = i })` with `i = 6` | `{ description = "Move window to workspace " .. i }` | default.lua:51 (loop 48-52) | Workspace loop bind 12/20. AZERTY alias: `minus` (fr) / `section` (be). |
| 18 | `SUPER + 7` | `hl.dsp.focus({ workspace = i})` with `i = 7` | `{ description = "Focus workspace " .. i }` | default.lua:50 (loop 48-52) | Workspace loop bind 13/20. AZERTY alias: `egrave`. |
| 19 | `SUPER + SHIFT + 7` | `hl.dsp.window.move({ workspace = i })` with `i = 7` | `{ description = "Move window to workspace " .. i }` | default.lua:51 (loop 48-52) | Workspace loop bind 14/20. AZERTY alias: `egrave`. |
| 20 | `SUPER + 8` | `hl.dsp.focus({ workspace = i})` with `i = 8` | `{ description = "Focus workspace " .. i }` | default.lua:50 (loop 48-52) | Workspace loop bind 15/20. AZERTY alias: `underscore` (fr) / `exclam` (be). |
| 21 | `SUPER + SHIFT + 8` | `hl.dsp.window.move({ workspace = i })` with `i = 8` | `{ description = "Move window to workspace " .. i }` | default.lua:51 (loop 48-52) | Workspace loop bind 16/20. AZERTY alias: `underscore` (fr) / `exclam` (be). |
| 22 | `SUPER + 9` | `hl.dsp.focus({ workspace = i})` with `i = 9` | `{ description = "Focus workspace " .. i }` | default.lua:50 (loop 48-52) | Workspace loop bind 17/20. AZERTY alias: `ccedilla`. |
| 23 | `SUPER + SHIFT + 9` | `hl.dsp.window.move({ workspace = i })` with `i = 9` | `{ description = "Move window to workspace " .. i }` | default.lua:51 (loop 48-52) | Workspace loop bind 18/20. AZERTY alias: `ccedilla`. |
| 24 | `SUPER + 0` | `hl.dsp.focus({ workspace = i})` with `i = 10` (`i % 10`) | `{ description = "Focus workspace " .. i }` | default.lua:50 (loop 48-52) | Workspace loop bind 19/20. Maps to workspace 10. AZERTY alias: `agrave`. |
| 25 | `SUPER + SHIFT + 0` | `hl.dsp.window.move({ workspace = i })` with `i = 10` (`i % 10`) | `{ description = "Move window to workspace " .. i }` | default.lua:51 (loop 48-52) | Workspace loop bind 20/20. Maps to workspace 10. AZERTY alias: `agrave`. |
| 26 | `SUPER + Q` | `hl.dsp.exec_cmd("~/.config/hypr/scripts/killactive.sh")` | `{ description = "Kill active window" }` | default.lua:55 | Final effective. A commented alternative `window.close()` exists at line 56 (see §1.5). |
| 27 | `SUPER + SHIFT + Q` | `hl.dsp.exec_cmd("hyprctl activewindow \| grep pid \| tr -d 'pid:' \| xargs kill")` | `{ description = "Quit active window and all open instances" }` | default.lua:57 | Pipe chars escaped as `\|` for the markdown table. |
| 28 | `SUPER + F` | `hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })` | `{ description = "Toggle Fullscreen" }` | default.lua:58 | — |
| 29 | `SUPER + M` | `hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })` | `{ description = "Toggle Maximize Window" }` | default.lua:59 | — |
| 30 | `SUPER + T` | `hl.dsp.window.float({ action = "toggle" })` | `{ description = "Toggle Floating" }` | default.lua:60 | — |
| 31 | `SUPER + SHIFT + T` | `hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-toggle-allfloat")` | `{ description = "Toggle floating for all windows of workspace" }` | default.lua:61 | — |
| 32 | `SUPER + ALT + T` | `function()<br>    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))<br>    hl.dispatch(hl.dsp.window.pin())<br>end` | `{ description = "Toggle floating + pinned" }` | default.lua:62 | Multi-statement function bind, verbatim body. |
| 33 | `SUPER + J` | `hl.dsp.layout("togglesplit")` | `{ description = "Toggle split" }` | default.lua:63 | — |
| 34 | `SUPER + left` | `hl.dsp.focus({ direction = "left" })` | `{ description = "Move focus left" }` | default.lua:64 | — |
| 35 | `SUPER + right` | `hl.dsp.focus({ direction = "right" })` | `{ description = "Move focus right" }` | default.lua:65 | — |
| 36 | `SUPER + up` | `hl.dsp.focus({ direction = "up" })` | `{ description = "Move focus up" }` | default.lua:66 | — |
| 37 | `SUPER + down` | `hl.dsp.focus({ direction = "down" })` | `{ description = "Move focus down" }` | default.lua:67 | — |
| 38 | `SUPER + mouse:272` | `hl.dsp.window.drag()` | `{ mouse = true, description = "Move window with the mouse" }` | default.lua:68 | Mouse bind (left button). |
| 39 | `SUPER + mouse:273` | `hl.dsp.window.resize()` | `{ mouse = true, description = "Resize window with the mouse" }` | default.lua:69 | Mouse bind (right button). |
| 40 | `SUPER + SHIFT + right` | `hl.dsp.window.resize({ x = 100, y = 0, relative = true })` | `{ repeating = true, description = "Increase window width with keyboard" }` | default.lua:70 | — |
| 41 | `SUPER + SHIFT + left` | `hl.dsp.window.resize({ x = -100, y = 0, relative = true })` | `{ repeating = true, description = "Reduce window width with keyboard" }` | default.lua:71 | — |
| 42 | `SUPER + SHIFT + down` | `hl.dsp.window.resize({ x = 0, y = 100, relative = true })` | `{ repeating = true, description = "Increase window height with keyboard" }` | default.lua:72 | — |
| 43 | `SUPER + SHIFT + up` | `hl.dsp.window.resize({ x = 0, y = -100, relative = true })` | `{ repeating = true, description = "Reduce window height with keyboard" }` | default.lua:73 | — |
| 44 | `SUPER + G` | `hl.dsp.group.toggle()` | `{ description = "Toggle window group" }` | default.lua:74 | — |
| 45 | `SUPER + K` | `hl.dsp.layout("swapsplit")` | `{ description = "Swapsplit" }` | default.lua:76 | — |
| 46 | `SUPER + ALT + left` | `hl.dsp.window.swap({ direction = "l" })` | `{ description = "Swap tiled window left" }` | default.lua:77 | — |
| 47 | `SUPER + ALT + right` | `hl.dsp.window.swap({ direction = "r" })` | `{ description = "Swap tiled window right" }` | default.lua:78 | — |
| 48 | `SUPER + ALT + up` | `hl.dsp.window.swap({ direction = "u" })` | `{ description = "Swap tiled window up" }` | default.lua:79 | — |
| 49 | `SUPER + ALT + down` | `hl.dsp.window.swap({ direction = "d" })` | `{ description = "Swap tiled window down" }` | default.lua:80 | — |
| 50 | `SUPER + SHIFT + A` | `hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle-animations.sh")` | `{ description = "Toggle animations" }` | default.lua:83 | — |
| 51 | `SUPER + PRINT` | `hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh")` | `{ description = "Take a screenshot" }` | default.lua:84 | — |
| 52 | `SUPER + ALT + F` | `hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh --instant")` | `{ description = "Take an instant full-screen screenshot" }` | default.lua:85 | — |
| 53 | `SUPER + ALT + S` | `hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh --instant-area")` | `{ description = "Take an instant area screenshot" }` | default.lua:86 | — |
| 54 | `SUPER + ALT + A` | `hl.dsp.exec_cmd("~/.config/hypr/scripts/text-extractor.sh")` | `{ description = "Extract text from an area" }` | default.lua:87 | — |
| 55 | `SUPER + CTRL + P` | `hl.dsp.exec_cmd("ml4w-powermenu toggle")` | `{ description = "Start Power Menu" }` | default.lua:88 | — |
| 56 | `SUPER + W` | `hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-wallpaper-app --carousel")` | `{ description = "Open wallpaper carousel" }` | default.lua:89 | — |
| 57 | `SUPER + SHIFT + W` | `hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-wallpaper-app --random")` | `{ description = "Change the wallpaper" }` | default.lua:90 | — |
| 58 | `SUPER + CTRL + W` | `hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-wallpaper-app")` | `{ description = "Open wallpaper selector" }` | default.lua:91 | — |
| 59 | `SUPER + ALT + W` | `hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-wallpaper-automation")` | `{ description = "Start random wallpaper script" }` | default.lua:92 | — |
| 60 | `SUPER + CTRL + RETURN` | `hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-launcher")` | `{ description = "Open application launcher" }` | default.lua:93 | — |
| 61 | `SUPER + CTRL + K` | `hl.dsp.exec_cmd("~/.config/hypr/scripts/keybindings.sh")` | `{ description = "Show keybindings" }` | default.lua:94 | — |
| 62 | `SUPER + SHIFT + B` | `hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-reload-statusbar")` | `{ description = "Reload Status Bar" }` | default.lua:95 | — |
| 63 | `SUPER + CTRL + B` | `hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-toggle-statusbar")` | `{ description = "Toggle Status Bar" }` | default.lua:96 | — |
| 64 | `SUPER + ALT + B` | `hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-toggle-statusbar-autohide")` | `{ description = "Toggle Status Bar Autohide" }` | default.lua:97 | — |
| 65 | `SUPER + SHIFT + D` | `hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-reload-dock")` | `{ description = "Reload Dock" }` | default.lua:98 | — |
| 66 | `SUPER + CTRL + D` | `hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-toggle-dock")` | `{ description = "Toggle Dock" }` | default.lua:99 | — |
| 67 | `SUPER + ALT + D` | `hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-toggle-dock-autohide")` | `{ description = "Toggle Dock Autohide" }` | default.lua:100 | — |
| 68 | `SUPER + SHIFT + R` | `hl.dsp.exec_cmd("~/.config/hypr/scripts/loadconfig.sh")` | `{ description = "Reload hyprland config" }` | default.lua:101 | — |
| 69 | `SUPER + V` | `hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-cliphist")` | `{ description = "Open clipboard manager" }` | default.lua:102 | — |
| 70 | `SUPER + CTRL + T` | `hl.dsp.exec_cmd("~/.config/waybar/themeswitcher.sh")` | `{ description = "Open waybar theme switcher" }` | default.lua:103 | — |
| 71 | `SUPER + SHIFT + M` | `hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-toggle-theme")` | `{ description = "Toggle between light and dark mode" }` | default.lua:104 | — |
| 72 | `SUPER + CTRL + S` | `hl.dsp.exec_cmd("qs ipc call sidebar toggle")` | `{ description = "Open ML4W Sidebar widget" }` | default.lua:105 | — |
| 73 | `SUPER + CTRL + C` | `hl.dsp.exec_cmd("qs ipc call calendar toggle")` | `{ description = "Open ML4W Calendar widget" }` | default.lua:106 | — |
| 74 | `SUPER + SPACE` | `hl.dsp.exec_cmd("qs ipc call statusbar focus")` | `{ description = "Expand statusbar and focus it for keyboard navigation" }` | default.lua:107 | — |
| 75 | `SUPER + ALT + G` | `hl.dsp.exec_cmd("~/.config/hypr/scripts/gamemode.sh")` | `{ description = "Toggle game mode" }` | default.lua:108 | — |
| 76 | `SUPER + CTRL + L` | `hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-power -l")` | `{ description = "Lock Screen" }` | default.lua:109 | — |
| 77 | `SUPER + SHIFT + H` | `hl.dsp.exec_cmd("~/.config/ml4w/scripts/ml4w-toggle-hyprsunset")` | `{ description = "Toggle Hyprsunset" }` | default.lua:110 | — |
| 78 | `SUPER + Tab` | `hl.dsp.exec_cmd("qs -p ~/.local/share/quickshell-overview ipc call overview toggle")` | `{ description = "Open Select Window Menu" }` | default.lua:111 | — |
| 79 | `CTRL + ALT + T` | `hl.dsp.exec_cmd("~/.config/ml4w/themes/themes.sh")` | `{ description = "Open theme switcher" }` | default.lua:112 | — |
| 80 | `ALT + Tab` | `hl.dsp.exec_cmd("qs -p ~/.local/share/hypr-app-switcher ipc call app-switcher next")` | `{ description = "Switch applications on active workspace" }` | default.lua:115 | — |
| 81 | `ALT + SHIFT + Tab` | `hl.dsp.exec_cmd("qs -p ~/.local/share/hypr-app-switcher ipc call app-switcher prev")` | `{ description = "Switch applications on active workspace (backwards)" }` | default.lua:116 | — |
| 82 | `SUPER + S` | `hl.dsp.workspace.toggle_special("scratchpad")` | `{ description = "Toggle special workspace scratchpad" }` | default.lua:119 | — |
| 83 | `SUPER + SHIFT + S` | `function()<br>    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))<br>    hl.dispatch(hl.dsp.window.move({ workspace = "special:scratchpad" }))<br>end` | `{ description = "Move window to special workspace scratchpad" }` | default.lua:120-123 | Multi-statement function bind, verbatim body. |
| 84 | `SUPER + mouse_down` | `throttled_scroll(hl.dsp.focus({ workspace = "e+1" }))` (wraps `hl.dispatch(dispatcher)` + `hl.timer(function() scroll_locked = false end, { timeout = 200, type = "oneshot" })`) | `{ description = "Switch to next workspace" }` | default.lua:156-160 | Throttled (200 ms oneshot lock, `scroll_locked`, lines 136-154). Commented non-throttled form at 126. |
| 85 | `SUPER + mouse_up` | `throttled_scroll(hl.dsp.focus({ workspace = "e-1" }))` (same throttle wrapper) | `{ description = "Switch to previous workspace" }` | default.lua:162-166 | Throttled (200 ms). Commented non-throttled form at 127. |
| 86 | `XF86AudioRaiseVolume` | `hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+")` | `{ locked = true, repeating = true, description = "Raise volume" }` | default.lua:169 | — |
| 87 | `XF86AudioLowerVolume` | `hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")` | `{ locked = true, repeating = true, description = "Lower volume" }` | default.lua:170 | — |
| 88 | `XF86AudioMute` | `hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")` | `{ locked = true, repeating = true, description = "Mute audio" }` | default.lua:171 | — |
| 89 | `XF86AudioMicMute` | `hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")` | `{ locked = true, repeating = true, description = "Mute microphone" }` | default.lua:172 | — |
| 90 | `XF86MonBrightnessUp` | `hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+")` | `{ locked = true, repeating = true, description = "Increase brightness" }` | default.lua:173 | Overridden by custom.lua:6 → `brightness.sh up`. |
| 91 | `XF86MonBrightnessDown` | `hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-")` | `{ locked = true, repeating = true, description = "Decrease brightness" }` | default.lua:174 | Overridden by custom.lua:9 → `brightness.sh down`. |
| 92 | `XF86AudioNext` | `hl.dsp.exec_cmd("playerctl next")` | `{ locked = true, description = "Next track" }` | default.lua:177 | — |
| 93 | `XF86AudioPause` | `hl.dsp.exec_cmd("playerctl play-pause")` | `{ locked = true, description = "Pause audio" }` | default.lua:178 | — |
| 94 | `XF86AudioPlay` | `hl.dsp.exec_cmd("playerctl play-pause")` | `{ locked = true, description = "Play audio" }` | default.lua:179 | — |
| 95 | `XF86AudioPrev` | `hl.dsp.exec_cmd("playerctl previous")` | `{ locked = true, description = "Previous track" }` | default.lua:180 | — |

Related non-bind config (`default.lua:129-134`): `hl.config({ binds = { pass_mouse_when_bound = false, scroll_event_delay = 1 } })`.

### 1.2 Active binds — `custom.lua` (7 rows)

Loaded last; these are the final effective bindings for their combos.

| # | Exact key combo | Exact command/dispatcher (verbatim) | All options verbatim | Source file:line | Notes |
|---:|---|---|---|---|---|
| 1 | `XF86MonBrightnessUp` | `hl.dsp.exec_cmd("~/.config/hypr/scripts/brightness.sh up")` | `{ locked = true, repeating = true, description = "Increase brightness" }` | custom.lua:6 | Preceded by `hl.unbind("XF86MonBrightnessUp")` at custom.lua:5; overrides default.lua:173. |
| 2 | `XF86MonBrightnessDown` | `hl.dsp.exec_cmd("~/.config/hypr/scripts/brightness.sh down")` | `{ locked = true, repeating = true, description = "Decrease brightness" }` | custom.lua:9 | Preceded by `hl.unbind("XF86MonBrightnessDown")` at custom.lua:8; overrides default.lua:174. |
| 3 | `SUPER + F4` | `hl.dsp.exec_cmd("~/.config/hypr/scripts/brightness.sh up")` | `{ locked = true, repeating = true, description = "Increase brightness" }` | custom.lua:12 | Preceded by `hl.unbind("SUPER + F4")` at custom.lua:11. |
| 4 | `SUPER + F3` | `hl.dsp.exec_cmd("~/.config/hypr/scripts/brightness.sh down")` | `{ locked = true, repeating = true, description = "Decrease brightness" }` | custom.lua:15 | Preceded by `hl.unbind("SUPER + F3")` at custom.lua:14. |
| 5 | `SUPER + F2` | `hl.dsp.exec_cmd("~/.config/hypr/scripts/brightness.sh down")` | `{ locked = true, repeating = true, description = "Decrease brightness" }` | custom.lua:18 | Preceded by `hl.unbind("SUPER + F2")` at custom.lua:17. |
| 6 | `SUPER + RETURN` | `hl.dsp.exec_cmd("kitty")` | `{ description = "Open Kitty" }` | custom.lua:23 | Preceded by unbinds at custom.lua:21-22; overrides default.lua:5 (`terminal.sh`). |
| 7 | `SUPER + SHIFT + RETURN` | `hl.dsp.exec_cmd("wezterm")` | `{ description = "Open WezTerm" }` | custom.lua:27 | Preceded by unbinds at custom.lua:25-26; also matches hyprland-gui.lua:29. |

### 1.3 Active binds — `hyprland-gui.lua` (2 rows)

Identical content at both `/hypr/hyprland-gui.lua` and `/hypr/hyprmod/profiles/946cfc33be85/hyprland-gui.lua`.

| # | Exact key combo | Exact command/dispatcher (verbatim) | All options verbatim | Source file:line | Notes |
|---:|---|---|---|---|---|
| 1 | `SUPER + CTRL + H` | `hl.dsp.exec_cmd("~/.config/hypr/scripts/display-mode.sh")` | `{ description = "Open screen display mode menu" }` | hyprland-gui.lua:25-27 (profile copy:25-27) | Preceded by `hl.unbind("SUPER + CTRL + H")` at line 24. |
| 2 | `SUPER + SHIFT + Return` | `hl.dsp.exec_cmd("wezterm")` | `{ description = "Open WezTerm" }` | hyprland-gui.lua:29-31 (profile copy:29-31) | Preceded by `hl.unbind("SUPER + SHIFT + RETURN")` at line 28. Case variant `Return` vs `RETURN`; same physical combo. Exists in both GUI copies; custom.lua:27 is a third identical bind. |

### 1.4 Gestures — `gestures.lua` (4 rows)

| # | Exact key combo | Exact command/dispatcher (verbatim) | All options verbatim | Source file:line | Notes |
|---:|---|---|---|---|---|
| 1 | Gesture: 3-finger vertical swipe | `action = "workspace"` | `fingers = 3`, `direction = "vertical"`, `action = "workspace"` | gestures.lua:6-10 | `hl.gesture({ ... })` block. |
| 2 | Gesture: 3-finger horizontal swipe | `action = "scroll_move"`, `scale = 0.9` | `fingers = 3`, `direction = "horizontal"`, `action = "scroll_move"`, `scale = 0.9` | gestures.lua:13-18 | `hl.gesture({ ... })` block. |
| 3 | Gesture: 4-finger pinch out | `action = function () hl.dispatch(hl.dsp.window.fullscreen({ action="set" })) end` | `fingers = 4`, `direction = "pinchout"` | gestures.lua:21-23 | Inline function body verbatim: `hl.dispatch(hl.dsp.window.fullscreen({ action="set" }))`. |
| 4 | Gesture: 4-finger pinch in | `action = function () hl.dispatch(hl.dsp.window.fullscreen({ action="unset" })) end` | `fingers = 4`, `direction = "pinchin"` | gestures.lua:26-28 | Inline function body verbatim: `hl.dispatch(hl.dsp.window.fullscreen({ action="unset" }))`. |

### 1.5 Commented-out entries (separate subsection, 4 rows)

| # | Exact key combo | Exact command/dispatcher (verbatim, including comment marker) | All options verbatim | Source file:line | Notes |
|---:|---|---|---|---|---|
| 1 | `SUPER + Q` | `-- hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { description = "Kill active window" })` | `{ description = "Kill active window" }` | default.lua:56 | COMMENTED OUT — not active. Active `SUPER + Q` at line 55 uses `killactive.sh`; this `window.close()` variant never fires. |
| 2 | `SUPER + SHIFT + G` | `-- hl.bind(mainMod .. " + SHIFT + G", hl.dsp.group.active("f"), { description = "Switch to next group window" })` | `{ description = "Switch to next group window" }` | default.lua:75 | COMMENTED OUT — unbound in ML4W. Noctalia binds this combo to HyprGlass toggle. |
| 3 | `SUPER + mouse_down` | `-- hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Switch to next workspace" })` | `{ description = "Switch to next workspace" }` | default.lua:126 | COMMENTED OUT — non-throttled form. Active throttled form at lines 156-160. |
| 4 | `SUPER + mouse_up` | `-- hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "Switch to previous workspace" })` | `{ description = "Switch to previous workspace" }` | default.lua:127 | COMMENTED OUT — non-throttled form. Active throttled form at lines 162-166. |

### 1.6 `hl.unbind(...)` entries / overridden combos (separate subsection, 13 unique rows)

| # | Exact key combo | Verbatim unbind statement | Followed by | Source file:line | Notes |
|---:|---|---|---|---|---|
| 1 | `XF86MonBrightnessUp` | `hl.unbind("XF86MonBrightnessUp")` | custom.lua:6 rebind | custom.lua:5 | Overrides default.lua:173. |
| 2 | `XF86MonBrightnessDown` | `hl.unbind("XF86MonBrightnessDown")` | custom.lua:9 rebind | custom.lua:8 | Overrides default.lua:174. |
| 3 | `SUPER + F4` | `hl.unbind("SUPER + F4")` | custom.lua:12 rebind | custom.lua:11 | New ML4W combo. |
| 4 | `SUPER + F3` | `hl.unbind("SUPER + F3")` | custom.lua:15 rebind | custom.lua:14 | Brightness-down override. |
| 5 | `SUPER + F2` | `hl.unbind("SUPER + F2")` | custom.lua:18 rebind | custom.lua:17 | New ML4W combo. |
| 6 | `SUPER + RETURN` | `hl.unbind("SUPER + RETURN")` | custom.lua:23 rebind (`kitty`) | custom.lua:21 | Overrides default.lua:5 (`terminal.sh`). |
| 7 | `SUPER + Return` | `hl.unbind("SUPER + Return")` | (case variant) | custom.lua:22 | Case variant of row 6; same physical combo. |
| 8 | `SUPER + SHIFT + RETURN` | `hl.unbind("SUPER + SHIFT + RETURN")` | custom.lua:27 rebind (`wezterm`) | custom.lua:25 | Overrides GUI/wezterm bind. |
| 9 | `SUPER + SHIFT + Return` | `hl.unbind("SUPER + SHIFT + Return")` | (case variant) | custom.lua:26 | Case variant of row 8. |
| 10 | `SUPER + ALT + RETURN` | `hl.unbind("SUPER + ALT + RETURN")` | **none** — left unbound | custom.lua:29 | No rebind anywhere in ML4W source. |
| 11 | `SUPER + ALT + Return` | `hl.unbind("SUPER + ALT + Return")` | **none** — left unbound | custom.lua:30 | Case variant of row 10. |
| 12 | `SUPER + CTRL + H` | `hl.unbind("SUPER + CTRL + H")` | hyprland-gui.lua:25 rebind | hyprland-gui.lua:24 (profile copy:24) | HyprMod-generated override. |
| 13 | `SUPER + SHIFT + RETURN` | `hl.unbind("SUPER + SHIFT + RETURN")` | hyprland-gui.lua:29 rebind (`wezterm`) | hyprland-gui.lua:28 (profile copy:28) | Duplicate of row 8 in the GUI profile. |

Note: the non-bind `hl.window_rule({ name = "zen-opacity", match = { class = "^(zen)$" }, opacity = "1.0 1.0" })` at custom.lua:33-37 is a window rule, not a keybind; listed here only to flag that custom.lua's only other statement is not a bind.

**ML4W totals:** 95 (default.lua) + 7 (custom.lua) + 2 (GUI) = **104 active keybinds**; **4 gestures**; **4 commented-out**; **13 unbind entries**. 108 active bind+gesture rows.

---

## 2. Noctalia keybind table

Source: `/home/sahil/mydotfiles/.config/hypr-noctalia/hyprland.conf`. `SUPER` is spelled out explicitly (no `mainMod` variable). Case variants (`Return`/`RETURN`, `Tab`/`TAB`) preserved verbatim in the combo column.

### 2.1 Active binds (97 rows)

| # | Exact key combo | Exact command/dispatcher (verbatim) | All options verbatim | Source file:line | Notes |
|---:|---|---|---|---|---|
| 1 | `SUPER + ALT + G` | `hl.dsp.exec_cmd("noctalia msg panel-open launcher /glass")` | `{ description = "Glass mode menu" }` | hyprland.conf:261 | Inside `if hl.plugin.hyprglass then` block (line 170). ML4W Super+Alt+G was gamemode.sh. |
| 2 | `SUPER + SHIFT + G` | `function()<br>    glass_on = not glass_on<br>    hg.config({ enabled = glass_on })<br>end` | `{ description = "Toggle HyprGlass on/off" }` | hyprland.conf:264-267 | Local `glass_on = true` at line 263. ML4W had this combo commented out. |
| 3 | `SUPER + RETURN` | `hl.dsp.exec_cmd("kitty")` | `{ description = "Kitty" }` | hyprland.conf:284 | — |
| 4 | `SUPER + SHIFT + RETURN` | `hl.dsp.exec_cmd("wezterm")` | `{ description = "WezTerm" }` | hyprland.conf:285 | — |
| 5 | `SUPER + B` | `hl.dsp.exec_cmd("brave")` | `{ description = "Brave" }` | hyprland.conf:286 | — |
| 6 | `SUPER + E` | `hl.dsp.exec_cmd("nautilus")` | `{ description = "Files" }` | hyprland.conf:287 | — |
| 7 | `SUPER + D` | `hl.dsp.exec_cmd("noctalia msg panel-toggle launcher")` | `{ description = "Noctalia launcher" }` | hyprland.conf:288 | NEW combo (ML4W binds only SHIFT/CTRL/ALT+D variants). |
| 8 | `SUPER + SPACE` | `hl.dsp.exec_cmd("noctalia msg panel-toggle launcher")` | `{ description = "Noctalia launcher (Super+Space)" }` | hyprland.conf:289 | ML4W Super+Space was `qs ipc call statusbar focus`. |
| 9 | `SUPER + V` | `hl.dsp.exec_cmd("noctalia msg panel-toggle clipboard")` | `{ description = "Clipboard history" }` | hyprland.conf:290 | — |
| 10 | `SUPER + SHIFT + C` | `hl.dsp.exec_cmd("noctalia msg panel-toggle control-center")` | `{ description = "Control center" }` | hyprland.conf:291 | NEW combo. |
| 11 | `SUPER + CTRL + P` | `hl.dsp.exec_cmd("noctalia msg panel-toggle session")` | `{ description = "Power/session menu (ML4W Super+Ctrl+P)" }` | hyprland.conf:292 | — |
| 12 | `SUPER + SHIFT + N` | `hl.dsp.exec_cmd("noctalia msg notification-dnd-toggle")` | `{ description = "Toggle Do Not Disturb" }` | hyprland.conf:293 | NEW combo. |
| 13 | `SUPER + L` | `hl.dsp.exec_cmd("noctalia msg session lock")` | `{ description = "Lock (Noctalia IPC; loginctl lock-session is fallback)" }` | hyprland.conf:294 | NEW combo (ML4W locks with Super+Ctrl+L). |
| 14 | `ALT + TAB` | `hl.dsp.exec_cmd("noctalia msg window-switcher hold")` | `{ description = "Noctalia window switcher" }` | hyprland.conf:295 | — |
| 15 | `SUPER + TAB` | `hl.dsp.exec_cmd("noctalia msg window-switcher")` | `{ description = "Window overview (ML4W Super+Tab)" }` | hyprland.conf:296 | — |
| 16 | `SUPER + SHIFT + TAB` | `hl.dsp.exec_cmd("noctalia msg window-switcher reverse")` | `{ description = "Window overview reverse" }` | hyprland.conf:297 | NEW combo. |
| 17 | `ALT + SHIFT + TAB` | `hl.dsp.exec_cmd("noctalia msg window-switcher hold reverse")` | `{ description = "Window switcher reverse (ML4W Alt+Shift+Tab)" }` | hyprland.conf:298 | — |
| 18 | `SUPER + H` | `hl.dsp.exec_cmd("noctalia msg caffeine-toggle")` | `{ description = "Toggle idle inhibitor (calls/presentations)" }` | hyprland.conf:299 | NEW combo. |
| 19 | `SUPER + CTRL + RETURN` | `hl.dsp.exec_cmd("noctalia msg panel-toggle launcher")` | `{ description = "Launcher (ML4W Super+Ctrl+Return)" }` | hyprland.conf:300 | — |
| 20 | `SUPER + CTRL + L` | `hl.dsp.exec_cmd("noctalia msg session lock")` | `{ description = "Lock (ML4W Super+Ctrl+L)" }` | hyprland.conf:301 | — |
| 21 | `SUPER + F4` | `hl.dsp.exec_cmd("noctalia msg brightness-up 5%")` | `{ description = "Brightness up (ML4W fallback)" }` | hyprland.conf:302 | — |
| 22 | `SUPER + F3` | `hl.dsp.exec_cmd("noctalia msg brightness-down 5%")` | `{ description = "Brightness down (ML4W fallback)" }` | hyprland.conf:303 | — |
| 23 | `SUPER + F2` | `hl.dsp.exec_cmd("noctalia msg brightness-down 5%")` | `{ description = "Brightness down (ML4W fallback)" }` | hyprland.conf:304 | — |
| 24 | `SUPER + SHIFT + H` | `hl.dsp.exec_cmd("noctalia msg nightlight-force-toggle")` | `{ description = "Night light force toggle (ML4W Super+Shift+H)" }` | hyprland.conf:305 | — |
| 25 | `SUPER + CTRL + H` | `hl.dsp.exec_cmd("noctalia msg panel-open launcher /eye")` | `{ description = "Eye-care menu in Noctalia launcher (ML4W Super+Ctrl+H)" }` | hyprland.conf:306 | ML4W GUI bound this to display-mode.sh. |
| 26 | `SUPER + CTRL + E` | `hl.dsp.exec_cmd("noctalia msg panel-open launcher /emo")` | `{ description = "Emoji picker (ML4W Super+Ctrl+E)" }` | hyprland.conf:307 | — |
| 27 | `SUPER + W` | `hl.dsp.exec_cmd("noctalia msg wallpaper-next")` | `{ description = "Next wallpaper (ML4W Super+W)" }` | hyprland.conf:308 | — |
| 28 | `SUPER + SHIFT + W` | `hl.dsp.exec_cmd("noctalia msg wallpaper-random")` | `{ description = "Random wallpaper (ML4W Super+Shift+W)" }` | hyprland.conf:309 | — |
| 29 | `SUPER + CTRL + W` | `hl.dsp.exec_cmd("noctalia msg panel-toggle wallpaper")` | `{ description = "Wallpaper picker (ML4W Super+Ctrl+W)" }` | hyprland.conf:310 | — |
| 30 | `SUPER + SHIFT + M` | `hl.dsp.exec_cmd("noctalia msg theme-mode-toggle")` | `{ description = "Toggle theme mode (ML4W Super+Shift+M)" }` | hyprland.conf:311 | — |
| 31 | `SUPER + CTRL + B` | `hl.dsp.exec_cmd("noctalia msg bar-toggle")` | `{ description = "Toggle bar" }` | hyprland.conf:312 | — |
| 32 | `SUPER + CTRL + D` | `hl.dsp.exec_cmd("noctalia msg dock-toggle")` | `{ description = "Toggle dock" }` | hyprland.conf:313 | — |
| 33 | `SUPER + Q` | `hl.dsp.window.close()` | `{ description = "Close window" }` | hyprland.conf:316 | ML4W uses `killactive.sh` script. |
| 34 | `SUPER + SHIFT + Q` | `hl.dsp.window.kill()` | `{ description = "Force-kill active window (ML4W)" }` | hyprland.conf:317 | — |
| 35 | `SUPER + F` | `hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })` | `{ description = "Fullscreen" }` | hyprland.conf:318 | — |
| 36 | `SUPER + M` | `hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })` | `{ description = "Maximize" }` | hyprland.conf:319 | — |
| 37 | `SUPER + T` | `hl.dsp.window.float({ action = "toggle" })` | `{ description = "Float" }` | hyprland.conf:320 | — |
| 38 | `SUPER + J` | `hl.dsp.layout("togglesplit")` | `{ description = "Toggle split" }` | hyprland.conf:321 | — |
| 39 | `SUPER + PRINT` | `hl.dsp.exec_cmd("noctalia msg screenshot-fullscreen")` | `{ description = "Full screenshot (ML4W Super+Print)" }` | hyprland.conf:322 | — |
| 40 | `SUPER + ALT + F` | `hl.dsp.exec_cmd("noctalia msg screenshot-fullscreen")` | `{ description = "Instant full screenshot (ML4W)" }` | hyprland.conf:323 | — |
| 41 | `SUPER + ALT + S` | `hl.dsp.exec_cmd("noctalia msg screenshot-region")` | `{ description = "Region screenshot (ML4W)" }` | hyprland.conf:324 | — |
| 42 | `SUPER + CTRL + F` | `hl.dsp.exec_cmd("noctalia msg screenshot-window")` | `{ description = "Focused-window screenshot" }` | hyprland.conf:325 | NEW combo. |
| 43 | `SUPER + A` | `hl.dsp.exec_cmd("noctalia msg screenshot-annotate")` | `{ description = "Freeze and annotate screenshot" }` | hyprland.conf:326 | NEW combo. |
| 44 | `SUPER + ALT + A` | `hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/ocr-region.sh")` | `{ description = "Region OCR to clipboard (ML4W Super+Alt+A)" }` | hyprland.conf:327 | Resolves to `~/.local/bin/ocr-region.sh`; ML4W used `text-extractor.sh`. |
| 45 | `SUPER + SHIFT + T` | `hl.dsp.exec_cmd("hyprctl dispatch workspaceopt allfloat")` | `{ description = "Toggle float for all windows on workspace (ML4W)" }` | hyprland.conf:328 | — |
| 46 | `SUPER + ALT + T` | `function()<br>    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))<br>    hl.dispatch(hl.dsp.window.pin())<br>end` | `{ description = "Float + pin window (ML4W)" }` | hyprland.conf:329-332 | Identical body to ML4W default.lua:62. |
| 47 | `SUPER + G` | `hl.dsp.group.toggle()` | `{ description = "Toggle window group (ML4W)" }` | hyprland.conf:333 | — |
| 48 | `SUPER + K` | `hl.dsp.layout("swapsplit")` | `{ description = "Swap split (ML4W)" }` | hyprland.conf:334 | — |
| 49 | `SUPER + SHIFT + R` | `hl.dsp.exec_cmd("hyprctl reload")` | `{ description = "Reload Hyprland config (ML4W)" }` | hyprland.conf:335 | — |
| 50 | `SUPER + left` | `hl.dsp.focus({ direction = "left" })` | `{ description = "Focus left" }` | hyprland.conf:338 | — |
| 51 | `SUPER + right` | `hl.dsp.focus({ direction = "right" })` | `{ description = "Focus right" }` | hyprland.conf:339 | — |
| 52 | `SUPER + up` | `hl.dsp.focus({ direction = "up" })` | `{ description = "Focus up" }` | hyprland.conf:340 | — |
| 53 | `SUPER + down` | `hl.dsp.focus({ direction = "down" })` | `{ description = "Focus down" }` | hyprland.conf:341 | — |
| 54 | `SUPER + mouse:272` | `hl.dsp.window.drag()` | `{ mouse = true, description = "Move window" }` | hyprland.conf:342 | Mouse bind (left button). |
| 55 | `SUPER + mouse:273` | `hl.dsp.window.resize()` | `{ mouse = true, description = "Resize window" }` | hyprland.conf:343 | Mouse bind (right button). |
| 56 | `SUPER + SHIFT + right` | `hl.dsp.window.resize({ x = 100, y = 0, relative = true })` | `{ repeating = true, description = "Increase window width (ML4W)" }` | hyprland.conf:344 | — |
| 57 | `SUPER + SHIFT + left` | `hl.dsp.window.resize({ x = -100, y = 0, relative = true })` | `{ repeating = true, description = "Decrease window width (ML4W)" }` | hyprland.conf:345 | — |
| 58 | `SUPER + SHIFT + down` | `hl.dsp.window.resize({ x = 0, y = 100, relative = true })` | `{ repeating = true, description = "Increase window height (ML4W)" }` | hyprland.conf:346 | — |
| 59 | `SUPER + SHIFT + up` | `hl.dsp.window.resize({ x = 0, y = -100, relative = true })` | `{ repeating = true, description = "Decrease window height (ML4W)" }` | hyprland.conf:347 | — |
| 60 | `SUPER + ALT + left` | `hl.dsp.window.swap({ direction = "l" })` | `{ description = "Swap tiled window left (ML4W)" }` | hyprland.conf:348 | — |
| 61 | `SUPER + ALT + right` | `hl.dsp.window.swap({ direction = "r" })` | `{ description = "Swap tiled window right (ML4W)" }` | hyprland.conf:349 | — |
| 62 | `SUPER + ALT + up` | `hl.dsp.window.swap({ direction = "u" })` | `{ description = "Swap tiled window up (ML4W)" }` | hyprland.conf:350 | — |
| 63 | `SUPER + ALT + down` | `hl.dsp.window.swap({ direction = "d" })` | `{ description = "Swap tiled window down (ML4W)" }` | hyprland.conf:351 | — |
| 64 | `SUPER + 1` | `hl.dsp.focus({ workspace = i })` with `i = 1` | `{ description = "Workspace " .. i }` | hyprland.conf:356 (loop 354-358) | Workspace loop bind 1/20. `local key = i % 10` at line 355. |
| 65 | `SUPER + SHIFT + 1` | `hl.dsp.window.move({ workspace = i })` with `i = 1` | `{ description = "Move to workspace " .. i }` | hyprland.conf:357 (loop 354-358) | Workspace loop bind 2/20. |
| 66 | `SUPER + 2` | `hl.dsp.focus({ workspace = i })` with `i = 2` | `{ description = "Workspace " .. i }` | hyprland.conf:356 (loop 354-358) | Workspace loop bind 3/20. |
| 67 | `SUPER + SHIFT + 2` | `hl.dsp.window.move({ workspace = i })` with `i = 2` | `{ description = "Move to workspace " .. i }` | hyprland.conf:357 (loop 354-358) | Workspace loop bind 4/20. |
| 68 | `SUPER + 3` | `hl.dsp.focus({ workspace = i })` with `i = 3` | `{ description = "Workspace " .. i }` | hyprland.conf:356 (loop 354-358) | Workspace loop bind 5/20. |
| 69 | `SUPER + SHIFT + 3` | `hl.dsp.window.move({ workspace = i })` with `i = 3` | `{ description = "Move to workspace " .. i }` | hyprland.conf:357 (loop 354-358) | Workspace loop bind 6/20. |
| 70 | `SUPER + 4` | `hl.dsp.focus({ workspace = i })` with `i = 4` | `{ description = "Workspace " .. i }` | hyprland.conf:356 (loop 354-358) | Workspace loop bind 7/20. |
| 71 | `SUPER + SHIFT + 4` | `hl.dsp.window.move({ workspace = i })` with `i = 4` | `{ description = "Move to workspace " .. i }` | hyprland.conf:357 (loop 354-358) | Workspace loop bind 8/20. |
| 72 | `SUPER + 5` | `hl.dsp.focus({ workspace = i })` with `i = 5` | `{ description = "Workspace " .. i }` | hyprland.conf:356 (loop 354-358) | Workspace loop bind 9/20. |
| 73 | `SUPER + SHIFT + 5` | `hl.dsp.window.move({ workspace = i })` with `i = 5` | `{ description = "Move to workspace " .. i }` | hyprland.conf:357 (loop 354-358) | Workspace loop bind 10/20. |
| 74 | `SUPER + 6` | `hl.dsp.focus({ workspace = i })` with `i = 6` | `{ description = "Workspace " .. i }` | hyprland.conf:356 (loop 354-358) | Workspace loop bind 11/20. |
| 75 | `SUPER + SHIFT + 6` | `hl.dsp.window.move({ workspace = i })` with `i = 6` | `{ description = "Move to workspace " .. i }` | hyprland.conf:357 (loop 354-358) | Workspace loop bind 12/20. |
| 76 | `SUPER + 7` | `hl.dsp.focus({ workspace = i })` with `i = 7` | `{ description = "Workspace " .. i }` | hyprland.conf:356 (loop 354-358) | Workspace loop bind 13/20. |
| 77 | `SUPER + SHIFT + 7` | `hl.dsp.window.move({ workspace = i })` with `i = 7` | `{ description = "Move to workspace " .. i }` | hyprland.conf:357 (loop 354-358) | Workspace loop bind 14/20. |
| 78 | `SUPER + 8` | `hl.dsp.focus({ workspace = i })` with `i = 8` | `{ description = "Workspace " .. i }` | hyprland.conf:356 (loop 354-358) | Workspace loop bind 15/20. |
| 79 | `SUPER + SHIFT + 8` | `hl.dsp.window.move({ workspace = i })` with `i = 8` | `{ description = "Move to workspace " .. i }` | hyprland.conf:357 (loop 354-358) | Workspace loop bind 16/20. |
| 80 | `SUPER + 9` | `hl.dsp.focus({ workspace = i })` with `i = 9` | `{ description = "Workspace " .. i }` | hyprland.conf:356 (loop 354-358) | Workspace loop bind 17/20. |
| 81 | `SUPER + SHIFT + 9` | `hl.dsp.window.move({ workspace = i })` with `i = 9` | `{ description = "Move to workspace " .. i }` | hyprland.conf:357 (loop 354-358) | Workspace loop bind 18/20. |
| 82 | `SUPER + 0` | `hl.dsp.focus({ workspace = i })` with `i = 10` (`i % 10`) | `{ description = "Workspace " .. i }` | hyprland.conf:356 (loop 354-358) | Workspace loop bind 19/20 → workspace 10. |
| 83 | `SUPER + SHIFT + 0` | `hl.dsp.window.move({ workspace = i })` with `i = 10` (`i % 10`) | `{ description = "Move to workspace " .. i }` | hyprland.conf:357 (loop 354-358) | Workspace loop bind 20/20 → workspace 10. |
| 84 | `SUPER + S` | `hl.dsp.workspace.toggle_special("scratchpad")` | `{ description = "Toggle scratchpad (ML4W)" }` | hyprland.conf:361 | — |
| 85 | `SUPER + SHIFT + S` | `function()<br>    hl.dispatch(hl.dsp.window.move({ workspace = "special:scratchpad" }))<br>    hl.dispatch(hl.dsp.window.set_prop({ prop = "active_border_color", value = "rgba(f5c2e4ff)" }))<br>    hl.dispatch(hl.dsp.window.set_prop({ prop = "inactive_border_color", value = "rgba(45475aff)" }))<br>end` | `{ description = "Move window to special workspace with pink border marker" }` | hyprland.conf:362-366 | ML4W also floats first; Noctalia sets pink border props instead. |
| 86 | `SUPER + mouse_down` | `throttled_scroll(hl.dsp.focus({ workspace = "e+1" }))` (wrapper `hl.timer(function() scroll_locked = false end, { timeout = 200, type = "oneshot" })`) | `{ description = "Next workspace (ML4W)" }` | hyprland.conf:378 | Throttle helper at lines 369-377. |
| 87 | `SUPER + mouse_up` | `throttled_scroll(hl.dsp.focus({ workspace = "e-1" }))` (same wrapper) | `{ description = "Previous workspace (ML4W)" }` | hyprland.conf:379 | Throttle helper at lines 369-377. |
| 88 | `XF86AudioRaiseVolume` | `hl.dsp.exec_cmd("noctalia msg volume-up 5")` | `{ repeating = true }` | hyprland.conf:383 | No `locked`, no `description` on this bind (verbatim). |
| 89 | `XF86AudioLowerVolume` | `hl.dsp.exec_cmd("noctalia msg volume-down 5")` | `{ repeating = true }` | hyprland.conf:384 | — |
| 90 | `XF86AudioMute` | `hl.dsp.exec_cmd("noctalia msg volume-mute")` | `(no options table)` | hyprland.conf:385 | — |
| 91 | `XF86MonBrightnessUp` | `hl.dsp.exec_cmd("noctalia msg brightness-up 5%")` | `{ repeating = true }` | hyprland.conf:386 | — |
| 92 | `XF86MonBrightnessDown` | `hl.dsp.exec_cmd("noctalia msg brightness-down 5%")` | `{ repeating = true }` | hyprland.conf:387 | — |
| 93 | `XF86AudioMicMute` | `hl.dsp.exec_cmd("noctalia msg mic-mute")` | `{ locked = true, description = "Mute microphone with OSD" }` | hyprland.conf:388 | — |
| 94 | `XF86AudioNext` | `hl.dsp.exec_cmd("playerctl next")` | `{ locked = true, description = "Next track (ML4W)" }` | hyprland.conf:389 | — |
| 95 | `XF86AudioPrev` | `hl.dsp.exec_cmd("playerctl previous")` | `{ locked = true, description = "Previous track (ML4W)" }` | hyprland.conf:390 | — |
| 96 | `XF86AudioPlay` | `hl.dsp.exec_cmd("playerctl play-pause")` | `{ locked = true, description = "Play/pause (ML4W)" }` | hyprland.conf:391 | — |
| 97 | `XF86AudioPause` | `hl.dsp.exec_cmd("playerctl play-pause")` | `{ locked = true, description = "Pause (ML4W)" }` | hyprland.conf:392 | — |

Bind-related config (`hyprland.conf:66-70`): `binds = { allow_workspace_cycles = true, pass_mouse_when_bound = false, scroll_event_delay = 1 }`. Note `allow_workspace_cycles = true` is **only** in Noctalia (ML4W's `default.lua:129-134` omits it).

### 2.2 Gestures — 4 rows (ported from ML4W verbatim)

| # | Exact key combo | Exact command/dispatcher (verbatim) | All options verbatim | Source file:line | Notes |
|---:|---|---|---|---|---|
| 1 | Gesture: 3-finger vertical swipe | `action = "workspace"` | `fingers = 3`, `direction = "vertical"`, `action = "workspace"` | hyprland.conf:99 | Identical to ML4W gestures.lua:6-10. |
| 2 | Gesture: 3-finger horizontal swipe | `action = "scroll_move"`, `scale = 0.9` | `fingers = 3`, `direction = "horizontal"`, `action = "scroll_move"`, `scale = 0.9` | hyprland.conf:100 | Identical to ML4W gestures.lua:13-18. |
| 3 | Gesture: 4-finger pinch out | `hl.dispatch(hl.dsp.window.fullscreen({ action = "set" }))` | `fingers = 4`, `direction = "pinchout"` | hyprland.conf:101-103 | Identical to ML4W gestures.lua:21-23. |
| 4 | Gesture: 4-finger pinch in | `hl.dispatch(hl.dsp.window.fullscreen({ action = "unset" }))` | `fingers = 4`, `direction = "pinchin"` | hyprland.conf:104-106 | Identical to ML4W gestures.lua:26-28. |

### 2.3 Start-hook `hl.exec_cmd(...)` commands (separate subsection, 5 rows)

`hl.on("hyprland.start", function()` at hyprland.conf:273-281. These run at session start; none are keybinds.

| # | Trigger | Exact command (verbatim) | All options verbatim | Source file:line | Notes |
|---:|---|---|---|---|---|
| 1 | `hyprland.start` | `hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr-noctalia/isolate-ml4w.sh &")` | `(none)` | hyprland.conf:276 | Isolation wrapper; `NOCTALIA_SESSION=1` set by wrapper (comment at 274). |
| 2 | `hyprland.start` | `hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE")` | `(none)` | hyprland.conf:277 | — |
| 3 | `hyprland.start` | `hl.exec_cmd("systemctl --user start hyprpolkitagent.service")` | `(none)` | hyprland.conf:278 | — |
| 4 | `hyprland.start` | `hl.exec_cmd("hypridle -c " .. os.getenv("HOME") .. "/.config/hypr-noctalia/hypridle.conf")` | `(none)` | hyprland.conf:279 | hypridle has no lock/lock-before-suspend command (comment at 272). |
| 5 | `hyprland.start` | `hl.exec_cmd("noctalia")` | `(none)` | hyprland.conf:280 | — |

**Noctalia totals:** 97 active keybinds + 4 gestures + 5 start-hook execs. Breakdown of the 97: 2 hyprglass + 30 application/system + 17 window management (source lines 316-335 span 20 lines; the `SUPER+ALT+T` function bind occupies 329-332) + 14 focus/move/resize + 20 workspace loop + 2 scratchpad + 2 scroll + 10 media.

---

## 3. Cross-comparison table

Statuses:
- **SAME** — combo on both sides, functionally identical command/dispatcher.
- **REMAP** — combo on both sides, same general purpose, different implementation/target.
- **REPURPOSED** — combo on both sides, materially different purpose.
- **LOST** — ML4W-only combo (including commented/unbound-only entries).
- **NEW** — Noctalia-only combo.

Case variants (`RETURN`/`Return`, `Tab`/`TAB`) are treated as the same physical combo. Gestures appear as the final four rows.

| # | Key combo | ML4W present? | Noctalia present? | Status | One-line note |
|---:|---|---|---|---|---|
| 1 | `SUPER + RETURN` | Yes (default.lua:5 terminal.sh; final custom.lua:23 `kitty`) | Yes (hyprland.conf:284 `kitty`) | SAME | Final effective ML4W is `kitty` after custom override; raw default was `terminal.sh`. |
| 2 | `SUPER + SHIFT + RETURN` | Yes (custom.lua:27 / GUI:29 `wezterm`) | Yes (hyprland.conf:285 `wezterm`) | SAME | Both sides `wezterm`; ML4W rebinds it twice plus unbinds. |
| 3 | `SUPER + B` | Yes `browser.sh` | Yes `brave` | REMAP | Browser launcher script → explicit Brave binary. |
| 4 | `SUPER + E` | Yes `filemanager` | Yes `nautilus` | REMAP | File-manager script → explicit Nautilus. |
| 5 | `SUPER + CTRL + E` | Yes `emojipicker.sh` | Yes `panel-open launcher /emo` | REMAP | Script → Noctalia launcher emoji panel. |
| 6 | `SUPER + C` | Yes `calculator.sh` | No | LOST | No Noctalia equivalent bound. |
| 7 | `SUPER + D` | No (only SHIFT/CTRL/ALT+D variants exist) | Yes `panel-toggle launcher` | NEW | Bare Super+D is new in Noctalia. |
| 8 | `SUPER + SPACE` | Yes `qs ipc call statusbar focus` | Yes `panel-toggle launcher` | REPURPOSED | Statusbar focus → launcher. |
| 9 | `SUPER + PRINT` | Yes `screenshot.sh` | Yes `screenshot-fullscreen` | REMAP | Screenshot script → Noctalia IPC. |
| 10 | `SUPER + ALT + F` | Yes `screenshot.sh --instant` | Yes `screenshot-fullscreen` | REMAP | Instant screenshot script → Noctalia full-screen shot. |
| 11 | `SUPER + ALT + S` | Yes `screenshot.sh --instant-area` | Yes `screenshot-region` | REMAP | Area screenshot script → Noctalia region shot. |
| 12 | `SUPER + CTRL + F` | No | Yes `screenshot-window` | NEW | No ML4W bind. |
| 13 | `SUPER + A` | No | Yes `screenshot-annotate` | NEW | No ML4W bind. |
| 14 | `SUPER + ALT + A` | Yes `text-extractor.sh` | Yes `~/.local/bin/ocr-region.sh` | REMAP | OCR script path changed; same purpose. |
| 15 | `SUPER + V` | Yes `ml4w-cliphist` | Yes `panel-toggle clipboard` | REMAP | Clipboard manager → Noctalia clipboard panel. |
| 16 | `SUPER + CTRL + K` | Yes `keybindings.sh` | No | LOST | Keybindings viewer dropped. |
| 17 | `SUPER + CTRL + P` | Yes `ml4w-powermenu toggle` | Yes `panel-toggle session` | REMAP | Power menu → Noctalia session panel. |
| 18 | `SUPER + CTRL + RETURN` | Yes `ml4w-launcher` | Yes `panel-toggle launcher` | REMAP | ML4W launcher → Noctalia launcher. |
| 19 | `SUPER + CTRL + L` | Yes `ml4w-power -l` | Yes `session lock` | REMAP | ML4W power-lock script → Noctalia lock IPC. |
| 20 | `SUPER + L` | No | Yes `session lock` | NEW | ML4W has only Super+Ctrl+L. |
| 21 | `SUPER + Tab` | Yes `qs ... overview toggle` | Yes `window-switcher` | REMAP | Quickshell overview → Noctalia window switcher. |
| 22 | `ALT + Tab` | Yes `qs ... app-switcher next` | Yes `window-switcher hold` | REMAP | App switcher → Noctalia switcher (hold). |
| 23 | `ALT + SHIFT + Tab` | Yes `qs ... app-switcher prev` | Yes `window-switcher hold reverse` | REMAP | Reverse app switcher → Noctalia reverse (hold). |
| 24 | `SUPER + SHIFT + TAB` | No | Yes `window-switcher reverse` | NEW | No ML4W bind. |
| 25 | `CTRL + ALT + T` | Yes `~/.config/ml4w/themes/themes.sh` | No | LOST | Theme switcher dropped. |
| 26 | `SUPER + CTRL + T` | Yes `~/.config/waybar/themeswitcher.sh` | No | LOST | Waybar theme switcher dropped. |
| 27 | `SUPER + SHIFT + M` | Yes `ml4w-toggle-theme` | Yes `theme-mode-toggle` | REMAP | Light/dark toggle → Noctalia IPC. |
| 28 | `SUPER + ALT + G` | Yes `gamemode.sh` | Yes `panel-open launcher /glass` | REPURPOSED | Game mode → HyprGlass menu. |
| 29 | `SUPER + SHIFT + G` | ML4W commented-out only (default.lua:75 `group.active("f")`) | Yes `glass_on` toggle (hyprland.conf:264-267) | NEW | ML4W never bound it; Noctalia toggles HyprGlass. |
| 30 | `SUPER + CTRL + S` | Yes `qs ipc call sidebar toggle` | No | LOST | ML4W sidebar widget dropped. |
| 31 | `SUPER + CTRL + C` | Yes `qs ipc call calendar toggle` | No | LOST | ML4W calendar widget dropped. |
| 32 | `SUPER + SHIFT + D` | Yes `ml4w-reload-dock` | No | LOST | Dock reload dropped. |
| 33 | `SUPER + CTRL + D` | Yes `ml4w-toggle-dock` | Yes `dock-toggle` | REMAP | Dock toggle script → Noctalia IPC. |
| 34 | `SUPER + ALT + D` | Yes `ml4w-toggle-dock-autohide` | No | LOST | Dock autohide toggle dropped. |
| 35 | `SUPER + SHIFT + B` | Yes `ml4w-reload-statusbar` | No | LOST | Status-bar reload dropped. |
| 36 | `SUPER + CTRL + B` | Yes `ml4w-toggle-statusbar` | Yes `bar-toggle` | REMAP | Status-bar toggle script → Noctalia IPC. |
| 37 | `SUPER + ALT + B` | Yes `ml4w-toggle-statusbar-autohide` | No | LOST | Status-bar autohide toggle dropped. |
| 38 | `SUPER + SHIFT + R` | Yes `loadconfig.sh` | Yes `hyprctl reload` | REMAP | Reload script → direct `hyprctl reload`. |
| 39 | `SUPER + SHIFT + A` | Yes `toggle-animations.sh` | No | LOST | Animation toggle dropped. |
| 40 | `SUPER + W` | Yes `ml4w-wallpaper-app --carousel` | Yes `wallpaper-next` | REMAP | Carousel → next wallpaper IPC. |
| 41 | `SUPER + SHIFT + W` | Yes `ml4w-wallpaper-app --random` | Yes `wallpaper-random` | REMAP | Random-wallpaper script → Noctalia IPC. |
| 42 | `SUPER + CTRL + W` | Yes `ml4w-wallpaper-app` | Yes `panel-toggle wallpaper` | REMAP | Wallpaper selector → Noctalia wallpaper panel. |
| 43 | `SUPER + ALT + W` | Yes `ml4w-wallpaper-automation` | No | LOST | Wallpaper automation dropped. |
| 44 | `SUPER + SHIFT + H` | Yes `ml4w-toggle-hyprsunset` | Yes `nightlight-force-toggle` | REMAP | Hyprsunset script → Noctalia night-light IPC. |
| 45 | `SUPER + H` | No | Yes `caffeine-toggle` | NEW | Idle inhibitor; no ML4W bind. |
| 46 | `SUPER + SHIFT + C` | No | Yes `panel-toggle control-center` | NEW | Control center; no ML4W bind. |
| 47 | `SUPER + SHIFT + N` | No | Yes `notification-dnd-toggle` | NEW | Do-not-disturb toggle; no ML4W bind. |
| 48 | `SUPER + F4` | Yes `brightness.sh up` (custom.lua:12) | Yes `brightness-up 5%` | REMAP | Script → Noctalia IPC. |
| 49 | `SUPER + F3` | Yes `brightness.sh down` (custom.lua:15) | Yes `brightness-down 5%` | REMAP | Script → Noctalia IPC. |
| 50 | `SUPER + F2` | Yes `brightness.sh down` (custom.lua:18) | Yes `brightness-down 5%` | REMAP | Script → Noctalia IPC (duplicate F3 behaviour on both sides). |
| 51 | `SUPER + CTRL + H` | Yes `display-mode.sh` (GUI:25) | Yes `panel-open launcher /eye` | REPURPOSED | Display-mode menu → eye-care menu. |
| 52 | `SUPER + ALT + RETURN` | ML4W unbind-only (custom.lua:29-30, no rebind) | No | LOST | Explicitly unbound in ML4W; absent in Noctalia. |
| 53 | `SUPER + Q` | Yes `killactive.sh` (default.lua:55; commented `window.close()` at 56) | Yes `window.close()` | REMAP | Script → native dispatcher; matches ML4W's commented alternative. |
| 54 | `SUPER + SHIFT + Q` | Yes `hyprctl activewindow ... xargs kill` | Yes `window.kill()` | REMAP | Shell kill pipeline → native `window.kill()`. |
| 55 | `SUPER + F` | Yes `fullscreen({mode="fullscreen",action="toggle"})` | Yes identical | SAME | Verbatim dispatcher match. |
| 56 | `SUPER + M` | Yes `fullscreen({mode="maximized",action="toggle"})` | Yes identical | SAME | Verbatim dispatcher match. |
| 57 | `SUPER + T` | Yes `float({action="toggle"})` | Yes identical | SAME | Verbatim dispatcher match. |
| 58 | `SUPER + SHIFT + T` | Yes `ml4w-toggle-allfloat` | Yes `hyprctl dispatch workspaceopt allfloat` | REMAP | Script → direct hyprctl dispatch. |
| 59 | `SUPER + ALT + T` | Yes float-toggle + pin function | Yes identical function body | SAME | Both `float({action="toggle"})` then `window.pin()`. |
| 60 | `SUPER + J` | Yes `layout("togglesplit")` | Yes identical | SAME | — |
| 61 | `SUPER + K` | Yes `layout("swapsplit")` | Yes identical | SAME | — |
| 62 | `SUPER + G` | Yes `group.toggle()` | Yes identical | SAME | — |
| 63 | `SUPER + left` | Yes `focus({direction="left"})` | Yes identical | SAME | — |
| 64 | `SUPER + right` | Yes `focus({direction="right"})` | Yes identical | SAME | — |
| 65 | `SUPER + up` | Yes `focus({direction="up"})` | Yes identical | SAME | — |
| 66 | `SUPER + down` | Yes `focus({direction="down"})` | Yes identical | SAME | — |
| 67 | `SUPER + mouse:272` | Yes `window.drag()` (`mouse=true`) | Yes identical | SAME | Description differs ("Move window with the mouse" vs "Move window"). |
| 68 | `SUPER + mouse:273` | Yes `window.resize()` (`mouse=true`) | Yes identical | SAME | Description differs only. |
| 69 | `SUPER + SHIFT + right` | Yes resize x=100 relative, repeating | Yes identical | SAME | Description differs only. |
| 70 | `SUPER + SHIFT + left` | Yes resize x=-100 relative, repeating | Yes identical | SAME | Description differs only. |
| 71 | `SUPER + SHIFT + down` | Yes resize y=100 relative, repeating | Yes identical | SAME | Description differs only. |
| 72 | `SUPER + SHIFT + up` | Yes resize y=-100 relative, repeating | Yes identical | SAME | Description differs only. |
| 73 | `SUPER + ALT + left` | Yes `swap({direction="l"})` | Yes identical | SAME | — |
| 74 | `SUPER + ALT + right` | Yes `swap({direction="r"})` | Yes identical | SAME | — |
| 75 | `SUPER + ALT + up` | Yes `swap({direction="u"})` | Yes identical | SAME | — |
| 76 | `SUPER + ALT + down` | Yes `swap({direction="d"})` | Yes identical | SAME | — |
| 77 | `SUPER + mouse_down` | Yes throttled `focus({workspace="e+1"})` (200 ms) | Yes throttled identical | SAME | Both throttle; ML4W has a commented non-throttled form at 126. |
| 78 | `SUPER + mouse_up` | Yes throttled `focus({workspace="e-1"})` (200 ms) | Yes throttled identical | SAME | Both throttle; ML4W commented form at 127. |
| 79 | `SUPER + 1` | Yes `focus({workspace=1})` | Yes identical | SAME | Workspace loop 1/20 (AZERTY ML4W alias `ampersand`). |
| 80 | `SUPER + 2` | Yes `focus({workspace=2})` | Yes identical | SAME | Workspace loop 3/20 (`eacute`). |
| 81 | `SUPER + 3` | Yes `focus({workspace=3})` | Yes identical | SAME | Workspace loop 5/20 (`quotedbl`). |
| 82 | `SUPER + 4` | Yes `focus({workspace=4})` | Yes identical | SAME | Workspace loop 7/20 (`apostrophe`). |
| 83 | `SUPER + 5` | Yes `focus({workspace=5})` | Yes identical | SAME | Workspace loop 9/20 (`parenleft`). |
| 84 | `SUPER + 6` | Yes `focus({workspace=6})` | Yes identical | SAME | Workspace loop 11/20 (`minus`/`section`). |
| 85 | `SUPER + 7` | Yes `focus({workspace=7})` | Yes identical | SAME | Workspace loop 13/20 (`egrave`). |
| 86 | `SUPER + 8` | Yes `focus({workspace=8})` | Yes identical | SAME | Workspace loop 15/20 (`underscore`/`exclam`). |
| 87 | `SUPER + 9` | Yes `focus({workspace=9})` | Yes identical | SAME | Workspace loop 17/20 (`ccedilla`). |
| 88 | `SUPER + 0` | Yes `focus({workspace=10})` | Yes identical | SAME | Workspace loop 19/20 (`agrave`). |
| 89 | `SUPER + SHIFT + 1` | Yes `window.move({workspace=1})` | Yes identical | SAME | Workspace loop 2/20. |
| 90 | `SUPER + SHIFT + 2` | Yes `window.move({workspace=2})` | Yes identical | SAME | Workspace loop 4/20. |
| 91 | `SUPER + SHIFT + 3` | Yes `window.move({workspace=3})` | Yes identical | SAME | Workspace loop 6/20. |
| 92 | `SUPER + SHIFT + 4` | Yes `window.move({workspace=4})` | Yes identical | SAME | Workspace loop 8/20. |
| 93 | `SUPER + SHIFT + 5` | Yes `window.move({workspace=5})` | Yes identical | SAME | Workspace loop 10/20. |
| 94 | `SUPER + SHIFT + 6` | Yes `window.move({workspace=6})` | Yes identical | SAME | Workspace loop 12/20. |
| 95 | `SUPER + SHIFT + 7` | Yes `window.move({workspace=7})` | Yes identical | SAME | Workspace loop 14/20. |
| 96 | `SUPER + SHIFT + 8` | Yes `window.move({workspace=8})` | Yes identical | SAME | Workspace loop 16/20. |
| 97 | `SUPER + SHIFT + 9` | Yes `window.move({workspace=9})` | Yes identical | SAME | Workspace loop 18/20. |
| 98 | `SUPER + SHIFT + 0` | Yes `window.move({workspace=10})` | Yes identical | SAME | Workspace loop 20/20. |
| 99 | `SUPER + S` | Yes `workspace.toggle_special("scratchpad")` | Yes identical | SAME | — |
| 100 | `SUPER + SHIFT + S` | Yes float-toggle + move to special:scratchpad | Yes move to special + pink border props | REMAP | Noctalia drops the float toggle and adds border colour set_prop calls. |
| 101 | `XF86AudioRaiseVolume` | Yes `wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+` (`locked`, `repeating`) | Yes `noctalia msg volume-up 5` (`repeating` only) | REMAP | Volume backend script → Noctalia IPC; `locked` dropped. |
| 102 | `XF86AudioLowerVolume` | Yes `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-` (`locked`, `repeating`) | Yes `noctalia msg volume-down 5` (`repeating` only) | REMAP | Volume backend script → Noctalia IPC; `locked` dropped. |
| 103 | `XF86AudioMute` | Yes `wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle` (`locked`, `repeating`) | Yes `noctalia msg volume-mute` (no options) | REMAP | Mute script → Noctalia IPC; `locked`/`repeating` dropped. |
| 104 | `XF86AudioMicMute` | Yes `wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle` (`locked`, `repeating`) | Yes `noctalia msg mic-mute` (`locked` only) | REMAP | Mic-mute script → Noctalia IPC; `repeating` dropped. |
| 105 | `XF86MonBrightnessUp` | Yes final `brightness.sh up` (custom.lua:6; raw default `brightnessctl -e4 -n2 set 5%+`) | Yes `noctalia msg brightness-up 5%` (`repeating`) | REMAP | Brightness script → Noctalia IPC; `locked` dropped. |
| 106 | `XF86MonBrightnessDown` | Yes final `brightness.sh down` (custom.lua:9; raw default `brightnessctl -e4 -n2 set 5%-`) | Yes `noctalia msg brightness-down 5%` (`repeating`) | REMAP | Brightness script → Noctalia IPC; `locked` dropped. |
| 107 | `XF86AudioNext` | Yes `playerctl next` (`locked`) | Yes identical (`locked`, description differs) | SAME | Same playerctl command and `locked`. |
| 108 | `XF86AudioPrev` | Yes `playerctl previous` (`locked`) | Yes identical (`locked`, description differs) | SAME | Same playerctl command and `locked`. |
| 109 | `XF86AudioPlay` | Yes `playerctl play-pause` (`locked`) | Yes identical (`locked`, description differs) | SAME | Same playerctl command and `locked`. |
| 110 | `XF86AudioPause` | Yes `playerctl play-pause` (`locked`) | Yes identical (`locked`, description differs) | SAME | Same playerctl command and `locked`. |
| 111 | Gesture: 3-finger vertical (`workspace`) | Yes gestures.lua:6-10 | Yes hyprland.conf:99 | SAME | Verbatim port. |
| 112 | Gesture: 3-finger horizontal (`scroll_move`, scale 0.9) | Yes gestures.lua:13-18 | Yes hyprland.conf:100 | SAME | Verbatim port. |
| 113 | Gesture: 4-finger pinch out (fullscreen set) | Yes gestures.lua:21-23 | Yes hyprland.conf:101-103 | SAME | Verbatim port. |
| 114 | Gesture: 4-finger pinch in (fullscreen unset) | Yes gestures.lua:26-28 | Yes hyprland.conf:104-106 | SAME | Verbatim port. |

**Cross-comparison totals:** 114 rows = 54 SAME + 35 REMAP + 3 REPURPOSED + 13 LOST + 9 NEW. No combo from either table is omitted; commented-out and unbind-only ML4W combos are included and flagged in the ML4W-present column.


---

<a id="rules"></a>
# Rules & Workspace sheet — ML4W backup vs live Noctalia

Research-only extraction. Scope: everything that is NOT a keybind and NOT a simple parameter change, per the 12 requested topics.

**Path legend**
- `B/` = `/home/sahil/mydotfiles/backups-noctalia-2026-11-22/hypr/`
- `N/` = `/home/sahil/mydotfiles/.config/hypr-noctalia/`
- `C/` = `/home/sahil/mydotfiles/.config/noctalia/config.toml`

**Active ML4W variants** (from selector files): animation=`animations-fast.lua` (`B/conf/animation.lua:1`), decoration=`default.lua` (`B/conf/decoration.lua:1`), window=`glass.lua` (`B/conf/window.lua:1`), layout=`laptop.lua` (`B/conf/layout.lua:1`), monitor=`1920x1080.lua` (`B/conf/monitor.lua:1`) + top-level generated `B/monitors.lua`, workspace=`default.lua` (empty), windowrule=`default.lua` (empty), environment=`default.lua` (empty), keybindings=`default.lua`, hyprmod=`hyprland-gui.lua` (`B/hyprmod/active_profile:1`). Non-active profiles are listed as DROPPED available profiles, not as live values. All ML4W files load through `B/hyprland.lua:9-48`.

Verdict key: PORTED = same value/behavior on both sides; DROPPED = existed in ML4W (live or as profile) and absent in Noctalia; NEW = Noctalia-only; CHANGED = both present but different value/implementation.

---

## 1. Workspace definition & behavior

| Topic | ML4W exact value/implementation (file:line) | Noctalia exact value/implementation (file:line) | Verdict |
|---|---|---|---|
| Named workspaces | None: no `name:`/`workspace=` named definitions anywhere; `B/conf/workspaces/default.lua` is 0 lines (selector `B/conf/workspace.lua:1-2`) | None: numeric only, no named workspaces | PORTED (both none) |
| Numbered workspaces 1-10 | Loop `for i=1,10`, key `ws_keys and ws_keys[i] or (i%10)`; AZERTY detection maps fr/be keysyms (`ampersand,eacute,quotedbl,apostrophe,parenleft,minus/ section,egrave,underscore,ccedilla,agrave`) from `B/conf/keybindings/default.lua:14-52` | Loop `for i=1,10`, key `i % 10`; no AZERTY detection (`N/hyprland.conf:353-358`) | CHANGED (AZERTY keysym mapping dropped) |
| `workspace_rule` / per-monitor split | Available profile `B/conf/monitors/workspace-split.lua:6-16`: `map_workspaces(1,5,"DP-1")`, `map_workspaces(6,10,"HDMI-A-1")` via `hl.workspace_rule({workspace=tostring(i), monitor=name})`; profile NOT active | No `hl.workspace_rule` anywhere in `N/` | DROPPED |
| Special workspace / scratchpad name | `special:scratchpad`; `hl.dsp.workspace.toggle_special("scratchpad")` (`B/conf/keybindings/default.lua:119-123`) | `special:scratchpad`; `hl.dsp.workspace.toggle_special("scratchpad")` (`N/hyprland.conf:360-366`) | PORTED |
| Scratchpad window preparation | Move + `hl.dsp.window.float({action="toggle"})` then move to `special:scratchpad` (`B/conf/keybindings/default.lua:120-123`); dedicated drop-down terminal `B/scripts/toggle-scratchpad.sh:5-26` (`CLASS="dev-scratchpad"`, `kitty --class ... -e tmux new-session -A -s scratch`, `movetoworkspacesilent "special:scratchpad,pid:$pid"`) | Move + `set_prop active_border_color=rgba(f5c2e4ff)`, `inactive_border_color=rgba(45475aff)` (`N/hyprland.conf:362-366`); no drop-down terminal script | CHANGED (pink border marker NEW; terminal script DROPPED) |
| Special-workspace border rule | None | `name="special-workspace-color"`, `match={workspace="special:scratchpad"}`, `border_color="rgb(f5c2e4) rgb(45475a)"` (`N/hyprland.conf:132-136`) | NEW |
| Workspace cycling `e+1`/`e-1` | `throttled_scroll` with `scroll_locked` flag, `hl.timer(..., {timeout=200, type="oneshot"})` (`B/conf/keybindings/default.lua:136-166`) | Identical `scroll_locked` + 200ms oneshot timer (`N/hyprland.conf:368-379`) | PORTED |
| `binds.allow_workspace_cycles` | `true` (`B/conf/layouts/default.lua:17`, active `B/conf/layouts/laptop.lua:16`) | `true` (`N/hyprland.conf:67`) | PORTED |
| `binds.workspace_back_and_forth` | `false` explicit (`B/conf/layouts/default.lua:16`, `B/conf/layouts/laptop.lua:15`) | Not set (Hyprland default applies) | DROPPED (explicit `false`; effective behavior unchanged) |
| `binds.pass_mouse_when_bound` | `false` (`B/conf/layouts/default.lua:18`, `B/conf/layouts/laptop.lua:17`, `B/conf/keybindings/default.lua:131`) | `false` (`N/hyprland.conf:68`) | PORTED |
| `binds.scroll_event_delay` | `1` (`B/conf/keybindings/default.lua:132`) | `1` (`N/hyprland.conf:69`) | PORTED |
| `misc.initial_workspace_tracking` | `1` (`B/conf/misc.lua:6`) | Not set | DROPPED |
| `misc.on_focus_under_fullscreen` | `1` (`B/conf/misc.lua:7`) | Not set | DROPPED |
| Window overview / tabs | `qs -p ~/.local/share/quickshell-overview ipc call overview toggle`; app switcher `qs -p ~/.local/share/hypr-app-switcher ipc call app-switcher next/prev` (`B/conf/keybindings/default.lua:111,115-116`) | `noctalia msg window-switcher` / `... reverse` / `... hold` / `... hold reverse` (`N/hyprland.conf:295-298`); `C:165-173`: `style="icons"`, `mru=true`, `show_caption/show_count/show_app_icon=true`, `show_all_outputs=true`, `current_workspace_only=false`, `colorize_icons=false` | CHANGED (shell-owned overview replaced; Quickshell panels dropped) |
| Workspace alerts / bar indicators | No workspace-alert keys in ML4W Hyprland config; status bar owned by waybar/Quickshell (`B/conf/autostart.lua:29`) | `C:47` `show_on_workspace_switch=true`; `C:122-123` dead-zone `scroll_up="workspace-switch prev"`, `scroll_down="workspace-switch next"`; `C:319-332` `[widget.workspaces]`: `change_color_on_hover=true`, `hide_when_empty=false`, `pill_scale=0.85`, `inactive_pill_size=1.0`, `active_pill_size=2.4`, `urgent_color="error"`, `empty_color="outline_variant"`, `occupied_color="secondary"`, `focused_color="primary"`, `show_icons=false`, `show_labels=false`, `style="focus_hint"`, `type="workspaces"` | NEW |
| All-float workspace | `~/.config/ml4w/scripts/ml4w-toggle-allfloat` (`B/conf/keybindings/default.lua:61`) | `hyprctl dispatch workspaceopt allfloat` (`N/hyprland.conf:328`) | CHANGED |
| Group behavior (workspace-local) | `hl.dsp.group.toggle()` bound; `group.active("f")` commented out; no `group:` config keys (`B/conf/keybindings/default.lua:74-75`) | `hl.dsp.group.toggle()` bound; no group config keys (`N/hyprland.conf:333`) | PORTED (next-group-window comment DROPPED) |

---

## 2. Window rules (every rule on each side)

| Topic | ML4W exact value/implementation (file:line) | Noctalia exact value/implementation (file:line) | Verdict |
|---|---|---|---|
| `zen-opacity` | `match={class="^(zen)$"}`, `opacity="1.0 1.0"` (`B/custom.lua:33-37`) | `name="zen-opacity"`, `match={class="^(zen)$"}`, `opacity="1.0 1.0"` (`N/hyprland.conf:109-113`) | PORTED |
| `pavucontrol` | `match={class=".*org.pulseaudio.pavucontrol.*"}`, `float=true`, `center=true`, `size="700 600"` (`B/conf/ml4w.lua:19-25`) | same values, `name="pavucontrol"` (`N/hyprland.conf:114-120`) | PORTED |
| `ml4w-welcome-app` | `match={title="ML4W Welcome"}`, float, center, pin, `size="700 640"` (`B/conf/ml4w.lua:28-35`) | absent | DROPPED |
| `ml4w-dock-settings` | `match={title="ML4W Dock Settings"}`, float, center, pin, `size="480 300"` (`B/conf/ml4w.lua:38-45`) | absent | DROPPED |
| `ml4w-settings-app` | `match={title="ML4W Dotfiles Settings"}`, float, center, pin, `size="900 600"` (`B/conf/ml4w.lua:48-55`) | absent | DROPPED |
| `newelle` | `match={class="io.github.qwersyk.Newelle"}`, float, center, pin, `size="1000 700"` (`B/conf/ml4w.lua:58-65`) | absent | DROPPED |
| `blueman-manager` | `match={class="blueman-manager"}`, float, center, `size="800 600"` (`B/conf/ml4w.lua:68-74`) | absent | DROPPED |
| `nwg-look` | `match={class="nwg-look"}`, float, center, `size="700 600"` (`B/conf/ml4w.lua:77-83`) | absent | DROPPED |
| `nwg-displays` | `match={class="nwg-displays"}`, float, center, `size="900 600"` (`B/conf/ml4w.lua:86-92`) | absent | DROPPED |
| `missioncenter` | `match={class="io.missioncenter.MissionCenter"}`, float, center, pin, `size="900 600"` (`B/conf/ml4w.lua:95-102`) | absent | DROPPED |
| `gnome-calculator` | `match={class="org.gnome.Calculator"}`, float, center, `size="700 600"` (`B/conf/ml4w.lua:105-111`) | absent | DROPPED |
| `hyprland-share-picker` | `match={class="hyprland-share-picker"}`, float, pin, center, `size="600 400"` (`B/conf/ml4w.lua:114-121`) | absent (screen-share picker crash suspect; `QT_QPA_PLATFORMTHEME` disabled, `N/hyprland.conf:5-6,10`) | DROPPED |
| `xdg-desktop-portal-gtk` | `match={class="xdg-desktop-portal-gtk"}`, float, **`center=false`**, `size="800 600"` (`B/conf/ml4w.lua:124-130`) | `name="gtk-file-dialog"`, same class, float, **`center=true`**, `size="800 600"` (`N/hyprland.conf:137-143`) | CHANGED (center flipped) |
| `nm-connection-editor` | `match={class="nm-connection-editor"}`, float, center, `size="800 700"` (`B/conf/ml4w.lua:133-139`) | same (`N/hyprland.conf:144-150`) | PORTED |
| `io.github.bluemancz.hyprmod` | `match={class="io.github.bluemancz.hyprmod"}`, float, center, `size="1000 700"` (`B/conf/ml4w.lua:142-148`) | absent | DROPPED |
| `dotfiles-floating` | `match={class="dotfiles-floating"}`, float, center, `size="1000 700"` (`B/conf/ml4w.lua:151-157`) | same (`N/hyprland.conf:151-157`) | PORTED |
| `ml4w-window-mode-floating` | `window_mode_rule = hl.window_rule({name="ml4w-window-mode-floating", match={class=".*"}, float=true})`; runtime toggle `set_window_mode(mode)` via `rule:set_enabled(mode=="floating")`; reads `~/.config/ml4w/settings/window-mode` (`B/conf/ml4w.lua:159-176`) | absent | DROPPED |
| `Picture-in-Picture` | `match={title=[[^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture)(.*)$]]}`, float, pin, `focus_on_activate=false`, `no_initial_focus=true`, `suppress_event="activate"` (`B/conf/ml4w.lua:179-189`) | identical values (`N/hyprland.conf:121-131`) | PORTED |
| `xwaylandvideobridge` | `match={class="^(xwaylandvideobridge)$"}`, `opacity="0.0 override 0.0 override"`, `no_anim=true`, `no_initial_focus=true`, `max_size="1 1"`, `no_blur=true`, `float=true` (`B/conf/ml4w.lua:192-201`) | absent | DROPPED |
| `special-workspace-color` | absent | `name="special-workspace-color"`, `match={workspace="special:scratchpad"}`, `border_color="rgb(f5c2e4) rgb(45475a)"` (`N/hyprland.conf:132-136`) | NEW |
| `glass-shell-only` | absent | `name="glass-shell-only"`, `match={class=".*"}`, `tag="+hyprglass_disabled"` (`N/hyprland.conf:158-162`) | NEW |
| `B/conf/windowrules/default.lua` | 0 lines (selector `B/conf/windowrule.lua:1-2`): no rules from this variant on either ML4W or Noctalia | n/a | PORTED (both none) |

---

## 3. Layer rules

| Topic | ML4W exact value/implementation (file:line) | Noctalia exact value/implementation (file:line) | Verdict |
|---|---|---|---|
| Power menu layer rule | `hl.layer_rule({match={namespace="ml4w-powermenu"}, no_anim=true})` (`B/conf/ml4w.lua:204`) | absent | DROPPED |
| Waybar blur layer rule (profiles) | `hl.layer_rule({match={namespace="waybar"}, blur=true})` in `B/conf/decorations/blur.lua:32`, `rounding-all-blur.lua:31`, `rounding-all-blur-no-shadows.lua:31` (all inactive profiles) | absent | DROPPED |
| Noctalia bar no-anim layer rule | absent | `name="noctalia-bar-no-anim"`, `match={namespace="^noctalia-bar-.+$"}`, `no_anim=true` (`N/hyprland.conf:164-168`) | NEW |
| HyprGlass layer registrations | absent (no plugin) | `hg.layer("noctalia-bar-main",{preset="liquid",mask_mode="auto"})`; `hg.layer("noctalia-dock",{preset="liquid",mask_mode="auto",mask_feather=0.45,popups={enabled=true,preset="liquid"}})`; `hg.layer("noctalia-panel",{preset="liquid",mask_mode="contour",mask_threshold=0.15})`; `hg.layer("noctalia-attached-panel",{preset="liquid",mask_mode="contour",mask_threshold=0.15})`; `hg.layer("noctalia-notification",{preset="liquid",mask_mode="contour",mask_threshold=0.15})`; `hg.layer("noctalia-osd",{preset="liquid"})`; `hg.layer("noctalia-window-switcher",{preset="liquid"})` (`N/hyprland.conf:253-259`) | NEW |

---

## 4. Gestures (touchpad/mouse) and their actions

| Topic | ML4W exact value/implementation (file:line) | Noctalia exact value/implementation (file:line) | Verdict |
|---|---|---|---|
| 3-finger vertical | `hl.gesture({fingers=3, direction="vertical", action="workspace"})` (`B/gestures.lua:5-10`) | identical (`N/hyprland.conf:99`) | PORTED |
| 3-finger horizontal | `hl.gesture({fingers=3, direction="horizontal", action="scroll_move", scale=0.9})` (`B/gestures.lua:12-18`) | identical (`N/hyprland.conf:100`) | PORTED |
| 4-finger pinchout | `hl.dispatch(hl.dsp.window.fullscreen({action="set"}))` (`B/gestures.lua:20-23`) | identical (`N/hyprland.conf:101-103`) | PORTED |
| 4-finger pinchin | `hl.dispatch(hl.dsp.window.fullscreen({action="unset"}))` (`B/gestures.lua:25-28`) | identical (`N/hyprland.conf:104-106`) | PORTED |
| Touchpad `natural_scroll` | `true` (`B/input.lua:17-19`) | `true` (`N/hyprland.conf:58-62`) | PORTED |

---

## 5. Layouts, splits, group behavior

| Topic | ML4W exact value/implementation (file:line) | Noctalia exact value/implementation (file:line) | Verdict |
|---|---|---|---|
| `general.layout` | `"dwindle"` (active `B/conf/windows/glass.lua:12`; also default/gamemode/border variants) | `"dwindle"` (`N/hyprland.conf:32`) | PORTED |
| `dwindle.preserve_split` | `true` (active `B/conf/layouts/laptop.lua:6-8`; also `default.lua:6-8`) | `true` (`N/hyprland.conf:63-65`) | PORTED |
| Master layout | `master = { -- new_status="master" -- Commented out due to compatibility reasons }` (`B/conf/layouts/laptop.lua:10-12`, `default.lua:11-13`) | no `master` section | DROPPED (commented, never active) |
| `binds.allow_workspace_cycles` | `true` (`B/conf/layouts/laptop.lua:16`) | `true` (`N/hyprland.conf:67`) | PORTED |
| `binds.workspace_back_and_forth` | `false` (`B/conf/layouts/laptop.lua:15`) | absent | DROPPED (explicit) |
| `binds.pass_mouse_when_bound` | `false` (`B/conf/layouts/laptop.lua:17`) | `false` (`N/hyprland.conf:68`) | PORTED |
| `binds.scroll_event_delay` | `1` (`B/conf/keybindings/default.lua:132`) | `1` (`N/hyprland.conf:69`) | PORTED |
| `general.gaps_in` / `gaps_out` | active `10` / `16` (`B/conf/windows/glass.lua:3-4`); default variant `10/16`; gamemode `0/0`; no-border-more-gaps `20/40` | `8` / `16` (`N/hyprland.conf:27-28`) | CHANGED (`gaps_in` 10→8) |
| `general.border_size` | active `1` (`B/conf/windows/glass.lua:5`); default `2`; gamemode `1`; border-1..4 profiles `1..4`; no-border `0` | `2` (`N/hyprland.conf:29`) | CHANGED (1→2; equals ML4W `default.lua` variant) |
| `general.resize_on_border` | `true` (active `B/conf/windows/glass.lua:10`) | not set | DROPPED |
| `general.allow_tearing` | `false` in active `B/conf/windows/glass.lua:11`; **overridden to `true` by hyprmod** `B/hyprland-gui.lua:10` (loaded after all conf modules, `B/hyprland.lua:39-40`) | not set | DROPPED (conflicting ML4W values; neither present) |
| `general.col.active_border` | active gradient `{colors={primary,on_primary},angle=90}` = `rgba(95cdf7ff)`→`rgba(00344eff)` (`B/conf/windows/glass.lua:7`; `B/colors.lua:52,20`); transparent variant `{"rgb(ffffff)",on_primary}` | flat `"rgba(7aa2f7ff)"` (`N/hyprland.conf:30`) | CHANGED (gradient→flat, different hue) |
| `general.col.inactive_border` | active `on_primary`=`rgba(00344eff)` (`B/conf/windows/glass.lua:8`), then hyprmod override `"0xff000000"` (`B/hyprland-gui.lua:11-13`) | `"rgba(3b4261ff)"` (`N/hyprland.conf:31`) | CHANGED |
| Border window profiles | `B/conf/windows/border-1.lua`, `border-1-reverse.lua`, `border-2.lua`, `border-2-reverse.lua`, `border-3.lua`, `border-3-reverse.lua`, `border-4.lua`, `border-4-reverse.lua`, `no-border.lua`, `no-border-more-gaps.lua`, `transparent.lua`, `default.lua`, `gamemode.lua`, `glass.lua` (all `gaps_in/out=10/16` except no-border-more-gaps `20/40`; border sizes 1-4/0; active/on_primary color pairs reversed in `*-reverse` variants) | none | DROPPED (available profiles) |
| Split dispatch behavior | `hl.dsp.layout("togglesplit")` and `hl.dsp.layout("swapsplit")` (`B/conf/keybindings/default.lua:63,76`); no split config keys | same dispatchers (`N/hyprland.conf:321,334`); no split config keys | PORTED |
| Window group config | `group.toggle` active, `group.active("f")` commented (`B/conf/keybindings/default.lua:74-75`); no `group:` keys | `group.toggle` active (`N/hyprland.conf:333`); no `group:` keys | PORTED |

---

## 6a. Animations (active profile) — leaf-by-leaf

| Topic | ML4W exact value/implementation (file:line) | Noctalia exact value/implementation (file:line) | Verdict |
|---|---|---|---|
| Master switch | `animations.enabled=true` (`B/conf/animations/animations-fast.lua:9-13`) | `animations.enabled=true` (`N/hyprland.conf:55-57`) | PORTED |
| Curves defined | 11 curves (`B/conf/animations/animations-fast.lua:18-28`): `linear {0,0}{1,1}`; `md3_standard {0.2,0}{0,1}`; `md3_decel {0.05,0.7}{0.1,1}`; `md3_accel {0.3,0}{0.8,0.15}`; `overshot {0.05,0.9}{0.1,1.1}`; `crazyshot {0.1,1.5}{0.76,0.92}`; `hyprnostretch {0.05,0.9}{0.1,1.0}`; `fluent_decel {0.1,1}{0,1}`; `easeInOutCirc {0.85,0}{0.15,1}`; `easeOutCirc {0,0.55}{0.45,1}`; `easeOutExpo {0.16,1}{0.3,1}` | 1 curve: `hl.curve("smooth",{type="bezier", points={{0.05,0.9},{0.1,1.0}}})` (`N/hyprland.conf:82`) = ML4W `hyprnostretch` reordered/renamed | CHANGED (10 curves dropped) |
| `global` leaf | not defined | `speed=10, bezier="smooth", enabled=true` (`N/hyprland.conf:83`) | NEW |
| `windows` leaf | `speed=3, bezier="md3_decel", style="popin 60%"` (`B/conf/animations/animations-fast.lua:33`) | `speed=7, bezier="smooth"` (no style) (`N/hyprland.conf:84`) | CHANGED |
| `windowsIn` leaf | not defined in active fast profile | `speed=8, bezier="smooth", style="popin 97%"` (`N/hyprland.conf:85`) | NEW |
| `windowsOut` leaf | not defined in active fast profile | `speed=8, bezier="smooth", style="popin 97%"` (`N/hyprland.conf:86`) | NEW |
| `border` leaf | `speed=10, bezier="default"` (`B/conf/animations/animations-fast.lua:34`) | absent | DROPPED |
| `fade` leaf | `speed=2.5, bezier="md3_decel"` (`B/conf/animations/animations-fast.lua:35`) | `speed=10, bezier="smooth"` (`N/hyprland.conf:87`) | CHANGED |
| `workspaces` leaf | `speed=3.5, bezier="easeOutExpo", style="slide"` (`B/conf/animations/animations-fast.lua:36`) | `speed=9, bezier="smooth", style="slidefade 8%"` (`N/hyprland.conf:88`) | CHANGED |
| `specialWorkspace` leaf | `speed=3, bezier="md3_decel", style="slidevert"` (`B/conf/animations/animations-fast.lua:37`) | absent | DROPPED |
| `layersIn/Out`, `fadeLayersIn/Out` leaves | absent in active fast profile (present in `default.lua`/`end4.lua`) | absent | PORTED (both absent) |
| `borderangle`, `windowsMove`, `fadeDim` leaves | absent in active fast profile | absent | PORTED (both absent) |

## 6b. All ML4W animation variant profiles (complete list)

| Topic | ML4W exact value/implementation (file:line) | Noctalia exact value/implementation (file:line) | Verdict |
|---|---|---|---|
| `default.lua` ("Default") | curves 14 (`B/conf/animations/default.lua:18-31`): `linear{0,0}{1,1}`, `md3_standard{0.2,0}{0,1}`, `md3_decel{0.05,0.7}{0.1,1}`, `md3_accel{0.3,0}{0.8,0.15}`, `overshot{0.05,0.9}{0.1,1.1}`, `crazyshot{0.1,1.5}{0.76,0.92}`, `hyprnostretch{0.05,0.9}{0.1,1.0}`, `menu_decel{0.1,1}{0,1}`, `menu_accel{0.38,0.04}{1,0.07}`, `easeInOutCirc{0.85,0}{0.15,1}`, `easeOutCirc{0,0.55}{0.45,1}`, `easeOutExpo{0.16,1}{0.3,1}`, `softAcDecel{0.26,0.26}{0.15,1}`, `md2{0.4,0}{0.2,1}`; leaves (`:36-56`): windows 3/md3_decel/popin60%, windowsIn 3/md3_decel/popin60%, windowsOut 3/md3_accel/popin60%, border 10/default, fade 3/md3_decel, layersIn 3/menu_decel/slide, layersOut 1.6/menu_accel, fadeLayersIn 2/menu_decel, fadeLayersOut 4.5/menu_accel, workspaces 7/menu_decel/slide, specialWorkspace 3/md3_decel/slidevert; commented: layers 2/md3_decel/slide, workspaces 2.5/softAcDecel/slide, workspaces 7/menu_decel/slidefade15%, specialWorkspace 3/md3_decel/slidefadevert15% | not carried (see 6a) | DROPPED |
| `standard.lua` ("Standard") | curve `myBezier{0.05,0.9}{0.1,1.05}` (`:18`); leaves: windows 7/myBezier, windowsOut 7/default/popin80%, border 10/default, borderangle 8/default, fade 7/default, workspaces 6/default (`:23-28`) | not carried | DROPPED |
| `animations-fast.lua` ("Fast", ACTIVE) | 11 curves + 5 leaves exactly as listed in 6a | partially ported as changed `smooth` curve + 6 leaves (`N/hyprland.conf:82-88`) | CHANGED |
| `animations-classic.lua` ("Classic") | identical to `standard.lua`: `myBezier{0.05,0.9}{0.1,1.05}`; windows 7, windowsOut 7/popin80%, border 10, borderangle 8, fade 7, workspaces 6 (`B/conf/animations/animations-classic.lua:18-28`) | not carried | DROPPED |
| `animations-dynamic.lua` ("Dynamic") | curves `wind{0.05,0.9}{0.1,1.05}`, `winIn{0.1,1.1}{0.1,1.1}`, `winOut{0.3,-0.3}{0,1}`, `liner{1,1}{1,1}` (`:18-21`); leaves: windows 6/wind/slide, windowsIn 6/winIn/slide, windowsOut 5/winOut/slide, windowsMove 5/wind/slide, border 1/liner, borderangle 30/liner/loop, fade 10/default, workspaces 5/wind (`:26-33`) | not carried | DROPPED |
| `animations-end4.lua` ("End-4", credit end-4/dots-hyprland) | 14 curves identical to `default.lua` (`:19-32`); 11 leaves identical to `default.lua` (`:37-47`) | not carried | DROPPED |
| `animations-high.lua` ("High") | identical to `dynamic.lua`: `wind/winIn/winOut/liner` curves; windows 6, windowsIn 6, windowsOut 5, windowsMove 5, border 1, borderangle 30/loop, fade 10, workspaces 5 (`B/conf/animations/animations-high.lua:18-33`) | not carried | DROPPED |
| `animations-moving.lua` ("Moving") | curves `overshot{0.05,0.9}{0.1,1.05}`, `smoothOut{0.5,0}{0.99,0.99}`, `smoothIn{0.5,-0.5}{0.68,1.5}` (`:18-20`); leaves: windows 5/overshot/slide, windowsOut 3/smoothOut, windowsIn 3/smoothOut, windowsMove 4/smoothIn/slide, border 5/default, fade 5/smoothIn, fadeDim 5/smoothIn, workspaces 6/default (`:25-32`) | not carried | DROPPED |
| `animations-smooth.lua` ("Smooth") | curves `overshot{0.05,0.9}{0.1,1.05}`, `easeOutExpo{0.16,1}{0.3,1}`, `easeOutBack{0.34,1.56}{0.64,1}`, `easeInBack{0.36,0}{0.66,-0.56}`, `easeInOutBack{0.68,-0.6}{0.32,1.6}` (`:18-22`); leaves: windows 3/overshot/slide, windowsOut 100/easeOutExpo, windowsIn 7/easeOutBack, windowsMove 6/easeInOutBack/slide, border 5/default, fade 5/easeOutBack, fadeDim 5/easeOutBack, workspaces 10/easeOutExpo (`:27-34`) | not carried (note: Noctalia curve named `smooth` is NOT this profile; it is `hyprnostretch` points) | DROPPED |
| `disabled.lua` ("Disabled") | `animations.enabled=false`, no curves/leaves (`B/conf/animations/disabled.lua:10-14`) | no equivalent (animations always enabled) | DROPPED |
| `toggle-animations.sh` | runtime toggle script bound to Super+Shift+A (`B/conf/keybindings/default.lua:83`) | absent (only hyprglass on/off toggle exists, `N/hyprland.conf:263-267`) | DROPPED |

---

## 7. Decorations / effects

| Topic | ML4W exact value/implementation (file:line) | Noctalia exact value/implementation (file:line) | Verdict |
|---|---|---|---|
| `decoration.rounding` | active `10` (`B/conf/decorations/default.lua:8`), then hyprmod override `15` + `rounding_power=3.5` (`B/hyprland-gui.lua:5-8`); default `rounding_power=2` (`default.lua:12`) | `rounding=14`; no `rounding_power` (`N/hyprland.conf:35`) | CHANGED |
| Opacity leaves | `active_opacity=1.0`, `inactive_opacity=0.9`, `fullscreen_opacity=1.0` (`B/conf/decorations/default.lua:9-11`) | not set | DROPPED |
| Blur (active) | `enabled=true, size=4, passes=4, new_optimizations=on, ignore_opacity=true, xray=true, vibrancy=0.1696` (`B/conf/decorations/default.lua:21-29`) | `enabled=true, size=6, passes=2, new_optimizations=true, ignore_opacity=true, xray=false, noise=0.04, contrast=1.0, brightness=0.9, popups=true` (`N/hyprland.conf:36-47`) | CHANGED |
| Shadow (active) | `enabled=true, range=32, render_power=2, color="rgba(00000050)"` (`B/conf/decorations/default.lua:14-19`) | `enabled=true, range=20, render_power=3, color="rgba(16161e66)"` (`N/hyprland.conf:48-53`) | CHANGED |
| Blur/shadow decoration profiles | 9 profiles in `B/conf/decorations/`: `blur.lua` (size3/passes4/xray true + waybar layer blur), `no-blur.lua` (enabled=false), `no-rounding.lua` (rounding0, size4/passes4/vibrancy), `no-rounding-more-blur.lua` (rounding0, inactive_opacity0.6, size12/passes6, range30/power3 color `0x66000000`), `rounding.lua` (inactive0.8, size3/passes4), `rounding-all-blur.lua` (active0.9/inactive0.6/fullscreen0.9, size3/passes4 + waybar rule), `rounding-all-blur-no-shadows.lua` (shadow enabled=false + waybar rule), `rounding-more-blur.lua` (size12/passes6, range30/power3), `gamemode.lua` (rounding0, shadow off, blur off) | none | DROPPED (available profiles) |
| `misc.force_default_wallpaper` | `0` (`B/conf/misc.lua:4`; also `B/hyprland-gui.lua:18`) | not set | DROPPED |
| `misc.disable_hyprland_logo` | `true` (`B/conf/misc.lua:3`), hyprmod override `false` (`B/hyprland-gui.lua:16`) | `true` (`N/hyprland.conf:72`) | CHANGED (net ML4W value was false) |
| `misc.disable_splash_rendering` | `true` (`B/conf/misc.lua:5`), hyprmod override `false` (`B/hyprland-gui.lua:17`) | `true` (`N/hyprland.conf:73`) | CHANGED (net ML4W value was false) |
| `misc.allow_session_lock_restore` | `true` (`B/conf/misc.lua:8`) | `true` (`N/hyprland.conf:74`) | PORTED |
| `misc.vrr` (global) | `1` (`B/hyprland-gui.lua:19`; contradicts monitor `vrr=0`) | not set | DROPPED |
| HyprGlass plugin load | absent | `hl.plugin.load(os.getenv("HOME") .. "/.local/share/hyprland/plugins/hyprglass.so")` (`N/hyprland.conf:23`), guarded by `if hl.plugin.hyprglass` (`:170`) | NEW |
| HyprGlass preset `liquid` | absent | `inherits="pomme"`, `refraction_strength=8.0`, `chromatic_aberration=1.0`, `specular_strength=1.0`, `specular_angle=0.0`, `bevel_strength=1.0`, `bevel_size=6.0`, `bevel_color=0xffffff00`, `bevel_tint=0.0`, `bevel_angle=315.0`, `bevel_shadow=0.5`, `fresnel_strength=1.0`, `edge_height=30`, `edge_thickness_px=20`, `fresnel_reflection=0.4`, `lens_distortion=0.5`, `blur_strength=2.0`, `blur_iterations=3`, `noise_strength=0.0`, `glass_opacity=0.9`, `tint_color=0x8899aa22` (`N/hyprland.conf:173-195`) | NEW |
| HyprGlass preset `matte` | absent | `inherits="subtle"`, `noise_strength=0.5`, `frost=1.0`, `frost_blur=2.0`, `refraction_strength=0.3`, `refraction_spread=1.0`, `refraction_flow=0.0`, `chromatic_aberration=0.0`, `specular_strength=0.0`, `fresnel_strength=0.0`, `bevel_strength=0.0`, `edge_height=0.0`, `edge_thickness_px=0.0`, `lens_distortion=0.0`, `blur_strength=2.0`, `blur_iterations=5`, `glass_opacity=1.0`, `tint_color=0x8899aa22` (`N/hyprland.conf:197-216`) | NEW |
| HyprGlass preset `lens` | absent | `inherits="clear"`, `edge_height=30`, `edge_thickness_px=20`, `fresnel_reflection=1.0`, `refraction_strength=0.6`, `chromatic_aberration=0.5`, `lens_distortion=1.0`, `fresnel_strength=0.6`, `specular_strength=0.8`, `blur_strength=1.5`, `blur_iterations=3`, `noise_strength=0.0`, `glass_opacity=0.8`, `tint_color=0x8899aa22`, `refraction_flow=0.0`, `refraction_spread=1.0` (`N/hyprland.conf:218-235`) | NEW |
| HyprGlass global config | absent | `default_theme="dark"`, `default_preset="liquid"`, `manage_window_blur=true`, `skip_opaque_windows=true`, `blur_fold=true`, `events={geometry=false}`, `layers={enabled=true, mask_mode="auto", mask_threshold=0.15, live_resample=false, popups={enabled=true}}` (`N/hyprland.conf:237-251`); runtime `hg.config({enabled=glass_on})` toggle (`:263-267`); glass-mode menu bind `noctalia msg panel-open launcher /glass` (`:261`) | NEW |
| HyprGlass exclusion | absent | window rule `glass-shell-only`, `match={class=".*"}`, `tag="+hyprglass_disabled"` (`N/hyprland.conf:158-162`) | NEW |
| Wallpaper effects list (14 files) | `B/effects/wallpaper/`: `blackwhite` (`magick $IMAGE_PATH -set colorspace Gray -separate -average $IMAGE_PATH`); `blackwhite-blur` (same + `-blur "50x30"`); `blackwhite-brightness40/60/80` (same + `-brightness-contrast -60%/-40%/-20%`); `blur1` (`-blur "50x30"`); `blur1-brightness40/60/80` (blur50x30 + -60%/-40%/-20%); `blur2` (`-blur "10x30"`); `negate` (`-negate`); `negate-brightness40/60/80` (`-negate` + -60%/-40%/-20%) | No wallpaper-effect scripts in `N/`; `C:202-203` `[wallpaper.automation] enabled=false`; wallpaper handled by Noctalia IPC (`N/hyprland.conf:308-310`) and `C:74` bar wallpaper widget | DROPPED |
| Gamemode effects | `activate_gamemode()` (`B/functions.lua:2-21`): `animations.enabled=false`; `decoration.shadow.enabled=false`, `blur.enabled=false`, `active_opacity=1.0`, `inactive_opacity=1.0`, `fullscreen_opacity=1.0`, `rounding=0`; `general.gaps_in=0`, `gaps_out=0`, `border_size=1`. Runtime `B/scripts/gamemode.sh:17-39` toggles `gamemode-enabled` flag + wallpaper-automation restart + `hyprctl reload`/`hyprctl eval "activate_gamemode()"`. Startup `B/scripts/load-gamemode.sh:12-28` uses `hyprctl --batch "keyword animations:enabled 0; keyword decoration:shadow:enabled 0; keyword decoration:blur:enabled 0; keyword general:gaps_in 0; keyword general:gaps_out 0; keyword general:border_size 1; keyword decoration:rounding 0"`. Profiles `B/conf/decorations/gamemode.lua`, `B/conf/windows/gamemode.lua`. Bound Super+Alt+G (`B/conf/keybindings/default.lua:108`) | No gamemode effects/script in `N/`; Super+Alt+G is glass-mode menu (`N/hyprland.conf:261`); Noctalia `caffeine-toggle` only inhibits idle (`:299`) | DROPPED |
| Hyprsunset / night-light effects | `B/hyprsunset.conf:1-5`: `profile{time=00:00, temperature=5000, gamma=0.8}`; `B/scripts/display-mode.sh:3-38` rofi menu: Grayscale (`hyprshade on grayscale`), Blue light (`hyprsunset -t 4500 -g 90`), Night (`-t 3000 -g 70`), Dim (`-t 6000 -g 60`), Focus (`-t 6000 -g 70` + grayscale), Reset all; `B/scripts/gtk.sh` + `ml4w-toggle-hyprsunset` binding | No `hyprsunset.conf` in `N/`; `noctalia msg nightlight-force-toggle` (`N/hyprland.conf:305`), `nightlight` control-center shortcut (`C:190-191`), `widget.nightlight` in bar group g3 (`C:106`); `C:35-37` `[lockscreen] blur_intensity=0.35, transition=[]` | CHANGED |
| Hyprtoolkit / toolkit effects | `B/hyprtoolkit.conf:1-15`: `background=0xff101417`, `base=0xff1c2024`, `text=0xffe0e3e8`, `alternate_base=0xff262a2e`, `bright_text=0xff2d3135`, `link_text=0xffcfc0e8`, `accent=0xff95cdf7`, `accent_secondary=0xffb7c9d9`, `rounding_large=12`, `rounding_small=9`, `font_family="Ubuntu Sans"` | none | DROPPED |
| Hyprpaper / wallpaper cache | `B/hyprpaper.conf:1-3`: `preload=$HOME/.config/hypr/assets/blank.png`, `wallpaper=,$HOME/.config/hypr/assets/blank.png`, `splash=false`; `B/hyprlock.conf:10,21,87` uses `$ml4w_cache_folder/blurred_wallpaper.png` and `square_wallpaper.png` | no hyprpaper config; Noctalia shell draws wallpaper (`C:202-203` automation disabled) | DROPPED |

---

## 8. Monitors

| Topic | ML4W exact value/implementation (file:line) | Noctalia exact value/implementation (file:line) | Verdict |
|---|---|---|---|
| Active output/mode/position/scale/VRR | `B/monitors.lua:3-8` and `B/monitors.conf:3` (nwg-displays generated 2026-11-18 17:08): `output="eDP-1"`, `mode="1920x1080@60.02"`, `position="0x0"`, `scale=1.0`, `vrr=0` | `hl.monitor({output="eDP-1", mode="1920x1080@60.02", position="0x0", scale=1.0, vrr=0})` (`N/hyprland.conf:90-96`) | PORTED |
| Secondary generic monitor variant | Active selector `B/conf/monitor.lua:1` also loads `B/conf/monitors/1920x1080.lua:6-11`: `output=""`, `mode="1920x1080"`, `position="auto"`, `scale=1` (no VRR) — both loaded by `B/hyprland.lua:12-13` | none | CHANGED (duplicate generic rule removed) |
| Monitor profiles (available) | 14 profiles in `B/conf/monitors/`: `1366x768`, `1440x1080`, `1600x900`, `1920x1080`, `1920x1200`, `2560x1440@120`, `2560x1440@120x125` (mode 2560x1440@120, scale1.25), `2560x1440`, `3440x1440`, `default-125` (preferred/1.25), `default` (comment only), `highres`, `preferred`, `workspace-split` — all `output=""`, `position="auto"`, `scale=1` unless noted | none (single hardcoded monitor) | DROPPED |
| nwg-displays provenance | generated comment `B/monitors.lua:1`, `B/monitors.conf:1` | no generator comment (`N/hyprland.conf:90`) | DROPPED |
| Per-monitor workspace split | `B/conf/monitors/workspace-split.lua:6-16` (see Table 1) | none | DROPPED |

---

## 9. Idle / lock / suspend

| Topic | ML4W exact value/implementation (file:line) | Noctalia exact value/implementation (file:line) | Verdict |
|---|---|---|---|
| `general.lock_cmd` | `pidof hyprlock \|\| hyprlock` (commented alternative: `playerctl --all-players pause && pidof hyprlock \|\| hyprlock`) (`B/hypridle.conf:2-3`) | none; `N/hypridle.conf:2-4` explicitly documents "No lock_cmd and no before_sleep_cmd" | DROPPED |
| `general.before_sleep_cmd` | `loginctl lock-session` (`B/hypridle.conf:4`) | none (Noctalia uses logind `PrepareForSleep`, `N/hyprland.conf:270-272`) | DROPPED |
| `general.after_sleep_cmd` | `hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'` (`B/hypridle.conf:5`) | identical (`N/hypridle.conf:7`) | PORTED |
| Listener 480s | `on-timeout=brightnessctl -s set 10`, `on-resume=brightnessctl -r` (`B/hypridle.conf:8-12`) | identical (`N/hypridle.conf:10-14`) | PORTED |
| Keyboard-backlight 480s listener | commented out: `brightnessctl -sd rgb:kbd_backlight set 0` / `-rd rgb:kbd_backlight` (`B/hypridle.conf:14-19`) | absent | DROPPED (was inactive) |
| Listener 600s (lock) | `on-timeout=loginctl lock-session` (`B/hypridle.conf:21-24`) | absent | DROPPED |
| Listener 660s (DPMS) | `on-timeout=hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })'`; `on-resume=... enable && brightnessctl -r` (`B/hypridle.conf:26-30`) | same timeout/commands but `on-resume` only `... enable` (no `&& brightnessctl -r`) (`N/hypridle.conf:16-20`) | CHANGED (resume backlight restore dropped) |
| Listener 1800s (suspend) | `on-timeout=systemctl suspend` (`B/hypridle.conf:32-35`) | absent | DROPPED |
| Lock owner | hyprlock: `B/hyprlock.conf` (102 lines; `$ml4w_cache_folder=$HOME/.cache/ml4w/hyprland-dotfiles`, background blurred_wallpaper.png, input-field 200x50/dots0.33/0.15/rounding10/outline3/fade1000, label clock 70px + $USER 20px, image square_wallpaper.png 280/rounding40/border4); power menu `ml4w-power -l` (`B/conf/keybindings/default.lua:109`); `B/scripts/power.sh:48-52` calls `hyprlock` | Noctalia IPC `noctalia msg session lock` (`N/hyprland.conf:294,301`); logind PrepareForSleep; `C:35-37` lockscreen `blur_intensity=0.35`, `transition=[]`; `N/hypridle.conf:2-4` notes lock re-added before daily use | CHANGED |
| hypridle startup command | bare `hypridle` (`B/conf/autostart.lua:60-61`) | `hypridle -c $HOME/.config/hypr-noctalia/hypridle.conf` (`N/hyprland.conf:279`) | CHANGED |
| hypridle control scripts | `B/scripts/hypridle.sh:9-39` (`status`/`toggle`, pgrep/killall/start), `B/scripts/restart-hypridle.sh:6-12` (killall + sleep1 + restart + notify) | none | DROPPED |
| Idle inhibitor | none in ML4W | `noctalia msg caffeine-toggle` (`N/hyprland.conf:299`), `C:106` caffeine widget, `C:194-195` control-center shortcut | NEW |

---

## 10. Autostart / services / isolation (exact commands)

| Topic | ML4W exact value/implementation (file:line) | Noctalia exact value/implementation (file:line) | Verdict |
|---|---|---|---|
| dbus environment export | `dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP` (`B/conf/autostart.lua:13`) | `dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE` (`N/hyprland.conf:277`) | CHANGED (`XDG_SESSION_TYPE` added) |
| Portal restart on start | `systemctl --user stop xdg-desktop-portal xdg-desktop-portal-hyprland` then `systemctl --user start xdg-desktop-portal-hyprland xdg-desktop-portal` (`B/conf/autostart.lua:15-17`); plus `B/scripts/xdg.sh:17-57` killall 6 portals, stop pipewire/wireplumber + 5 portals, start `/usr/lib/xdg-desktop-portal-hyprland`, `/usr/lib/xdg-desktop-portal-gtk` (if present), `/usr/lib/xdg-desktop-portal`, then systemctl start pipewire/wireplumber/2 portals | none in `N/` | DROPPED |
| `awww-daemon` | started (`B/conf/autostart.lua:19-20`) | killed by isolation `pkill -x awww-daemon` (`N/isolate-ml4w.sh:10`) | DROPPED (actively killed) |
| Cursor load | `hyprctl setcursor Bibata-Modern-Ice 24` (`B/conf/autostart.lua:22-23`); `B/scripts/gtk.sh:44-48` writes `conf/cursor.conf` + `hyprctl setcursor $cursor_theme $cursor_size` | no setcursor command; env `XCURSOR_THEME="Sweet-cursors"`, `XCURSOR_SIZE=24`, `HYPRCURSOR_SIZE=24` (`N/hyprland.conf:16-18`) | CHANGED |
| ML4W listeners | `~/.config/ml4w/listeners.sh --startall` (`B/conf/autostart.lua:25-26`); stopped by `B/scripts/power.sh:37` | none | DROPPED |
| Waybar | `$HOME/.config/waybar/launch.sh` (`B/conf/autostart.lua:28-29`) | killed by isolation `pkill -x waybar` (`N/isolate-ml4w.sh:9`); Noctalia bar/dock owned by shell (`C:39-117,302-317`) | DROPPED (replaced by Noctalia bar/dock) |
| Polkit agent | `systemctl --user start hyprpolkitagent.service 2>/dev/null \|\| /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 \|\| true` (`B/conf/autostart.lua:31-37`) | `systemctl --user start hyprpolkitagent.service` (`N/hyprland.conf:278`) | CHANGED (gnome fallback dropped) |
| Wallpaper restore | `~/.config/ml4w/scripts/ml4w-wallpaper-app --restore` unless `wallpaper-app` setting is `quickshell` (`B/conf/autostart.lua:4-10,39-42`) | none; Noctalia owns wallpaper, automation disabled (`C:202-203`) | DROPPED |
| ml4w-autostart + log rotation | `d="$HOME/.local/state/ml4w-os-hyprland"; mkdir -p "$d"; ls -1r "$d"/ml4w-autostart-*.log 2>/dev/null \| tail -n +10 \| xargs -r rm -f; ~/.config/ml4w/scripts/ml4w-autostart > "$d/ml4w-autostart-$(date +%Y-%m-%d_%H-%M-%S).log" 2>&1` (`B/conf/autostart.lua:44-50`) | none | DROPPED |
| GTK settings application | `~/.config/hypr/scripts/gtk.sh` (`B/conf/autostart.lua:52-53`) | not executed; relies on gsettings persisted by ML4W (`N/hyprland.conf:20-21` comment) | DROPPED (script), state retained |
| SwayNC | `[ -f ~/.config/ml4w/.swaync-dbus-activated ] \|\| swaync` (`B/conf/autostart.lua:55-58`) | killed by isolation `pkill -x swaync` (`N/isolate-ml4w.sh:8`); notifications owned by Noctalia (`C:292-295`) | DROPPED (replaced) |
| hypridle | `hypridle` (`B/conf/autostart.lua:60-61`) | `hypridle -c $HOME/.config/hypr-noctalia/hypridle.conf` (`N/hyprland.conf:279`) | CHANGED |
| Clipboard watcher | `wl-paste --watch cliphist store` (`B/conf/autostart.lua:63-64`) | none; Noctalia owns clipboard history via IPC clipboard-clear/copy/text (`N/hyprland.conf:270-271`) | DROPPED |
| Cleanup script | `~/.config/hypr/scripts/cleanup.sh` (`B/conf/autostart.lua:66-67`; removes `~/.cache/gamemode`, `B/scripts/cleanup.sh:10-13`) | none | DROPPED |
| HyprGlass plugin | none | `hl.plugin.load(.../hyprglass.so)` (`N/hyprland.conf:23`) | NEW |
| Shell | Quickshell via ml4w-autostart / `qs` IPC (`B/conf/keybindings/default.lua:93,105-107,111`) | `noctalia` (`N/hyprland.conf:280`) | NEW |
| Isolation guard | none (ML4W is the base session) | `[ "$NOCTALIA_SESSION" = 1 ] \|\| exit 0` (`N/isolate-ml4w.sh:5`); `sleep 3` (`:6`); `systemctl --user stop elephant.service walker.service >/dev/null 2>&1` (`:7`); `pkill -x swaync`, `pkill -x waybar`, `pkill -x awww-daemon` (`:8-10`) | NEW |
| Session desktop file | no dedicated session file in backup (uses system Hyprland SDDM session) | `N/session/hyprland-noctalia.desktop`: `Name=Hyprland + Noctalia`, `Exec=/usr/local/bin/hyprland-noctalia-session`, `Type=Application`, `DesktopNames=Hyprland`, `Keywords=tiling;wayland;compositor;noctalia;` | NEW |
| Session wrapper | none | `N/session/hyprland-noctalia-session:4-12`: exports `XDG_SESSION_TYPE=wayland`, `XDG_CURRENT_DESKTOP=Hyprland`, `XDG_SESSION_DESKTOP=Hyprland`, `DESKTOP_SESSION=Hyprland`, `ELECTRON_OZONE_PLATFORM_HINT=wayland`, `MOZ_ENABLE_WAYLAND=1`, `GDK_BACKEND='wayland,x11,*'`, `NOCTALIA_SESSION=1`; `exec /usr/bin/start-hyprland -- --config "$HOME/.config/hypr-noctalia/hyprland.conf"` | NEW |

---

## 11. Environment variables & toolkit settings

| Topic | ML4W exact value/implementation (file:line) | Noctalia exact value/implementation (file:line) | Verdict |
|---|---|---|---|
| `OZONE_PLATFORM` | `"wayland"` (`B/conf/ml4w.lua:207`) | `"wayland"` (`N/hyprland.conf:7`) | PORTED |
| `ELECTRON_OZONE_PLATFORM_HINT` | `"wayland"` (`B/conf/ml4w.lua:208`) | `"wayland"` (`N/hyprland.conf:8`; also wrapper `N/session/hyprland-noctalia-session:8`) | PORTED |
| `QT_QPA_PLATFORM` | `"wayland;xcb"` (`B/conf/ml4w.lua:213`) | `"wayland;xcb"` (`N/hyprland.conf:9`) | PORTED |
| `QT_QPA_PLATFORMTHEME` | `"qt6ct"` (`B/conf/ml4w.lua:214`) | commented out: `-- hl.env("QT_QPA_PLATFORMTHEME", "qt6ct") -- disabled for first days: Breeze theme is a picker-crash suspect` (`N/hyprland.conf:10`) | DROPPED (deliberately disabled) |
| `QT_WAYLAND_DISABLE_WINDOWDECORATION` | `"1"` (`B/conf/ml4w.lua:215`) | `"1"` (`N/hyprland.conf:11`) | PORTED |
| `GDK_SCALE` | `"1"` (`B/conf/ml4w.lua:222`) | `"1"` (`N/hyprland.conf:12`) | PORTED |
| `GDK_BACKEND` | `"wayland,x11,*"` (`B/conf/ml4w.lua:225`) | `"wayland,x11,*"` (`N/hyprland.conf:13`; wrapper `:10`) | PORTED |
| `CLUTTER_BACKEND` | `"wayland"` (`B/conf/ml4w.lua:226`) | `"wayland"` (`N/hyprland.conf:14`) | PORTED |
| `MOZ_ENABLE_WAYLAND` | `"1"` (`B/conf/ml4w.lua:229`) | `"1"` (`N/hyprland.conf:15`; wrapper `:9`) | PORTED |
| `XCURSOR_THEME` | `"Bibata-Modern-Ice"` (`B/conf/ml4w.lua:232`) | `"Sweet-cursors"` (`N/hyprland.conf:16`) | CHANGED |
| `XCURSOR_SIZE` / `HYPRCURSOR_SIZE` | `"24"` / `"24"` (`B/conf/ml4w.lua:233-234`) | `"24"` / `"24"` (`N/hyprland.conf:17-18`) | PORTED |
| `SDL_VIDEODRIVER` | `"wayland"` (`B/conf/ml4w.lua:237`) | `"wayland"` (`N/hyprland.conf:19`) | PORTED |
| `DESKTOP_SESSION` | `"Hyprland"` (`B/conf/ml4w.lua:209`) | set in wrapper only (`N/session/hyprland-noctalia-session:7`) | CHANGED (moved to wrapper) |
| `XDG_SESSION_TYPE` | `"wayland"` (`B/conf/ml4w.lua:210,218`) | wrapper `=wayland` (`N/session/hyprland-noctalia-session:4`); also passed via dbus-update (`N/hyprland.conf:277`) | CHANGED (moved to wrapper) |
| `XDG_CURRENT_DESKTOP` | `"Hyprland"` (`B/conf/ml4w.lua:217`) | wrapper `=Hyprland` (`N/session/hyprland-noctalia-session:5`) | CHANGED (moved to wrapper) |
| `XDG_SESSION_DESKTOP` | `"Hyprland"` (`B/conf/ml4w.lua:219`) | wrapper `=Hyprland` (`N/session/hyprland-noctalia-session:6`) | CHANGED (moved to wrapper) |
| `PATH` prepends | `HOME .. "/.local/bin:" .. PATH` then `HOME .. "/.cargo/bin:" .. PATH` (`B/conf/ml4w.lua:10-16`) | not set | DROPPED |
| `QS_ICON_THEME` | parsed from `~/.config/gtk-3.0/settings.ini` key `gtk-icon-theme-name` via Lua io.open/line match (`B/conf/environment.lua:1-16`) | not set | DROPPED |
| `QS_NO_RELOAD_POPUP` | `"1"` (`B/conf/ml4w.lua:240`) | not set | DROPPED |
| `NOCTALIA_SESSION` | absent | `"1"` in wrapper, used as isolation-script guard (`N/session/hyprland-noctalia-session:11`; `N/isolate-ml4w.sh:5`) | NEW |
| Input keyboard config | `kb_layout="us"`, `kb_variant=""`, `kb_model=""`, `kb_options="grp:win_space_toggle"`, `kb_rules=""`, `sensitivity=0`, `follow_mouse=1` (`B/input.lua:5-20`) | `kb_layout="us"`, `follow_mouse=1`, `touchpad.natural_scroll=true` (`N/hyprland.conf:58-62`); no `kb_options`/variant/model/rules/sensitivity | CHANGED (layout-switch + sensitivity settings dropped) |
| GTK theme | `B/scripts/gtk.sh:14-48` sets gsettings `org.gnome.desktop.interface` gtk-theme/icon-theme/cursor-theme/font-name/color-scheme from settings.ini; comment: WhiteSur-Dark-solid/WhiteSur-dark/prefer-dark, Fira Sans 11 (`N/hyprland.conf:20-21` records it is still persisted) | no gtk.sh execution; gsettings state reused | DROPPED (script), values persist |
| Environment profiles | `B/conf/environments/default.lua` empty; `kvm.lua:1` `WLR_RENDERER_ALLOW_SOFTWARE=1`; `nvidia.lua:1-2` `LIBVA_DRIVER_NAME=nvidia`, `__GLX_VENDOR_LIBRARY_NAME=nvidia` (inactive) | none | DROPPED (available profiles) |

---

## 12. Portals, polkit, input methods, XWayland

| Topic | ML4W exact value/implementation (file:line) | Noctalia exact value/implementation (file:line) | Verdict |
|---|---|---|---|
| Portal restart at start | stop/start `xdg-desktop-portal` + `xdg-desktop-portal-hyprland` (`B/conf/autostart.lua:15-17`) | none | DROPPED |
| Full portal/pipewire reset script | `B/scripts/xdg.sh:17-57` (see Table 10) | none | DROPPED |
| Portal GTK dialog rule | `xdg-desktop-portal-gtk` window rule, `center=false`, `800 600` (`B/conf/ml4w.lua:124-130`) | `name="gtk-file-dialog"`, `center=true`, `800 600` (`N/hyprland.conf:137-143`) | CHANGED |
| Share picker rule | `hyprland-share-picker` rule (`B/conf/ml4w.lua:114-121`) | absent; `QT_QPA_PLATFORMTHEME=qt6ct` disabled due to picker-crash suspicion (`N/hyprland.conf:5-6,10`) | DROPPED |
| Polkit agent | `systemctl --user start hyprpolkitagent.service 2>/dev/null \|\| /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 \|\| true` (`B/conf/autostart.lua:31-37`) | `systemctl --user start hyprpolkitagent.service` (`N/hyprland.conf:278`) | CHANGED |
| Input methods (fcitx/ibus/RIME) | none configured; only `kb_options="grp:win_space_toggle"` layout toggle (`B/input.lua:10`) | none configured | PORTED (both none) |
| `xwayland.force_zero_scaling` | `true` (`B/conf/ml4w.lua:242-247`) | `true` (`N/hyprland.conf:76-78`) | PORTED |
| XWayland video bridge | `xwaylandvideobridge` rule: opacity `0.0 override 0.0 override`, no_anim, no_initial_focus, max_size `1 1`, no_blur, float (`B/conf/ml4w.lua:191-201`) | absent | DROPPED |
| XWayland input backend | `QT_QPA_PLATFORM="wayland;xcb"` fallback to xcb (`B/conf/ml4w.lua:213`) | identical (`N/hyprland.conf:9`) | PORTED |
| dbus activation env | without `XDG_SESSION_TYPE` (`B/conf/autostart.lua:13`) / `XDG_CURRENT_DESKTOP=hyprland` in `B/scripts/xdg.sh:27` | with `XDG_SESSION_TYPE` (`N/hyprland.conf:277`) | CHANGED |

---

<a id="ml4w-parameters"></a>
# ML4W parameter sheet — exhaustive extraction

**Source A:** `/home/sahil/mydotfiles/backups-noctalia-2026-11-22/hypr/` (entire tree)
**Source B:** `/home/sahil/.cache/ml4w/`

**Path conventions in the File column**
- `hypr/...` → relative to Source A. Bare names (`hyprland.lua`, `colors.conf`, `scripts/...`, `conf/...`, `effects/...`) are also relative to Source A.
- `cache/...` → relative to `/home/sahil/.cache/ml4w/nested-settings-20261014_104636/` (canonical depth-0 copy). The 10 nested `settings/settings/...` copies (depths 1–10) are byte-identical duplicates of the depth-0 set; values below apply to all 11 copies.
- `cache-dotfiles/...` → relative to `/home/sahil/.cache/ml4w/hyprland-dotfiles/`.

**Load order / precedence:** `hyprland.lua` requires, in order: `functions`, `monitors`, `conf.monitor`, `input`, `gestures`, `conf.autostart`, `colors`, `conf.environment`, `conf.window`, `conf.decoration`, `conf.layout`, `conf.workspace`, `conf.misc`, `conf.keybinding`, `conf.windowrule`, `conf.animation`, `conf.ml4w`, `hyprland-gui`, then `custom` **only if** `~/.config/hypr/custom.lua` exists. Later assignment wins; `custom.lua` wins over everything.

**Active variants (selector files):** animation → `animations-fast.lua`; decoration → `default.lua`; environment → `default.lua` (empty); window → `glass.lua`; layout → `laptop.lua`; monitor → `1920x1080.lua`; keybinding → `default.lua`; windowrule → `default.lua` (empty); workspace → `default.lua` (empty). HyprMod active profile: `946cfc33be85` ("Default"), identical snapshot to top-level `hyprland-gui.lua`.

---

## ACTIVE PARAMETERS (one row per parameter)

| File | Section/context | Parameter/key | Exact value | Purpose/effect (short) |
|---|---|---|---|---|
| hyprland.lua | load order | require | `functions` | Load helper functions first |
| hyprland.lua | load order | require | `monitors` | Load nwg-displays generated monitor block |
| hyprland.lua | load order | require | `conf.monitor` | Load selected monitor variant selector |
| hyprland.lua | load order | require | `input` | Load keyboard/touchpad input config |
| hyprland.lua | load order | require | `gestures` | Load 3/4-finger gestures |
| hyprland.lua | load order | require | `conf.autostart` | Register hyprland.start autostart hook |
| hyprland.lua | load order | require | `colors` | Load global color Lua globals |
| hyprland.lua | load order | require | `conf.environment` | Load environment selector + QS icon theme |
| hyprland.lua | load order | require | `conf.window` | Load selected window variant (glass) |
| hyprland.lua | load order | require | `conf.decoration` | Load selected decoration variant |
| hyprland.lua | load order | require | `conf.layout` | Load selected layout variant (laptop) |
| hyprland.lua | load order | require | `conf.workspace` | Load selected workspace variant |
| hyprland.lua | load order | require | `conf.misc` | Load misc settings |
| hyprland.lua | load order | require | `conf.keybinding` | Load selected keybinding variant |
| hyprland.lua | load order | require | `conf.windowrule` | Load selected windowrule variant |
| hyprland.lua | load order | require | `conf.animation` | Load selected animation variant (fast) |
| hyprland.lua | load order | require | `conf.ml4w` | Load ML4W env vars + app window rules |
| hyprland.lua | load order | require | `hyprland-gui` | Load HyprMod-generated overrides + binds |
| hyprland.lua | load order | conditional require | `if f then require("custom") end`, `f = io.open(HOME .. "/.config/hypr/custom.lua", "r")` | User overrides loaded last; win over all |
| hyprland.lua | header comment | note | `Loaded last so ~/.config/hypr/custom.lua can override everything, including settings made with HyprMod` | Documents override intent |
| functions.lua | activate_gamemode() | animations.enabled | `false` | Disable animations in game mode |
| functions.lua | activate_gamemode() | decoration.shadow.enabled | `false` | Disable shadows in game mode |
| functions.lua | activate_gamemode() | decoration.blur.enabled | `false` | Disable blur in game mode |
| functions.lua | activate_gamemode() | decoration.active_opacity | `1.0` | Full opacity focused |
| functions.lua | activate_gamemode() | decoration.inactive_opacity | `1.0` | Full opacity unfocused (OVERRIDE vs decoration 0.9) |
| functions.lua | activate_gamemode() | decoration.fullscreen_opacity | `1.0` | Full opacity fullscreen |
| functions.lua | activate_gamemode() | decoration.rounding | `0` | Square corners |
| functions.lua | activate_gamemode() | general.gaps_in | `0` | No inner gaps |
| functions.lua | activate_gamemode() | general.gaps_out | `0` | No outer gaps |
| functions.lua | activate_gamemode() | general.border_size | `1` | 1px border |
| functions.lua | activate_gamemode() | print | `"Gamemode ON"` | Console confirmation |
| functions.lua | load_variant() | variant_file transform | `variant_file:gsub(".lua", "")` | Strip .lua suffix |
| functions.lua | load_variant() | require path | `"conf." .. variant_name .. "." .. variant_file` | Resolves variant module |
| input.lua | input | kb_layout | `"us"` | US keyboard layout |
| input.lua | input | kb_variant | `""` | No layout variant |
| input.lua | input | kb_model | `""` | Default model |
| input.lua | input | kb_options | `"grp:win_space_toggle"` | Super+Space switches layout |
| input.lua | input | kb_rules | `""` | Default xkb rules |
| input.lua | input | follow_mouse | `1` | Focus follows mouse |
| input.lua | input | sensitivity | `0` | No modification; valid -1.0 - 1.0 |
| input.lua | input.touchpad | natural_scroll | `true` | Natural scrolling |
| monitors.lua | hl.monitor (nwg-displays 2026-11-18 17:08:34) | output | `"eDP-1"` | Laptop panel |
| monitors.lua | hl.monitor | mode | `"1920x1080@60.02"` | Generated refresh rate (refines variant `1920x1080`) |
| monitors.lua | hl.monitor | position | `"0x0"` | Origin |
| monitors.lua | hl.monitor | scale | `1.0` | 100% (same as variant scale 1) |
| monitors.lua | hl.monitor | vrr | `0` | VRR off for eDP-1 (OVERRIDE vs global misc.vrr=1) |
| workspaces.lua | whole file | — | *(empty file)* | No parameters |
| gestures.lua | gesture 1 (workspaces) | fingers | `3` | Three-finger swipe |
| gestures.lua | gesture 1 | direction | `"vertical"` | Vertical |
| gestures.lua | gesture 1 | action | `"workspace"` | Switch workspace |
| gestures.lua | gesture 2 (scrolling) | fingers | `3` | Three-finger swipe |
| gestures.lua | gesture 2 | direction | `"horizontal"` | Horizontal |
| gestures.lua | gesture 2 | action | `"scroll_move"` | Scroll content |
| gestures.lua | gesture 2 | scale | `0.9` | Scroll speed |
| gestures.lua | gesture 3 (fullscreen on) | fingers | `4` | Four-finger pinch |
| gestures.lua | gesture 3 | direction | `"pinchout"` | Pinch out |
| gestures.lua | gesture 3 | action | `function () hl.dispatch(hl.dsp.window.fullscreen({ action="set" })) end` | Enter fullscreen |
| gestures.lua | gesture 4 (fullscreen off) | fingers | `4` | Four-finger pinch |
| gestures.lua | gesture 4 | direction | `"pinchin"` | Pinch in |
| gestures.lua | gesture 4 | action | `function () hl.dispatch(hl.dsp.window.fullscreen({ action="unset" })) end` | Leave fullscreen |
| custom.lua | brightness rebinds | hl.unbind | `"XF86MonBrightnessUp"` | Remove default (WINS over keybindings/default.lua) |
| custom.lua | brightness rebinds | hl.bind | `"XF86MonBrightnessUp"` → `brightness.sh up`, `{ locked=true, repeating=true, description="Increase brightness" }` | 5%-step brightness |
| custom.lua | brightness rebinds | hl.unbind | `"XF86MonBrightnessDown"` | Remove default |
| custom.lua | brightness rebinds | hl.bind | `"XF86MonBrightnessDown"` → `brightness.sh down`, `{ locked=true, repeating=true, description="Decrease brightness" }` | 5%-step brightness |
| custom.lua | brightness rebinds | hl.unbind | `"SUPER + F4"` | Remove F4 default |
| custom.lua | brightness rebinds | hl.bind | `"SUPER + F4"` → `brightness.sh up`, `{ locked=true, repeating=true, description="Increase brightness" }` | Brightness up |
| custom.lua | brightness rebinds | hl.unbind | `"SUPER + F3"` | Remove F3 default |
| custom.lua | brightness rebinds | hl.bind | `"SUPER + F3"` → `brightness.sh down`, `{ locked=true, repeating=true, description="Decrease brightness" }` | Brightness down |
| custom.lua | brightness rebinds | hl.unbind | `"SUPER + F2"` | Remove F2 default |
| custom.lua | brightness rebinds | hl.bind | `"SUPER + F2"` → `brightness.sh down`, `{ locked=true, repeating=true, description="Decrease brightness" }` | Brightness down (second) |
| custom.lua | terminal bindings | hl.unbind | `"SUPER + RETURN"` | Remove terminal.sh binding |
| custom.lua | terminal bindings | hl.unbind | `"SUPER + Return"` | Case variant |
| custom.lua | terminal bindings | hl.bind | `"SUPER + RETURN"` → `hl.dsp.exec_cmd("kitty")`, `{ description="Open Kitty" }` | Final terminal = Kitty (WINS, loaded last) |
| custom.lua | terminal bindings | hl.unbind | `"SUPER + SHIFT + RETURN"` | Remove HyprMod binding |
| custom.lua | terminal bindings | hl.unbind | `"SUPER + SHIFT + Return"` | Case variant |
| custom.lua | terminal bindings | hl.bind | `"SUPER + SHIFT + RETURN"` → `hl.dsp.exec_cmd("wezterm")`, `{ description="Open WezTerm" }` | Final alt terminal = WezTerm (WINS) |
| custom.lua | terminal bindings | hl.unbind | `"SUPER + ALT + RETURN"` | Remove alt+enter |
| custom.lua | terminal bindings | hl.unbind | `"SUPER + ALT + Return"` | Case variant |
| custom.lua | window rule zen-opacity | name | `"zen-opacity"` | Named rule |
| custom.lua | window rule zen-opacity | match.class | `"^(zen)$"` | Zen Browser |
| custom.lua | window rule zen-opacity | opacity | `"1.0 1.0"` | Keep full opacity unfocused (preserve Zen transparency/blur) |
| hyprland-gui.lua | Settings → decoration | rounding | `15` | Corner radius (OVERRIDE vs decoration 10; WINS) |
| hyprland-gui.lua | Settings → decoration | rounding_power | `3.5` | Corner exponent (OVERRIDE vs 2) |
| hyprland-gui.lua | Settings → general | allow_tearing | `true` | Tearing (OVERRIDE vs window variants false; WINS) |
| hyprland-gui.lua | Settings → general.col | inactive_border | `"0xff000000"` | Black inactive border (OVERRIDE vs on_primary; WINS) |
| hyprland-gui.lua | Settings → misc | disable_hyprland_logo | `false` | Logo shown (OVERRIDE vs conf.misc true; WINS) |
| hyprland-gui.lua | Settings → misc | disable_splash_rendering | `false` | Splash shown (OVERRIDE vs conf.misc true; WINS) |
| hyprland-gui.lua | Settings → misc | force_default_wallpaper | `0` | No forced wallpaper (same as conf.misc) |
| hyprland-gui.lua | Settings → misc | vrr | `1` | Global VRR on (per-monitor eDP-1 vrr=0 wins on that output) |
| hyprland-gui.lua | Keybinds | hl.unbind | `"SUPER + CTRL + H"` | Remove prior binding |
| hyprland-gui.lua | Keybinds | hl.bind | `"SUPER + CTRL + H"` → `display-mode.sh`, `{ description="Open screen display mode menu" }` | Display menu |
| hyprland-gui.lua | Keybinds | hl.unbind | `"SUPER + SHIFT + RETURN"` | Remove prior binding |
| hyprland-gui.lua | Keybinds | hl.bind | `"SUPER + SHIFT + Return"` → `wezterm`, `{ description="Open WezTerm" }` | WezTerm (later OVERRIDDEN by custom.lua) |
| hyprmod/active_profile | profile | active_profile | `946cfc33be85` | Active HyprMod profile ID |
| hyprmod/profiles/946cfc33be85/hyprland-gui.lua | Settings → decoration | rounding | `15` | DUP (identical snapshot of top-level) |
| hyprmod/profiles/946cfc33be85/hyprland-gui.lua | Settings → decoration | rounding_power | `3.5` | DUP |
| hyprmod/profiles/946cfc33be85/hyprland-gui.lua | Settings → general | allow_tearing | `true` | DUP |
| hyprmod/profiles/946cfc33be85/hyprland-gui.lua | Settings → general.col | inactive_border | `"0xff000000"` | DUP |
| hyprmod/profiles/946cfc33be85/hyprland-gui.lua | Settings → misc | disable_hyprland_logo | `false` | DUP |
| hyprmod/profiles/946cfc33be85/hyprland-gui.lua | Settings → misc | disable_splash_rendering | `false` | DUP |
| hyprmod/profiles/946cfc33be85/hyprland-gui.lua | Settings → misc | force_default_wallpaper | `0` | DUP |
| hyprmod/profiles/946cfc33be85/hyprland-gui.lua | Settings → misc | vrr | `1` | DUP |
| hyprmod/profiles/946cfc33be85/hyprland-gui.lua | Keybinds | hl.unbind | `"SUPER + CTRL + H"` | DUP |
| hyprmod/profiles/946cfc33be85/hyprland-gui.lua | Keybinds | hl.bind | `"SUPER + CTRL + H"` → `display-mode.sh`, `{ description="Open screen display mode menu" }` | DUP |
| hyprmod/profiles/946cfc33be85/hyprland-gui.lua | Keybinds | hl.unbind | `"SUPER + SHIFT + RETURN"` | DUP |
| hyprmod/profiles/946cfc33be85/hyprland-gui.lua | Keybinds | hl.bind | `"SUPER + SHIFT + Return"` → `wezterm`, `{ description="Open WezTerm" }` | DUP |
| hyprmod/profiles/946cfc33be85/meta.json | metadata | name | `"Default"` | Profile display name |
| hyprmod/profiles/946cfc33be85/meta.json | metadata | description | `""` | Empty description |
| hyprmod/profiles/946cfc33be85/meta.json | metadata | created_at | `"2026-11-03T07:30:28+00:00"` | Creation timestamp |
| hyprmod/profiles/946cfc33be85/meta.json | metadata | modified_at | `"2026-11-17T10:34:34+00:00"` | Last modified |
| hyprmod/profiles/946cfc33be85/meta.json | metadata | snapshot | `"hyprland-gui.lua"` | Snapshot file |
| colors.lua | Material color globals | background | `"rgba(101417ff)"` | Material You token (Lua global form) |
| colors.lua | Material color globals | error | `"rgba(ffb4abff)"` | Error |
| colors.lua | Material color globals | error_container | `"rgba(93000aff)"` | Error container |
| colors.lua | Material color globals | inverse_on_surface | `"rgba(2d3135ff)"` | Inverse on-surface |
| colors.lua | Material color globals | inverse_primary | `"rgba(266489ff)"` | Inverse primary |
| colors.lua | Material color globals | inverse_surface | `"rgba(e0e3e8ff)"` | Inverse surface |
| colors.lua | Material color globals | on_background | `"rgba(e0e3e8ff)"` | On-background |
| colors.lua | Material color globals | on_error | `"rgba(690005ff)"` | On-error |
| colors.lua | Material color globals | on_error_container | `"rgba(ffdad6ff)"` | On-error-container |
| colors.lua | Material color globals | on_primary | `"rgba(00344eff)"` | On-primary (inactive border in window variants) |
| colors.lua | Material color globals | on_primary_container | `"rgba(c9e6ffff)"` | On-primary-container |
| colors.lua | Material color globals | on_primary_fixed | `"rgba(001e2fff)"` | On-primary-fixed |
| colors.lua | Material color globals | on_primary_fixed_variant | `"rgba(004b6fff)"` | On-primary-fixed-variant |
| colors.lua | Material color globals | on_secondary | `"rgba(22323fff)"` | On-secondary |
| colors.lua | Material color globals | on_secondary_container | `"rgba(d3e5f5ff)"` | On-secondary-container |
| colors.lua | Material color globals | on_secondary_fixed | `"rgba(0c1d29ff)"` | On-secondary-fixed |
| colors.lua | Material color globals | on_secondary_fixed_variant | `"rgba(384956ff)"` | On-secondary-fixed-variant |
| colors.lua | Material color globals | on_surface | `"rgba(e0e3e8ff)"` | On-surface |
| colors.lua | Material color globals | on_surface_variant | `"rgba(c1c7ceff)"` | On-surface-variant |
| colors.lua | Material color globals | on_tertiary | `"rgba(352b4bff)"` | On-tertiary |
| colors.lua | Material color globals | on_tertiary_container | `"rgba(eaddffff)"` | On-tertiary-container |
| colors.lua | Material color globals | on_tertiary_fixed | `"rgba(201634ff)"` | On-tertiary-fixed |
| colors.lua | Material color globals | on_tertiary_fixed_variant | `"rgba(4c4162ff)"` | On-tertiary-fixed-variant |
| colors.lua | Material color globals | outline | `"rgba(8b9198ff)"` | Outline |
| colors.lua | Material color globals | outline_variant | `"rgba(41474dff)"` | Outline variant |
| colors.lua | Material color globals | primary | `"rgba(95cdf7ff)"` | Primary (active border in window variants) |
| colors.lua | Material color globals | primary_container | `"rgba(004b6fff)"` | Primary container |
| colors.lua | Material color globals | primary_fixed | `"rgba(c9e6ffff)"` | Primary fixed |
| colors.lua | Material color globals | primary_fixed_dim | `"rgba(95cdf7ff)"` | Dimmed primary fixed |
| colors.lua | Material color globals | scrim | `"rgba(000000ff)"` | Scrim |
| colors.lua | Material color globals | secondary | `"rgba(b7c9d9ff)"` | Secondary |
| colors.lua | Material color globals | secondary_container | `"rgba(384956ff)"` | Secondary container |
| colors.lua | Material color globals | secondary_fixed | `"rgba(d3e5f5ff)"` | Secondary fixed |
| colors.lua | Material color globals | secondary_fixed_dim | `"rgba(b7c9d9ff)"` | Dimmed secondary fixed |
| colors.lua | Material color globals | shadow | `"rgba(000000ff)"` | Shadow |
| colors.lua | Material color globals | source_color | `"rgba(2f5671ff)"` | Seed source color |
| colors.lua | Material color globals | surface | `"rgba(101417ff)"` | Surface |
| colors.lua | Material color globals | surface_bright | `"rgba(363a3eff)"` | Bright surface |
| colors.lua | Material color globals | surface_container | `"rgba(1c2024ff)"` | Surface container |
| colors.lua | Material color globals | surface_container_high | `"rgba(262a2eff)"` | High surface container |
| colors.lua | Material color globals | surface_container_highest | `"rgba(313539ff)"` | Highest surface container |
| colors.lua | Material color globals | surface_container_low | `"rgba(181c20ff)"` | Low surface container |
| colors.lua | Material color globals | surface_container_lowest | `"rgba(0b0f12ff)"` | Lowest surface container |
| colors.lua | Material color globals | surface_dim | `"rgba(101417ff)"` | Dim surface |
| colors.lua | Material color globals | surface_tint | `"rgba(95cdf7ff)"` | Surface tint |
| colors.lua | Material color globals | surface_variant | `"rgba(41474dff)"` | Surface variant |
| colors.lua | Material color globals | tertiary | `"rgba(cfc0e8ff)"` | Tertiary |
| colors.lua | Material color globals | tertiary_container | `"rgba(4c4162ff)"` | Tertiary container |
| colors.lua | Material color globals | tertiary_fixed | `"rgba(eaddffff)"` | Tertiary fixed |
| colors.lua | Material color globals | tertiary_fixed_dim | `"rgba(cfc0e8ff)"` | Dimmed tertiary fixed |
| colors.conf | Material color variables | $background | `rgba(101417ff)` | DUP of colors.lua in hyprlang `$var` form; sourced by hyprlock.conf |
| colors.conf | Material color variables | $error | `rgba(ffb4abff)` | DUP |
| colors.conf | Material color variables | $error_container | `rgba(93000aff)` | DUP |
| colors.conf | Material color variables | $inverse_on_surface | `rgba(2d3135ff)` | DUP |
| colors.conf | Material color variables | $inverse_primary | `rgba(266489ff)` | DUP |
| colors.conf | Material color variables | $inverse_surface | `rgba(e0e3e8ff)` | DUP |
| colors.conf | Material color variables | $on_background | `rgba(e0e3e8ff)` | DUP |
| colors.conf | Material color variables | $on_error | `rgba(690005ff)` | DUP |
| colors.conf | Material color variables | $on_error_container | `rgba(ffdad6ff)` | DUP |
| colors.conf | Material color variables | $on_primary | `rgba(00344eff)` | DUP |
| colors.conf | Material color variables | $on_primary_container | `rgba(c9e6ffff)` | DUP |
| colors.conf | Material color variables | $on_primary_fixed | `rgba(001e2fff)` | DUP |
| colors.conf | Material color variables | $on_primary_fixed_variant | `rgba(004b6fff)` | DUP |
| colors.conf | Material color variables | $on_secondary | `rgba(22323fff)` | DUP |
| colors.conf | Material color variables | $on_secondary_container | `rgba(d3e5f5ff)` | DUP |
| colors.conf | Material color variables | $on_secondary_fixed | `rgba(0c1d29ff)` | DUP |
| colors.conf | Material color variables | $on_secondary_fixed_variant | `rgba(384956ff)` | DUP |
| colors.conf | Material color variables | $on_surface | `rgba(e0e3e8ff)` | DUP |
| colors.conf | Material color variables | $on_surface_variant | `rgba(c1c7ceff)` | DUP |
| colors.conf | Material color variables | $on_tertiary | `rgba(352b4bff)` | DUP |
| colors.conf | Material color variables | $on_tertiary_container | `rgba(eaddffff)` | DUP |
| colors.conf | Material color variables | $on_tertiary_fixed | `rgba(201634ff)` | DUP |
| colors.conf | Material color variables | $on_tertiary_fixed_variant | `rgba(4c4162ff)` | DUP |
| colors.conf | Material color variables | $outline | `rgba(8b9198ff)` | DUP |
| colors.conf | Material color variables | $outline_variant | `rgba(41474dff)` | DUP |
| colors.conf | Material color variables | $primary | `rgba(95cdf7ff)` | DUP |
| colors.conf | Material color variables | $primary_container | `rgba(004b6fff)` | DUP |
| colors.conf | Material color variables | $primary_fixed | `rgba(c9e6ffff)` | DUP |
| colors.conf | Material color variables | $primary_fixed_dim | `rgba(95cdf7ff)` | DUP |
| colors.conf | Material color variables | $scrim | `rgba(000000ff)` | DUP |
| colors.conf | Material color variables | $secondary | `rgba(b7c9d9ff)` | DUP |
| colors.conf | Material color variables | $secondary_container | `rgba(384956ff)` | DUP |
| colors.conf | Material color variables | $secondary_fixed | `rgba(d3e5f5ff)` | DUP |
| colors.conf | Material color variables | $secondary_fixed_dim | `rgba(b7c9d9ff)` | DUP |
| colors.conf | Material color variables | $shadow | `rgba(000000ff)` | DUP |
| colors.conf | Material color variables | $source_color | `rgba(2f5671ff)` | DUP |
| colors.conf | Material color variables | $surface | `rgba(101417ff)` | DUP |
| colors.conf | Material color variables | $surface_bright | `rgba(363a3eff)` | DUP |
| colors.conf | Material color variables | $surface_container | `rgba(1c2024ff)` | DUP |
| colors.conf | Material color variables | $surface_container_high | `rgba(262a2eff)` | DUP |
| colors.conf | Material color variables | $surface_container_highest | `rgba(313539ff)` | DUP |
| colors.conf | Material color variables | $surface_container_low | `rgba(181c20ff)` | DUP |
| colors.conf | Material color variables | $surface_container_lowest | `rgba(0b0f12ff)` | DUP |
| colors.conf | Material color variables | $surface_dim | `rgba(101417ff)` | DUP |
| colors.conf | Material color variables | $surface_tint | `rgba(95cdf7ff)` | DUP |
| colors.conf | Material color variables | $surface_variant | `rgba(41474dff)` | DUP |
| colors.conf | Material color variables | $tertiary | `rgba(cfc0e8ff)` | DUP |
| colors.conf | Material color variables | $tertiary_container | `rgba(4c4162ff)` | DUP |
| colors.conf | Material color variables | $tertiary_fixed | `rgba(eaddffff)` | DUP |
| colors.conf | Material color variables | $tertiary_fixed_dim | `rgba(cfc0e8ff)` | DUP |
| conf/ml4w.lua | PATH | hl.env PATH (local bin) | `HOME .. "/.local/bin:" .. current_path` | Prepend ~/.local/bin |
| conf/ml4w.lua | PATH | hl.env PATH (cargo bin) | `HOME .. "/.cargo/bin:" .. current_path` | Prepend ~/.cargo/bin (second assignment; both retained) |
| conf/ml4w.lua | window rule pavucontrol | name | `"pavucontrol"` | Named rule |
| conf/ml4w.lua | window rule pavucontrol | match.class | `".*org.pulseaudio.pavucontrol.*"` | Volume control |
| conf/ml4w.lua | window rule pavucontrol | float / center / size | `true / true / "700 600"` | Floating, centered, sized |
| conf/ml4w.lua | window rule ml4w-welcome-app | name | `"ml4w-welcome-app"` | Named rule |
| conf/ml4w.lua | window rule ml4w-welcome-app | match.title | `"ML4W Welcome"` | Welcome dialog |
| conf/ml4w.lua | window rule ml4w-welcome-app | float / center / pin / size | `true / true / true / "700 640"` | Floating, centered, pinned |
| conf/ml4w.lua | window rule ml4w-dock-settings | name | `"ml4w-dock-settings"` | Named rule |
| conf/ml4w.lua | window rule ml4w-dock-settings | match.title | `"ML4W Dock Settings"` | Quickshell dock dialog |
| conf/ml4w.lua | window rule ml4w-dock-settings | float / center / pin / size | `true / true / true / "480 300"` | Floating, centered, pinned |
| conf/ml4w.lua | window rule ml4w-settings-app | name | `"ml4w-settings-app"` | Named rule |
| conf/ml4w.lua | window rule ml4w-settings-app | match.title | `"ML4W Dotfiles Settings"` | Settings app |
| conf/ml4w.lua | window rule ml4w-settings-app | float / center / pin / size | `true / true / true / "900 600"` | Floating, centered, pinned |
| conf/ml4w.lua | window rule newelle | name | `"newelle"` | Named rule |
| conf/ml4w.lua | window rule newelle | match.class | `"io.github.qwersyk.Newelle"` | Newelle AI app |
| conf/ml4w.lua | window rule newelle | float / center / pin / size | `true / true / true / "1000 700"` | Floating, centered, pinned |
| conf/ml4w.lua | window rule blueman-manager | name | `"blueman-manager"` | Named rule |
| conf/ml4w.lua | window rule blueman-manager | match.class | `"blueman-manager"` | Bluetooth manager |
| conf/ml4w.lua | window rule blueman-manager | float / center / size | `true / true / "800 600"` | Floating, centered |
| conf/ml4w.lua | window rule nwg-look | name | `"nwg-look"` | Named rule |
| conf/ml4w.lua | window rule nwg-look | match.class | `"nwg-look"` | GTK theme tool |
| conf/ml4w.lua | window rule nwg-look | float / center / size | `true / true / "700 600"` | Floating, centered |
| conf/ml4w.lua | window rule nwg-displays | name | `"nwg-displays"` | Named rule |
| conf/ml4w.lua | window rule nwg-displays | match.class | `"nwg-displays"` | Display tool |
| conf/ml4w.lua | window rule nwg-displays | float / center / size | `true / true / "900 600"` | Floating, centered |
| conf/ml4w.lua | window rule missioncenter | name | `"missioncenter"` | Named rule |
| conf/ml4w.lua | window rule missioncenter | match.class | `"io.missioncenter.MissionCenter"` | System monitor |
| conf/ml4w.lua | window rule missioncenter | float / center / pin / size | `true / true / true / "900 600"` | Floating, centered, pinned |
| conf/ml4w.lua | window rule gnome-calculator | name | `"gnome-calculator"` | Named rule |
| conf/ml4w.lua | window rule gnome-calculator | match.class | `"org.gnome.Calculator"` | Calculator |
| conf/ml4w.lua | window rule gnome-calculator | float / center / size | `true / true / "700 600"` | Floating, centered |
| conf/ml4w.lua | window rule hyprland-share-picker | name | `"hyprland-share-picker"` | Named rule |
| conf/ml4w.lua | window rule hyprland-share-picker | match.class | `"hyprland-share-picker"` | Screen-share picker |
| conf/ml4w.lua | window rule hyprland-share-picker | float / pin / center / size | `true / true / true / "600 400"` | Floating, pinned, centered |
| conf/ml4w.lua | window rule xdg-desktop-portal-gtk | name | `"xdg-desktop-portal-gtk"` | Named rule |
| conf/ml4w.lua | window rule xdg-desktop-portal-gtk | match.class | `"xdg-desktop-portal-gtk"` | GTK file/folder picker |
| conf/ml4w.lua | window rule xdg-desktop-portal-gtk | float / center / size | `true / false / "800 600"` | Floating, NOT centered |
| conf/ml4w.lua | window rule nm-connection-editor | name | `"nm-connection-editor"` | Named rule |
| conf/ml4w.lua | window rule nm-connection-editor | match.class | `"nm-connection-editor"` | Network editor |
| conf/ml4w.lua | window rule nm-connection-editor | float / center / size | `true / true / "800 700"` | Floating, centered |
| conf/ml4w.lua | window rule hyprmod | name | `"io.github.bluemancz.hyprmod"` | Named rule |
| conf/ml4w.lua | window rule hyprmod | match.class | `"io.github.bluemancz.hyprmod"` | HyprMod GUI |
| conf/ml4w.lua | window rule hyprmod | float / center / size | `true / true / "1000 700"` | Floating, centered |
| conf/ml4w.lua | window rule dotfiles-floating | name | `"dotfiles-floating"` | Named rule (ML4W terminal launchers) |
| conf/ml4w.lua | window rule dotfiles-floating | match.class | `"dotfiles-floating"` | ML4W floating class |
| conf/ml4w.lua | window rule dotfiles-floating | float / center / size | `true / true / "1000 700"` | Floating, centered |
| conf/ml4w.lua | window mode | name | `"ml4w-window-mode-floating"` | Runtime-togglable rule |
| conf/ml4w.lua | window mode | match.class | `".*"` | Match all when enabled |
| conf/ml4w.lua | window mode | float | `true` | Float every new window |
| conf/ml4w.lua | window mode | set_enabled | `mode == "floating"` | Enable only in floating mode |
| conf/ml4w.lua | window mode | settings file | `HOME .. "/.config/ml4w/settings/window-mode"` | Read stored mode |
| conf/ml4w.lua | window mode | fallback value | `"tiling"` | Default if file missing |
| conf/ml4w.lua | window rule Picture-in-Picture | name | `"Picture-in-Picture"` | Named rule |
| conf/ml4w.lua | window rule Picture-in-Picture | match.title | `[[^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture)(.*)$]]` | Match PiP windows |
| conf/ml4w.lua | window rule Picture-in-Picture | float / pin / focus_on_activate / no_initial_focus / suppress_event | `true / true / false / true / "activate"` | No focus steal |
| conf/ml4w.lua | window rule xwaylandvideobridge | name | `"xwaylandvideobridge"` | Named rule |
| conf/ml4w.lua | window rule xwaylandvideobridge | match.class | `"^(xwaylandvideobridge)$"` | Video bridge |
| conf/ml4w.lua | window rule xwaylandvideobridge | opacity | `"0.0 override 0.0 override"` | Fully transparent |
| conf/ml4w.lua | window rule xwaylandvideobridge | no_anim / no_initial_focus / max_size / no_blur / float | `true / true / "1 1" / true / true` | Hidden 1x1 float |
| conf/ml4w.lua | layer rule | match.namespace | `"ml4w-powermenu"` | Power menu layer |
| conf/ml4w.lua | layer rule | no_anim | `true` | No animation |
| conf/ml4w.lua | Wayland env | OZONE_PLATFORM | `"wayland"` | Chromium/Electron backend |
| conf/ml4w.lua | Wayland env | ELECTRON_OZONE_PLATFORM_HINT | `"wayland"` | Electron hint |
| conf/ml4w.lua | Wayland env | DESKTOP_SESSION | `"Hyprland"` | Session name |
| conf/ml4w.lua | Wayland env | XDG_SESSION_TYPE | `"wayland"` | DUP: set again at line 218, same value |
| conf/ml4w.lua | Qt env | QT_QPA_PLATFORM | `"wayland;xcb"` | Qt platform preference |
| conf/ml4w.lua | Qt env | QT_QPA_PLATFORMTHEME | `"qt6ct"` | Qt theme module |
| conf/ml4w.lua | Qt env | QT_WAYLAND_DISABLE_WINDOWDECORATION | `"1"` | Disable Qt decorations |
| conf/ml4w.lua | Wayland env | XDG_CURRENT_DESKTOP | `"Hyprland"` | Desktop name |
| conf/ml4w.lua | Wayland env | XDG_SESSION_TYPE (second) | `"wayland"` | DUP of line 210; same value, harmless |
| conf/ml4w.lua | Wayland env | XDG_SESSION_DESKTOP | `"Hyprland"` | Session desktop |
| conf/ml4w.lua | GDK env | GDK_SCALE | `"1"` | GTK scaling |
| conf/ml4w.lua | Toolkit backend | GDK_BACKEND | `"wayland,x11,*"` | GTK backend priority |
| conf/ml4w.lua | Toolkit backend | CLUTTER_BACKEND | `"wayland"` | Clutter backend |
| conf/ml4w.lua | Mozilla env | MOZ_ENABLE_WAYLAND | `"1"` | Firefox Wayland |
| conf/ml4w.lua | Cursor env | XCURSOR_THEME | `"Bibata-Modern-Ice"` | Cursor theme |
| conf/ml4w.lua | Cursor env | XCURSOR_SIZE | `"24"` | Cursor size |
| conf/ml4w.lua | Cursor env | HYPRCURSOR_SIZE | `"24"` | Hyprland cursor size |
| conf/ml4w.lua | SDL env | SDL_VIDEODRIVER | `"wayland"` | SDL backend |
| conf/ml4w.lua | Quickshell debug | QS_NO_RELOAD_POPUP | `"1"` | Suppress reload popup |
| conf/ml4w.lua | xwayland | force_zero_scaling | `true` | XWayland zero scaling |
| conf/animation.lua | variant selector | name | `"animations-fast.lua"` | ACTIVE animation profile |
| conf/animation.lua | variant selector | load_variant | `load_variant(name,"animations")` | → conf/animations/animations-fast.lua |
| conf/autostart.lua | hyprland.start | wallpaper_app default | `"quickshell"` | Default before reading setting |
| conf/autostart.lua | hyprland.start | settings file | `HOME .. "/.config/ml4w/settings/wallpaper-app"` | Read wallpaper app |
| conf/autostart.lua | hyprland.start | dbus env | `dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP` | Export to systemd |
| conf/autostart.lua | hyprland.start | portal restart | `systemctl --user stop xdg-desktop-portal xdg-desktop-portal-hyprland` then `start ...` | Restart portals |
| conf/autostart.lua | hyprland.start | awww daemon | `awww-daemon` | Start awww |
| conf/autostart.lua | hyprland.start | cursor | `hyprctl setcursor Bibata-Modern-Ice 24` | Set cursor |
| conf/autostart.lua | hyprland.start | listeners | `~/.config/ml4w/listeners.sh --startall` | Start listeners |
| conf/autostart.lua | hyprland.start | waybar | `HOME .. "/.config/waybar/launch.sh"` | Start bar |
| conf/autostart.lua | hyprland.start | polkit agent | `systemctl --user start hyprpolkitagent.service 2>/dev/null \|\| /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 \|\| true` | Exactly one polkit agent |
| conf/autostart.lua | hyprland.start | wallpaper guard | `if wallpaper_app ~= "quickshell"` | Skip restore for quickshell |
| conf/autostart.lua | hyprland.start | wallpaper restore | `~/.config/ml4w/scripts/ml4w-wallpaper-app --restore` | Restore wallpaper |
| conf/autostart.lua | hyprland.start | log dir | `"$HOME/.local/state/ml4w-os-hyprland"` | Log location |
| conf/autostart.lua | hyprland.start | log retention | `ls -1r ... \| tail -n +10 \| xargs -r rm -f` | Keep last 10 logs |
| conf/autostart.lua | hyprland.start | autostart script | `~/.config/ml4w/scripts/ml4w-autostart` | Main autostart |
| conf/autostart.lua | hyprland.start | GTK settings | `~/.config/hypr/scripts/gtk.sh` | Apply GTK |
| conf/autostart.lua | hyprland.start | swaync guard | `[ -f ~/.config/ml4w/.swaync-dbus-activated ] \|\| swaync` | Start swaync unless D-Bus activated |
| conf/autostart.lua | hyprland.start | hypridle | `hypridle` | Start idle daemon |
| conf/autostart.lua | hyprland.start | clipboard | `wl-paste --watch cliphist store` | Persist clipboard |
| conf/autostart.lua | hyprland.start | cleanup | `~/.config/hypr/scripts/cleanup.sh` | Remove gamemode flag |
| conf/decoration.lua | variant selector | name | `"default.lua"` | ACTIVE decoration |
| conf/decoration.lua | variant selector | load_variant | `load_variant(name,"decorations")` | → conf/decorations/default.lua |
| conf/environment.lua | QS icon theme | source file | `os.getenv("HOME") .. "/.config/gtk-3.0/settings.ini"` | Read GTK icon theme |
| conf/environment.lua | QS icon theme | match pattern | `"^%s*gtk%-icon%-theme%-name%s*=%s*(.-)%s*$"` | Extract theme name |
| conf/environment.lua | QS icon theme | hl.env QS_ICON_THEME | `theme` (from settings.ini) | Quickshell icon theme |
| conf/environment.lua | variant selector | name | `"default.lua"` | ACTIVE environment (empty) |
| conf/environment.lua | variant selector | load_variant | `load_variant(name,"environments")` | → conf/environments/default.lua |
| conf/keybinding.lua | variant selector | name | `"default.lua"` | ACTIVE keybinding |
| conf/keybinding.lua | variant selector | load_variant | `load_variant(name,"keybindings")` | → conf/keybindings/default.lua |
| conf/layout.lua | variant selector | name | `"laptop.lua"` | ACTIVE layout |
| conf/layout.lua | variant selector | load_variant | `load_variant(name,"layouts")` | → conf/layouts/laptop.lua |
| conf/misc.lua | misc | disable_hyprland_logo | `true` | Hide logo (OVERRIDDEN to false by hyprland-gui.lua) |
| conf/misc.lua | misc | force_default_wallpaper | `0` | No forced wallpaper |
| conf/misc.lua | misc | disable_splash_rendering | `true` | No splash (OVERRIDDEN to false) |
| conf/misc.lua | misc | initial_workspace_tracking | `1` | Track initial workspace |
| conf/misc.lua | misc | on_focus_under_fullscreen | `1` | Allow focus under fullscreen |
| conf/misc.lua | misc | allow_session_lock_restore | `true` | Restore after lock |
| conf/monitor.lua | variant selector | name | `"1920x1080.lua"` | ACTIVE monitor |
| conf/monitor.lua | variant selector | load_variant | `load_variant(name,"monitors")` | → conf/monitors/1920x1080.lua |
| conf/window.lua | variant selector | name | `"glass.lua"` | ACTIVE window |
| conf/window.lua | variant selector | load_variant | `load_variant(name,"windows")` | → conf/windows/glass.lua |
| conf/windowrule.lua | variant selector | name | `"default.lua"` | ACTIVE windowrule (empty) |
| conf/windowrule.lua | variant selector | load_variant | `load_variant(name,"windowrules")` | → conf/windowrules/default.lua |
| conf/workspace.lua | variant selector | name | `"default.lua"` | ACTIVE workspace (empty) |
| conf/workspace.lua | variant selector | load_variant | `load_variant(name,"workspaces")` | → conf/workspaces/default.lua |
| conf/animations/animations-classic.lua | "Classic" | animations.enabled | `true` | Master switch |
| conf/animations/animations-classic.lua | "Classic" | curve myBezier | `{ type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } }` | Custom bezier |
| conf/animations/animations-classic.lua | "Classic" | animation windows | `{ enabled=true, speed=7, bezier="myBezier" }` | Window open/close |
| conf/animations/animations-classic.lua | "Classic" | animation windowsOut | `{ enabled=true, speed=7, bezier="default", style="popin 80%" }` | Window close |
| conf/animations/animations-classic.lua | "Classic" | animation border | `{ enabled=true, speed=10, bezier="default" }` | Border color |
| conf/animations/animations-classic.lua | "Classic" | animation borderangle | `{ enabled=true, speed=8, bezier="default" }` | Border angle |
| conf/animations/animations-classic.lua | "Classic" | animation fade | `{ enabled=true, speed=7, bezier="default" }` | Fade |
| conf/animations/animations-classic.lua | "Classic" | animation workspaces | `{ enabled=true, speed=6, bezier="default" }` | Workspaces |
| conf/animations/animations-dynamic.lua | "Dynamic" | animations.enabled | `true` | Master switch |
| conf/animations/animations-dynamic.lua | "Dynamic" | curve wind | `{ {0.05, 0.9}, {0.1, 1.05} }` | Wind bezier |
| conf/animations/animations-dynamic.lua | "Dynamic" | curve winIn | `{ {0.1, 1.1}, {0.1, 1.1} }` | Window in |
| conf/animations/animations-dynamic.lua | "Dynamic" | curve winOut | `{ {0.3, -0.3}, {0, 1} }` | Window out |
| conf/animations/animations-dynamic.lua | "Dynamic" | curve liner | `{ {1, 1}, {1, 1} }` | Linear |
| conf/animations/animations-dynamic.lua | "Dynamic" | animation windows | `{ enabled=true, speed=6, bezier="wind", style="slide" }` | Window slide |
| conf/animations/animations-dynamic.lua | "Dynamic" | animation windowsIn | `{ enabled=true, speed=6, bezier="winIn", style="slide" }` | Window in |
| conf/animations/animations-dynamic.lua | "Dynamic" | animation windowsOut | `{ enabled=true, speed=5, bezier="winOut", style="slide" }` | Window out |
| conf/animations/animations-dynamic.lua | "Dynamic" | animation windowsMove | `{ enabled=true, speed=5, bezier="wind", style="slide" }` | Window move |
| conf/animations/animations-dynamic.lua | "Dynamic" | animation border | `{ enabled=true, speed=1, bezier="liner" }` | Border |
| conf/animations/animations-dynamic.lua | "Dynamic" | animation borderangle | `{ enabled=true, speed=30, bezier="liner", style="loop" }` | Border angle loop |
| conf/animations/animations-dynamic.lua | "Dynamic" | animation fade | `{ enabled=true, speed=10, bezier="default" }` | Fade |
| conf/animations/animations-dynamic.lua | "Dynamic" | animation workspaces | `{ enabled=true, speed=5, bezier="wind" }` | Workspaces |
| conf/animations/animations-end4.lua | "End-4" (credit end-4/dots-hyprland) | animations.enabled | `true` | Master switch |
| conf/animations/animations-end4.lua | "End-4" | curve linear | `{ {0, 0}, {1, 1} }` | Linear |
| conf/animations/animations-end4.lua | "End-4" | curve md3_standard | `{ {0.2, 0}, {0, 1} }` | MD3 standard |
| conf/animations/animations-end4.lua | "End-4" | curve md3_decel | `{ {0.05, 0.7}, {0.1, 1} }` | MD3 decel |
| conf/animations/animations-end4.lua | "End-4" | curve md3_accel | `{ {0.3, 0}, {0.8, 0.15} }` | MD3 accel |
| conf/animations/animations-end4.lua | "End-4" | curve overshot | `{ {0.05, 0.9}, {0.1, 1.1} }` | Overshoot |
| conf/animations/animations-end4.lua | "End-4" | curve crazyshot | `{ {0.1, 1.5}, {0.76, 0.92} }` | Heavy overshoot |
| conf/animations/animations-end4.lua | "End-4" | curve hyprnostretch | `{ {0.05, 0.9}, {0.1, 1.0} }` | No-stretch |
| conf/animations/animations-end4.lua | "End-4" | curve menu_decel | `{ {0.1, 1}, {0, 1} }` | Menu decel |
| conf/animations/animations-end4.lua | "End-4" | curve menu_accel | `{ {0.38, 0.04}, {1, 0.07} }` | Menu accel |
| conf/animations/animations-end4.lua | "End-4" | curve easeInOutCirc | `{ {0.85, 0}, {0.15, 1} }` | Circular in/out |
| conf/animations/animations-end4.lua | "End-4" | curve easeOutCirc | `{ {0, 0.55}, {0.45, 1} }` | Circular out |
| conf/animations/animations-end4.lua | "End-4" | curve easeOutExpo | `{ {0.16, 1}, {0.3, 1} }` | Expo out |
| conf/animations/animations-end4.lua | "End-4" | curve softAcDecel | `{ {0.26, 0.26}, {0.15, 1} }` | Soft decel |
| conf/animations/animations-end4.lua | "End-4" | curve md2 | `{ {0.4, 0}, {0.2, 1} }` | MD2 curve |
| conf/animations/animations-end4.lua | "End-4" | animation windows | `{ speed=3, bezier="md3_decel", style="popin 60%", enabled=true }` | Window open |
| conf/animations/animations-end4.lua | "End-4" | animation windowsIn | `{ speed=3, bezier="md3_decel", style="popin 60%", enabled=true }` | Window in |
| conf/animations/animations-end4.lua | "End-4" | animation windowsOut | `{ speed=3, bezier="md3_accel", style="popin 60%", enabled=true }` | Window out |
| conf/animations/animations-end4.lua | "End-4" | animation border | `{ speed=10, bezier="default", enabled=true }` | Border |
| conf/animations/animations-end4.lua | "End-4" | animation fade | `{ speed=3, bezier="md3_decel", enabled=true }` | Fade |
| conf/animations/animations-end4.lua | "End-4" | animation layersIn | `{ speed=3, bezier="menu_decel", style="slide", enabled=true }` | Layer in |
| conf/animations/animations-end4.lua | "End-4" | animation layersOut | `{ speed=1.6, bezier="menu_accel", enabled=true }` | Layer out |
| conf/animations/animations-end4.lua | "End-4" | animation fadeLayersIn | `{ speed=2, bezier="menu_decel", enabled=true }` | Layer fade in |
| conf/animations/animations-end4.lua | "End-4" | animation fadeLayersOut | `{ speed=4.5, bezier="menu_accel", enabled=true }` | Layer fade out |
| conf/animations/animations-end4.lua | "End-4" | animation workspaces | `{ speed=7, bezier="menu_decel", style="slide", enabled=true }` | Workspace slide |
| conf/animations/animations-end4.lua | "End-4" | animation specialWorkspace | `{ speed=3, bezier="md3_decel", style="slidevert", enabled=true }` | Scratchpad |
| conf/animations/animations-fast.lua | "Fast" — ACTIVE | animations.enabled | `true` | Master switch |
| conf/animations/animations-fast.lua | "Fast" | curve linear | `{ {0, 0}, {1, 1} }` | Linear |
| conf/animations/animations-fast.lua | "Fast" | curve md3_standard | `{ {0.2, 0}, {0, 1} }` | MD3 standard |
| conf/animations/animations-fast.lua | "Fast" | curve md3_decel | `{ {0.05, 0.7}, {0.1, 1} }` | MD3 decel |
| conf/animations/animations-fast.lua | "Fast" | curve md3_accel | `{ {0.3, 0}, {0.8, 0.15} }` | MD3 accel |
| conf/animations/animations-fast.lua | "Fast" | curve overshot | `{ {0.05, 0.9}, {0.1, 1.1} }` | Overshoot |
| conf/animations/animations-fast.lua | "Fast" | curve crazyshot | `{ {0.1, 1.5}, {0.76, 0.92} }` | Crazyshot |
| conf/animations/animations-fast.lua | "Fast" | curve hyprnostretch | `{ {0.05, 0.9}, {0.1, 1.0} }` | Hyprnostretch |
| conf/animations/animations-fast.lua | "Fast" | curve fluent_decel | `{ {0.1, 1}, {0, 1} }` | Fluent decel |
| conf/animations/animations-fast.lua | "Fast" | curve easeInOutCirc | `{ {0.85, 0}, {0.15, 1} }` | Circular in/out |
| conf/animations/animations-fast.lua | "Fast" | curve easeOutCirc | `{ {0, 0.55}, {0.45, 1} }` | Circular out |
| conf/animations/animations-fast.lua | "Fast" | curve easeOutExpo | `{ {0.16, 1}, {0.3, 1} }` | Expo out |
| conf/animations/animations-fast.lua | "Fast" | animation windows | `{ speed=3, bezier="md3_decel", style="popin 60%", enabled=true }` | Window open |
| conf/animations/animations-fast.lua | "Fast" | animation border | `{ speed=10, bezier="default", enabled=true }` | Border |
| conf/animations/animations-fast.lua | "Fast" | animation fade | `{ speed=2.5, bezier="md3_decel", enabled=true }` | Fade |
| conf/animations/animations-fast.lua | "Fast" | animation workspaces | `{ speed=3.5, bezier="easeOutExpo", style="slide", enabled=true }` | Workspace slide |
| conf/animations/animations-fast.lua | "Fast" | animation specialWorkspace | `{ speed=3, bezier="md3_decel", style="slidevert", enabled=true }` | Scratchpad |
| conf/animations/animations-high.lua | "High" | animations.enabled | `true` | Master switch |
| conf/animations/animations-high.lua | "High" | curve wind | `{ {0.05, 0.9}, {0.1, 1.05} }` | Wind |
| conf/animations/animations-high.lua | "High" | curve winIn | `{ {0.1, 1.1}, {0.1, 1.1} }` | Window in |
| conf/animations/animations-high.lua | "High" | curve winOut | `{ {0.3, -0.3}, {0, 1} }` | Window out |
| conf/animations/animations-high.lua | "High" | curve liner | `{ {1, 1}, {1, 1} }` | Linear |
| conf/animations/animations-high.lua | "High" | animation windows | `{ speed=6, bezier="wind", style="slide", enabled=true }` | Window slide (same as Dynamic) |
| conf/animations/animations-high.lua | "High" | animation windowsIn | `{ speed=6, bezier="winIn", style="slide", enabled=true }` | Window in |
| conf/animations/animations-high.lua | "High" | animation windowsOut | `{ speed=5, bezier="winOut", style="slide", enabled=true }` | Window out |
| conf/animations/animations-high.lua | "High" | animation windowsMove | `{ speed=5, bezier="wind", style="slide", enabled=true }` | Window move |
| conf/animations/animations-high.lua | "High" | animation border | `{ speed=1, bezier="liner", enabled=true }` | Border |
| conf/animations/animations-high.lua | "High" | animation borderangle | `{ speed=30, bezier="liner", style="loop", enabled=true }` | Border angle loop |
| conf/animations/animations-high.lua | "High" | animation fade | `{ speed=10, bezier="default", enabled=true }` | Fade |
| conf/animations/animations-high.lua | "High" | animation workspaces | `{ speed=5, bezier="wind", enabled=true }` | Workspaces |
| conf/animations/animations-moving.lua | "Moving" | animations.enabled | `true` | Master switch |
| conf/animations/animations-moving.lua | "Moving" | curve overshot | `{ {0.05, 0.9}, {0.1, 1.05} }` | Overshoot |
| conf/animations/animations-moving.lua | "Moving" | curve smoothOut | `{ {0.5, 0}, {0.99, 0.99} }` | Smooth out |
| conf/animations/animations-moving.lua | "Moving" | curve smoothIn | `{ {0.5, -0.5}, {0.68, 1.5} }` | Smooth in |
| conf/animations/animations-moving.lua | "Moving" | animation windows | `{ speed=5, bezier="overshot", style="slide", enabled=true }` | Window slide |
| conf/animations/animations-moving.lua | "Moving" | animation windowsOut | `{ speed=3, bezier="smoothOut", enabled=true }` | Window out |
| conf/animations/animations-moving.lua | "Moving" | animation windowsIn | `{ speed=3, bezier="smoothOut", enabled=true }` | Window in |
| conf/animations/animations-moving.lua | "Moving" | animation windowsMove | `{ speed=4, bezier="smoothIn", style="slide", enabled=true }` | Window move |
| conf/animations/animations-moving.lua | "Moving" | animation border | `{ speed=5, bezier="default", enabled=true }` | Border |
| conf/animations/animations-moving.lua | "Moving" | animation fade | `{ speed=5, bezier="smoothIn", enabled=true }` | Fade |
| conf/animations/animations-moving.lua | "Moving" | animation fadeDim | `{ speed=5, bezier="smoothIn", enabled=true }` | Fade dim |
| conf/animations/animations-moving.lua | "Moving" | animation workspaces | `{ speed=6, bezier="default", enabled=true }` | Workspaces |
| conf/animations/animations-smooth.lua | "Smooth" | animations.enabled | `true` | Master switch |
| conf/animations/animations-smooth.lua | "Smooth" | curve overshot | `{ {0.05, 0.9}, {0.1, 1.05} }` | Overshoot |
| conf/animations/animations-smooth.lua | "Smooth" | curve easeOutExpo | `{ {0.16, 1}, {0.3, 1} }` | Expo out |
| conf/animations/animations-smooth.lua | "Smooth" | curve easeOutBack | `{ {0.34, 1.56}, {0.64, 1} }` | Back out |
| conf/animations/animations-smooth.lua | "Smooth" | curve easeInBack | `{ {0.36, 0}, {0.66, -0.56} }` | Back in |
| conf/animations/animations-smooth.lua | "Smooth" | curve easeInOutBack | `{ {0.68, -0.6}, {0.32, 1.6} }` | Back in/out |
| conf/animations/animations-smooth.lua | "Smooth" | animation windows | `{ speed=3, bezier="overshot", style="slide", enabled=true }` | Window slide |
| conf/animations/animations-smooth.lua | "Smooth" | animation windowsOut | `{ speed=100, bezier="easeOutExpo", enabled=true }` | Window out (very fast) |
| conf/animations/animations-smooth.lua | "Smooth" | animation windowsIn | `{ speed=7, bezier="easeOutBack", enabled=true }` | Window in |
| conf/animations/animations-smooth.lua | "Smooth" | animation windowsMove | `{ speed=6, bezier="easeInOutBack", style="slide", enabled=true }` | Window move |
| conf/animations/animations-smooth.lua | "Smooth" | animation border | `{ speed=5, bezier="default", enabled=true }` | Border |
| conf/animations/animations-smooth.lua | "Smooth" | animation fade | `{ speed=5, bezier="easeOutBack", enabled=true }` | Fade |
| conf/animations/animations-smooth.lua | "Smooth" | animation fadeDim | `{ speed=5, bezier="easeOutBack", enabled=true }` | Fade dim |
| conf/animations/animations-smooth.lua | "Smooth" | animation workspaces | `{ speed=10, bezier="easeOutExpo", enabled=true }` | Workspaces |
| conf/animations/default.lua | "Default" | animations.enabled | `true` | Master switch |
| conf/animations/default.lua | "Default" | curve linear | `{ {0, 0}, {1, 1} }` | Linear |
| conf/animations/default.lua | "Default" | curve md3_standard | `{ {0.2, 0}, {0, 1} }` | MD3 standard |
| conf/animations/default.lua | "Default" | curve md3_decel | `{ {0.05, 0.7}, {0.1, 1} }` | MD3 decel |
| conf/animations/default.lua | "Default" | curve md3_accel | `{ {0.3, 0}, {0.8, 0.15} }` | MD3 accel |
| conf/animations/default.lua | "Default" | curve overshot | `{ {0.05, 0.9}, {0.1, 1.1} }` | Overshoot |
| conf/animations/default.lua | "Default" | curve crazyshot | `{ {0.1, 1.5}, {0.76, 0.92} }` | Crazyshot |
| conf/animations/default.lua | "Default" | curve hyprnostretch | `{ {0.05, 0.9}, {0.1, 1.0} }` | Hyprnostretch |
| conf/animations/default.lua | "Default" | curve menu_decel | `{ {0.1, 1}, {0, 1} }` | Menu decel |
| conf/animations/default.lua | "Default" | curve menu_accel | `{ {0.38, 0.04}, {1, 0.07} }` | Menu accel |
| conf/animations/default.lua | "Default" | curve easeInOutCirc | `{ {0.85, 0}, {0.15, 1} }` | Circular in/out |
| conf/animations/default.lua | "Default" | curve easeOutCirc | `{ {0, 0.55}, {0.45, 1} }` | Circular out |
| conf/animations/default.lua | "Default" | curve easeOutExpo | `{ {0.16, 1}, {0.3, 1} }` | Expo out |
| conf/animations/default.lua | "Default" | curve softAcDecel | `{ {0.26, 0.26}, {0.15, 1} }` | Soft decel |
| conf/animations/default.lua | "Default" | curve md2 | `{ {0.4, 0}, {0.2, 1} }` | MD2; use with .2s duration |
| conf/animations/default.lua | "Default" | animation windows | `{ speed=3, bezier="md3_decel", style="popin 60%", enabled=true }` | Window open |
| conf/animations/default.lua | "Default" | animation windowsIn | `{ speed=3, bezier="md3_decel", style="popin 60%", enabled=true }` | Window in |
| conf/animations/default.lua | "Default" | animation windowsOut | `{ speed=3, bezier="md3_accel", style="popin 60%", enabled=true }` | Window out |
| conf/animations/default.lua | "Default" | animation border | `{ speed=10, bezier="default", enabled=true }` | Border |
| conf/animations/default.lua | "Default" | animation fade | `{ speed=3, bezier="md3_decel", enabled=true }` | Fade |
| conf/animations/default.lua | "Default" | animation layersIn | `{ speed=3, bezier="menu_decel", style="slide", enabled=true }` | Layer in |
| conf/animations/default.lua | "Default" | animation layersOut | `{ speed=1.6, bezier="menu_accel", enabled=true }` | Layer out |
| conf/animations/default.lua | "Default" | animation fadeLayersIn | `{ speed=2, bezier="menu_decel", enabled=true }` | Layer fade in |
| conf/animations/default.lua | "Default" | animation fadeLayersOut | `{ speed=4.5, bezier="menu_accel", enabled=true }` | Layer fade out |
| conf/animations/default.lua | "Default" | animation workspaces | `{ speed=7, bezier="menu_decel", style="slide", enabled=true }` | Workspace slide |
| conf/animations/default.lua | "Default" | animation specialWorkspace | `{ speed=3, bezier="md3_decel", style="slidevert", enabled=true }` | Scratchpad |
| conf/animations/disabled.lua | "Disabled" | animations.enabled | `false` | Master animation switch off |
| conf/animations/standard.lua | "Standard" | animations.enabled | `true` | Master switch |
| conf/animations/standard.lua | "Standard" | curve myBezier | `{ {0.05, 0.9}, {0.1, 1.05} }` | Custom bezier |
| conf/animations/standard.lua | "Standard" | animation windows | `{ speed=7, bezier="myBezier", enabled=true }` | Window open |
| conf/animations/standard.lua | "Standard" | animation windowsOut | `{ speed=7, bezier="default", style="popin 80%", enabled=true }` | Window out |
| conf/animations/standard.lua | "Standard" | animation border | `{ speed=10, bezier="default", enabled=true }` | Border |
| conf/animations/standard.lua | "Standard" | animation borderangle | `{ speed=8, bezier="default", enabled=true }` | Border angle |
| conf/animations/standard.lua | "Standard" | animation fade | `{ speed=7, bezier="default", enabled=true }` | Fade |
| conf/animations/standard.lua | "Standard" | animation workspaces | `{ speed=6, bezier="default", enabled=true }` | Workspaces |
| conf/decorations/blur.lua | "Blur" | decoration.rounding | `10` | Corner radius |
| conf/decorations/blur.lua | "Blur" | active_opacity / inactive_opacity / fullscreen_opacity | `1.0 / 0.9 / 1.0` | Opacity |
| conf/decorations/blur.lua | "Blur" | rounding_power | `2` | Corner exponent |
| conf/decorations/blur.lua | "Blur" | shadow.enabled / range / render_power / color | `true / 32 / 2 / "rgba(00000050)"` | Shadows |
| conf/decorations/blur.lua | "Blur" | blur.enabled / size / passes / new_optimizations / ignore_opacity / xray | `true / 3 / 4 / on / true / true` | Blur |
| conf/decorations/blur.lua | "Blur" | layer rule waybar | `hl.layer_rule({ match = { namespace = "waybar" }, blur = true })` | Blur waybar |
| conf/decorations/default.lua | "Default" — ACTIVE | decoration.rounding | `10` | OVERRIDDEN to 15 by hyprland-gui.lua |
| conf/decorations/default.lua | "Default" | active_opacity / inactive_opacity / fullscreen_opacity | `1.0 / 0.9 / 1.0` | Opacity |
| conf/decorations/default.lua | "Default" | rounding_power | `2` | OVERRIDDEN to 3.5 |
| conf/decorations/default.lua | "Default" | shadow.enabled / range / render_power / color | `true / 32 / 2 / "rgba(00000050)"` | Shadows |
| conf/decorations/default.lua | "Default" | blur.enabled / size / passes / new_optimizations / ignore_opacity / xray / vibrancy | `true / 4 / 4 / on / true / true / 0.1696` | Blur |
| conf/decorations/gamemode.lua | "Gamemode" | decoration.rounding | `0` | Square corners |
| conf/decorations/gamemode.lua | "Gamemode" | active_opacity / inactive_opacity / fullscreen_opacity | `1.0 / 0.9 / 1.0` | Opacity |
| conf/decorations/gamemode.lua | "Gamemode" | shadow.enabled | `false` | No shadows |
| conf/decorations/gamemode.lua | "Gamemode" | blur.enabled | `false` | No blur |
| conf/decorations/no-blur.lua | "No Blur" | decoration.rounding | `10` | Corner radius |
| conf/decorations/no-blur.lua | "No Blur" | active_opacity / inactive_opacity / fullscreen_opacity | `1.0 / 0.9 / 1.0` | Opacity |
| conf/decorations/no-blur.lua | "No Blur" | rounding_power | `2` | Corner exponent |
| conf/decorations/no-blur.lua | "No Blur" | shadow.enabled / range / render_power / color | `true / 32 / 2 / "rgba(00000050)"` | Shadows |
| conf/decorations/no-blur.lua | "No Blur" | blur.enabled | `false` | Blur off |
| conf/decorations/no-rounding-more-blur.lua | "No Rounding More Blur" | decoration.rounding | `0` | Square corners |
| conf/decorations/no-rounding-more-blur.lua | "No Rounding More Blur" | active_opacity / inactive_opacity / fullscreen_opacity | `1.0 / 0.6 / 1.0` | Opacity |
| conf/decorations/no-rounding-more-blur.lua | "No Rounding More Blur" | blur.enabled / size / passes / new_optimizations / ignore_opacity / xray | `true / 12 / 6 / true / true / true` | Heavy blur |
| conf/decorations/no-rounding-more-blur.lua | "No Rounding More Blur" | shadow.enabled / range / render_power / color | `true / 30 / 3 / "0x66000000"` | Shadows |
| conf/decorations/no-rounding.lua | "No Rounding" | decoration.rounding | `0` | Square corners |
| conf/decorations/no-rounding.lua | "No Rounding" | active_opacity / inactive_opacity / fullscreen_opacity | `1.0 / 0.9 / 1.0` | Opacity |
| conf/decorations/no-rounding.lua | "No Rounding" | rounding_power | `2` | Corner exponent |
| conf/decorations/no-rounding.lua | "No Rounding" | shadow.enabled / range / render_power / color | `true / 32 / 2 / "rgba(00000050)"` | Shadows |
| conf/decorations/no-rounding.lua | "No Rounding" | blur.enabled / size / passes / new_optimizations / ignore_opacity / xray / vibrancy | `true / 4 / 4 / on / true / true / 0.1696` | Blur |
| conf/decorations/rounding-all-blur-no-shadows.lua | "Rounding All Blur No Shadows" | decoration.rounding | `10` | Corner radius |
| conf/decorations/rounding-all-blur-no-shadows.lua | "Rounding All Blur No Shadows" | active_opacity / inactive_opacity / fullscreen_opacity | `0.9 / 0.6 / 0.9` | All translucent |
| conf/decorations/rounding-all-blur-no-shadows.lua | "Rounding All Blur No Shadows" | blur.enabled / size / passes / new_optimizations / ignore_opacity / xray | `true / 3 / 4 / true / true / true` | Blur |
| conf/decorations/rounding-all-blur-no-shadows.lua | "Rounding All Blur No Shadows" | shadow.enabled / range / render_power / color | `false / 30 / 3 / "0x66000000"` | Shadows off; other values retained |
| conf/decorations/rounding-all-blur-no-shadows.lua | "Rounding All Blur No Shadows" | layer rule waybar | `hl.layer_rule({ match = { namespace = "waybar" }, blur = true })` | Blur waybar |
| conf/decorations/rounding-all-blur.lua | "Rounding All Blur" | decoration.rounding | `10` | Corner radius |
| conf/decorations/rounding-all-blur.lua | "Rounding All Blur" | active_opacity / inactive_opacity / fullscreen_opacity | `0.9 / 0.6 / 0.9` | All translucent |
| conf/decorations/rounding-all-blur.lua | "Rounding All Blur" | blur.enabled / size / passes / new_optimizations / ignore_opacity / xray | `true / 3 / 4 / true / true / true` | Blur |
| conf/decorations/rounding-all-blur.lua | "Rounding All Blur" | shadow.enabled / range / render_power / color | `true / 30 / 3 / "0x66000000"` | Shadows |
| conf/decorations/rounding-all-blur.lua | "Rounding All Blur" | layer rule waybar | `hl.layer_rule({ match = { namespace = "waybar" }, blur = true })` | Blur waybar |
| conf/decorations/rounding-more-blur.lua | "Rounding More Blur" | decoration.rounding | `10` | Corner radius |
| conf/decorations/rounding-more-blur.lua | "Rounding More Blur" | active_opacity / inactive_opacity / fullscreen_opacity | `1.0 / 0.6 / 1.0` | Opacity |
| conf/decorations/rounding-more-blur.lua | "Rounding More Blur" | blur.enabled / size / passes / new_optimizations / ignore_opacity / xray | `true / 12 / 6 / true / true / true` | Heavy blur |
| conf/decorations/rounding-more-blur.lua | "Rounding More Blur" | shadow.enabled / range / render_power / color | `true / 30 / 3 / "0x66000000"` | Shadows |
| conf/decorations/rounding.lua | "Rounding" | decoration.rounding | `10` | Corner radius |
| conf/decorations/rounding.lua | "Rounding" | active_opacity / inactive_opacity / fullscreen_opacity | `1.0 / 0.8 / 1.0` | Opacity |
| conf/decorations/rounding.lua | "Rounding" | rounding_power | `2` | Corner exponent |
| conf/decorations/rounding.lua | "Rounding" | shadow.enabled / range / render_power / color | `true / 32 / 2 / "rgba(66000000)"` | Shadows |
| conf/decorations/rounding.lua | "Rounding" | blur.enabled / size / passes / new_optimizations / ignore_opacity / xray / vibrancy | `true / 3 / 4 / on / true / true / 0.1696` | Blur |
| conf/environments/default.lua | "Default" — ACTIVE | — | *(empty file)* | No overrides; base env in conf/ml4w.lua |
| conf/environments/kvm.lua | "KVM" | WLR_RENDERER_ALLOW_SOFTWARE | `"1"` | Software rendering in VM |
| conf/environments/nvidia.lua | "NVIDIA" | LIBVA_DRIVER_NAME | `"nvidia"` | VA-API driver |
| conf/environments/nvidia.lua | "NVIDIA" | __GLX_VENDOR_LIBRARY_NAME | `"nvidia"` | GLX vendor library |
| conf/keybindings/default.lua | config | mainMod | `"SUPER"` | Primary modifier |
| conf/keybindings/default.lua | Applications | SUPER + RETURN | `hl.dsp.exec_cmd("~/.config/ml4w/settings/terminal.sh")`, desc "Open the terminal" | Terminal (OVERRIDDEN to kitty by custom.lua) |
| conf/keybindings/default.lua | Applications | SUPER + B | `browser.sh`, desc "Open the browser" | Browser |
| conf/keybindings/default.lua | Applications | SUPER + E | `filemanager`, desc "Open the filemanager" | File manager |
| conf/keybindings/default.lua | Applications | SUPER + CTRL + E | `emojipicker.sh`, desc "Open the emoji picker" | Emoji picker |
| conf/keybindings/default.lua | Applications | SUPER + C | `calculator.sh`, desc "Open the calculator" | Calculator |
| conf/keybindings/default.lua | AZERTY setup | azerty_keys.fr | `{ "ampersand", "eacute", "quotedbl", "apostrophe", "parenleft", "minus", "egrave", "underscore", "ccedilla", "agrave" }` | Workspace 1–10 keysyms, French |
| conf/keybindings/default.lua | AZERTY setup | azerty_keys.be | `{ "ampersand", "eacute", "quotedbl", "apostrophe", "parenleft", "section", "egrave", "exclam", "ccedilla", "agrave" }` | Belgian AZERTY keysyms |
| conf/keybindings/default.lua | AZERTY setup | non_azerty_variants.fr | `{ us=true, bepo=true, bepo_afnor=true, dvorak=true }` | Exclude FR non-AZERTY variants |
| conf/keybindings/default.lua | AZERTY setup | non_azerty_variants.be | `{ wang=true }` | Exclude BE wang |
| conf/keybindings/default.lua | AZERTY setup | detect_azerty source | `os.getenv("HOME") .. "/.config/hypr/input.lua"` | Read kb_layout/variant |
| conf/keybindings/default.lua | AZERTY setup | kb_layout match | `'kb_layout%s*=%s*"([^",]*)'` | Extract primary layout |
| conf/keybindings/default.lua | AZERTY setup | kb_variant match | `'kb_variant%s*=%s*"([^",]*)' or ""` | Extract variant |
| conf/keybindings/default.lua | Workspaces loop | loop | `for i = 1, 10 do` | Generate 10 binds |
| conf/keybindings/default.lua | Workspaces loop | key selection | `ws_keys and ws_keys[i] or (i % 10)` | AZERTY keysym or digit; 10 → 0 |
| conf/keybindings/default.lua | Workspaces loop | SUPER + key | `hl.dsp.focus({ workspace = i })`, desc "Focus workspace i" | Focus workspace |
| conf/keybindings/default.lua | Workspaces loop | SUPER + SHIFT + key | `hl.dsp.window.move({ workspace = i })`, desc "Move window to workspace i" | Move to workspace |
| conf/keybindings/default.lua | Windows | SUPER + Q | `killactive.sh`, desc "Kill active window" | Overlay-aware close |
| conf/keybindings/default.lua | Windows | SUPER + SHIFT + Q | `hyprctl activewindow \| grep pid \| tr -d 'pid:' \| xargs kill`, desc "Quit active window and all open instances" | Kill all instances |
| conf/keybindings/default.lua | Windows | SUPER + F | `hl.dsp.window.fullscreen({ mode="fullscreen", action="toggle" })`, desc "Toggle Fullscreen" | Fullscreen |
| conf/keybindings/default.lua | Windows | SUPER + M | `hl.dsp.window.fullscreen({ mode="maximized", action="toggle" })`, desc "Toggle Maximize Window" | Maximize |
| conf/keybindings/default.lua | Windows | SUPER + T | `hl.dsp.window.float({ action="toggle" })`, desc "Toggle Floating" | Float |
| conf/keybindings/default.lua | Windows | SUPER + SHIFT + T | `ml4w-toggle-allfloat`, desc "Toggle floating for all windows of workspace" | All-float |
| conf/keybindings/default.lua | Windows | SUPER + ALT + T | `function() hl.dispatch(hl.dsp.window.float({ action="toggle" })); hl.dispatch(hl.dsp.window.pin()) end`, desc "Toggle floating + pinned" | Float + pin |
| conf/keybindings/default.lua | Windows | SUPER + J | `hl.dsp.layout("togglesplit")`, desc "Toggle split" | Split toggle |
| conf/keybindings/default.lua | Windows | SUPER + left | `hl.dsp.focus({ direction="left" })`, desc "Move focus left" | Focus left |
| conf/keybindings/default.lua | Windows | SUPER + right | `hl.dsp.focus({ direction="right" })`, desc "Move focus right" | Focus right |
| conf/keybindings/default.lua | Windows | SUPER + up | `hl.dsp.focus({ direction="up" })`, desc "Move focus up" | Focus up |
| conf/keybindings/default.lua | Windows | SUPER + down | `hl.dsp.focus({ direction="down" })`, desc "Move focus down" | Focus down |
| conf/keybindings/default.lua | Windows | SUPER + mouse:272 | `hl.dsp.window.drag()`, `{ mouse=true, description="Move window with the mouse" }` | Drag (left button) |
| conf/keybindings/default.lua | Windows | SUPER + mouse:273 | `hl.dsp.window.resize()`, `{ mouse=true, description="Resize window with the mouse" }` | Resize (right button) |
| conf/keybindings/default.lua | Windows | SUPER + SHIFT + right | `hl.dsp.window.resize({ x=100, y=0, relative=true })`, `{ repeating=true }` | Wider |
| conf/keybindings/default.lua | Windows | SUPER + SHIFT + left | `hl.dsp.window.resize({ x=-100, y=0, relative=true })`, `{ repeating=true }` | Narrower |
| conf/keybindings/default.lua | Windows | SUPER + SHIFT + down | `hl.dsp.window.resize({ x=0, y=100, relative=true })`, `{ repeating=true }` | Taller |
| conf/keybindings/default.lua | Windows | SUPER + SHIFT + up | `hl.dsp.window.resize({ x=0, y=-100, relative=true })`, `{ repeating=true }` | Shorter |
| conf/keybindings/default.lua | Windows | SUPER + G | `hl.dsp.group.toggle()`, desc "Toggle window group" | Group toggle |
| conf/keybindings/default.lua | Windows | SUPER + K | `hl.dsp.layout("swapsplit")`, desc "Swapsplit" | Swap split |
| conf/keybindings/default.lua | Windows | SUPER + ALT + left | `hl.dsp.window.swap({ direction="l" })`, desc "Swap tiled window left" | Swap left |
| conf/keybindings/default.lua | Windows | SUPER + ALT + right | `hl.dsp.window.swap({ direction="r" })`, desc "Swap tiled window right" | Swap right |
| conf/keybindings/default.lua | Windows | SUPER + ALT + up | `hl.dsp.window.swap({ direction="u" })`, desc "Swap tiled window up" | Swap up |
| conf/keybindings/default.lua | Windows | SUPER + ALT + down | `hl.dsp.window.swap({ direction="d" })`, desc "Swap tiled window down" | Swap down |
| conf/keybindings/default.lua | Actions | SUPER + SHIFT + A | `toggle-animations.sh`, desc "Toggle animations" | Toggle animation master |
| conf/keybindings/default.lua | Actions | SUPER + PRINT | `screenshot.sh`, desc "Take a screenshot" | Screenshot menu |
| conf/keybindings/default.lua | Actions | SUPER + ALT + F | `screenshot.sh --instant`, desc "Take an instant full-screen screenshot" | Instant full |
| conf/keybindings/default.lua | Actions | SUPER + ALT + S | `screenshot.sh --instant-area`, desc "Take an instant area screenshot" | Instant area |
| conf/keybindings/default.lua | Actions | SUPER + ALT + A | `text-extractor.sh`, desc "Extract text from an area" | OCR |
| conf/keybindings/default.lua | Actions | SUPER + CTRL + P | `ml4w-powermenu toggle`, desc "Start Power Menu" | Power menu |
| conf/keybindings/default.lua | Actions | SUPER + W | `ml4w-wallpaper-app --carousel`, desc "Open wallpaper carousel" | Carousel |
| conf/keybindings/default.lua | Actions | SUPER + SHIFT + W | `ml4w-wallpaper-app --random`, desc "Change the wallpaper" | Random wallpaper |
| conf/keybindings/default.lua | Actions | SUPER + CTRL + W | `ml4w-wallpaper-app`, desc "Open wallpaper selector" | Picker |
| conf/keybindings/default.lua | Actions | SUPER + ALT + W | `ml4w-wallpaper-automation`, desc "Start random wallpaper script" | Automation |
| conf/keybindings/default.lua | Actions | SUPER + CTRL + RETURN | `ml4w-launcher`, desc "Open application launcher" | Launcher |
| conf/keybindings/default.lua | Actions | SUPER + CTRL + K | `keybindings.sh`, desc "Show keybindings" | Cheat sheet |
| conf/keybindings/default.lua | Actions | SUPER + SHIFT + B | `ml4w-reload-statusbar`, desc "Reload Status Bar" | Reload bar |
| conf/keybindings/default.lua | Actions | SUPER + CTRL + B | `ml4w-toggle-statusbar`, desc "Toggle Status Bar" | Toggle bar |
| conf/keybindings/default.lua | Actions | SUPER + ALT + B | `ml4w-toggle-statusbar-autohide`, desc "Toggle Status Bar Autohide" | Bar autohide |
| conf/keybindings/default.lua | Actions | SUPER + SHIFT + D | `ml4w-reload-dock`, desc "Reload Dock" | Reload dock |
| conf/keybindings/default.lua | Actions | SUPER + CTRL + D | `ml4w-toggle-dock`, desc "Toggle Dock" | Toggle dock |
| conf/keybindings/default.lua | Actions | SUPER + ALT + D | `ml4w-toggle-dock-autohide`, desc "Toggle Dock Autohide" | Dock autohide |
| conf/keybindings/default.lua | Actions | SUPER + SHIFT + R | `loadconfig.sh`, desc "Reload hyprland config" | Reload Hyprland |
| conf/keybindings/default.lua | Actions | SUPER + V | `ml4w-cliphist`, desc "Open clipboard manager" | Clipboard |
| conf/keybindings/default.lua | Actions | SUPER + CTRL + T | `~/.config/waybar/themeswitcher.sh`, desc "Open waybar theme switcher" | Waybar theme |
| conf/keybindings/default.lua | Actions | SUPER + SHIFT + M | `ml4w-toggle-theme`, desc "Toggle between light and dark mode" | Light/dark |
| conf/keybindings/default.lua | Actions | SUPER + CTRL + S | `qs ipc call sidebar toggle`, desc "Open ML4W Sidebar widget" | Sidebar |
| conf/keybindings/default.lua | Actions | SUPER + CTRL + C | `qs ipc call calendar toggle`, desc "Open ML4W Calendar widget" | Calendar |
| conf/keybindings/default.lua | Actions | SUPER + SPACE | `qs ipc call statusbar focus`, desc "Expand statusbar and focus it for keyboard navigation" | Bar keyboard nav |
| conf/keybindings/default.lua | Actions | SUPER + ALT + G | `gamemode.sh`, desc "Toggle game mode" | Game mode |
| conf/keybindings/default.lua | Actions | SUPER + CTRL + L | `ml4w-power -l`, desc "Lock Screen" | Lock |
| conf/keybindings/default.lua | Actions | SUPER + SHIFT + H | `ml4w-toggle-hyprsunset`, desc "Toggle Hyprsunset" | Night light |
| conf/keybindings/default.lua | Actions | SUPER + Tab | `qs -p ~/.local/share/quickshell-overview ipc call overview toggle`, desc "Open Select Window Menu" | Overview |
| conf/keybindings/default.lua | Actions | CTRL + ALT + T | `~/.config/ml4w/themes/themes.sh`, desc "Open theme switcher" | Theme switcher |
| conf/keybindings/default.lua | Hypr App Switcher | ALT + Tab | `qs -p ~/.local/share/hypr-app-switcher ipc call app-switcher next`, desc "Switch applications on active workspace" | Next app |
| conf/keybindings/default.lua | Hypr App Switcher | ALT + SHIFT + Tab | `qs -p ~/.local/share/hypr-app-switcher ipc call app-switcher prev`, desc "Switch applications on active workspace (backwards)" | Prev app |
| conf/keybindings/default.lua | Special workspace | SUPER + S | `hl.dsp.workspace.toggle_special("scratchpad")`, desc "Toggle special workspace scratchpad" | Scratchpad |
| conf/keybindings/default.lua | Special workspace | SUPER + SHIFT + S | `function() hl.dispatch(hl.dsp.window.float({ action="toggle" })); hl.dispatch(hl.dsp.window.move({ workspace="special:scratchpad" })) end`, desc "Move window to special workspace scratchpad" | Send to scratchpad |
| conf/keybindings/default.lua | binds config | binds.pass_mouse_when_bound | `false` | Swallow bound mouse events |
| conf/keybindings/default.lua | binds config | binds.scroll_event_delay | `1` | Scroll throttle base |
| conf/keybindings/default.lua | scroll throttle | scroll_locked initial | `false` | Throttle guard state |
| conf/keybindings/default.lua | scroll throttle | hl.timer timeout | `200` | ms lockout after scroll |
| conf/keybindings/default.lua | scroll throttle | hl.timer type | `"oneshot"` | Single-shot timer |
| conf/keybindings/default.lua | Workspace scroll | SUPER + mouse_down | `throttled_scroll(hl.dsp.focus({ workspace="e+1" }))`, desc "Switch to next workspace" | Next workspace |
| conf/keybindings/default.lua | Workspace scroll | SUPER + mouse_up | `throttled_scroll(hl.dsp.focus({ workspace="e-1" }))`, desc "Switch to previous workspace" | Prev workspace |
| conf/keybindings/default.lua | Multimedia | XF86AudioRaiseVolume | `wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+`, `{ locked=true, repeating=true }` | Volume up capped at 1 |
| conf/keybindings/default.lua | Multimedia | XF86AudioLowerVolume | `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-`, `{ locked=true, repeating=true }` | Volume down |
| conf/keybindings/default.lua | Multimedia | XF86AudioMute | `wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle`, `{ locked=true, repeating=true }` | Mute |
| conf/keybindings/default.lua | Multimedia | XF86AudioMicMute | `wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle`, `{ locked=true, repeating=true }` | Mic mute |
| conf/keybindings/default.lua | Multimedia | XF86MonBrightnessUp | `brightnessctl -e4 -n2 set 5%+`, `{ locked=true, repeating=true }` | OVERRIDDEN by custom.lua |
| conf/keybindings/default.lua | Multimedia | XF86MonBrightnessDown | `brightnessctl -e4 -n2 set 5%-`, `{ locked=true, repeating=true }` | OVERRIDDEN by custom.lua |
| conf/keybindings/default.lua | Multimedia | XF86AudioNext | `playerctl next`, `{ locked=true }` | Next track |
| conf/keybindings/default.lua | Multimedia | XF86AudioPause | `playerctl play-pause`, `{ locked=true }` | Pause |
| conf/keybindings/default.lua | Multimedia | XF86AudioPlay | `playerctl play-pause`, `{ locked=true }` | Play |
| conf/keybindings/default.lua | Multimedia | XF86AudioPrev | `playerctl previous`, `{ locked=true }` | Previous track |
| conf/layouts/default.lua | "Default" | dwindle.preserve_split | `true` | Keep split ratio |
| conf/layouts/default.lua | "Default" | master | `{}` (only commented new_status) | Master defaults |
| conf/layouts/default.lua | "Default" | binds.workspace_back_and_forth | `false` | No auto toggle |
| conf/layouts/default.lua | "Default" | binds.allow_workspace_cycles | `true` | Allow cycles |
| conf/layouts/default.lua | "Default" | binds.pass_mouse_when_bound | `false` | DUP in keybindings/default.lua, same value |
| conf/layouts/laptop.lua | "Laptop" — ACTIVE | dwindle.preserve_split | `true` | Keep split ratio |
| conf/layouts/laptop.lua | "Laptop" | master | `{}` (only commented new_status) | Master defaults |
| conf/layouts/laptop.lua | "Laptop" | binds.workspace_back_and_forth | `false` | No auto toggle |
| conf/layouts/laptop.lua | "Laptop" | binds.allow_workspace_cycles | `true` | Allow cycles |
| conf/layouts/laptop.lua | "Laptop" | binds.pass_mouse_when_bound | `false` | DUP in keybindings/default.lua, same value |
| conf/monitors/1366x768.lua | "1366x768" | output / mode / position / scale | `"" / "1366x768" / "auto" / 1` | All outputs; resolution; auto; 100% |
| conf/monitors/1440x1080.lua | "1440x1080" | output / mode / position / scale | `"" / "1440x1080" / "auto" / 1` | All outputs; resolution; auto; 100% |
| conf/monitors/1600x900.lua | "1600x900" | output / mode / position / scale | `"" / "1600x900" / "auto" / 1` | All outputs; resolution; auto; 100% |
| conf/monitors/1920x1080.lua | "1920x1080" — ACTIVE | output | `""` | All outputs; refined for eDP-1 by monitors.lua |
| conf/monitors/1920x1080.lua | "1920x1080" | mode / position / scale | `"1920x1080" / "auto" / 1` | Resolution; auto; 100% |
| conf/monitors/1920x1200.lua | "1920x1200" | output / mode / position / scale | `"" / "1920x1200" / "auto" / 1` | All outputs; resolution; auto; 100% |
| conf/monitors/2560x1440.lua | "2560x1440" | output / mode / position / scale | `"" / "2560x1440" / "auto" / 1` | All outputs; resolution; auto; 100% |
| conf/monitors/2560x1440@120.lua | "2560x1440@120" | output / mode / position / scale | `"" / "2560x1440@120" / "auto" / 1` | 120Hz |
| conf/monitors/2560x1440@120x125.lua | "2560x1440@120" (x125) | output / mode / position / scale | `"" / "2560x1440@120" / "auto" / 1.25` | 120Hz at 125% |
| conf/monitors/3440x1440.lua | "3440x1440" | output / mode / position / scale | `"" / "3440x1440" / "auto" / 1` | Ultrawide |
| conf/monitors/default-125.lua | "Default 1.25" | output / mode / position / scale | `"" / "preferred" / "auto" / 1.25` | Preferred at 125% |
| conf/monitors/default.lua | "Default" | — | *(empty except comment "Use nwg-displays to set your monitors")* | No parameters |
| conf/monitors/highres.lua | "Highres" | output / mode / position / scale | `"" / "highres" / "auto" / 1` | Highres |
| conf/monitors/preferred.lua | "Preferred" | output / mode / position / scale | `"" / "preferred" / "auto" / 1` | Preferred |
| conf/monitors/workspace-split.lua | "Workspace Split" | hl.workspace_rule fields | `workspace = tostring(i), monitor = monitor_name` | Bind workspace to monitor |
| conf/monitors/workspace-split.lua | "Workspace Split" | map_workspaces call 1 | `map_workspaces(1, 5, "DP-1")` | Workspaces 1–5 on DP-1 |
| conf/monitors/workspace-split.lua | "Workspace Split" | map_workspaces call 2 | `map_workspaces(6, 10, "HDMI-A-1")` | Workspaces 6–10 on HDMI-A-1 |
| conf/windows/border-1-reverse.lua | variant | gaps_in / gaps_out / border_size | `10 / 16 / 1` | Gaps, 1px border |
| conf/windows/border-1-reverse.lua | variant | active_border / inactive_border | `primary / on_primary` | Reversed colors |
| conf/windows/border-1-reverse.lua | variant | resize_on_border / allow_tearing / layout | `true / false / "dwindle"` | Flags (tearing OVERRIDDEN true) |
| conf/windows/border-1.lua | variant | gaps_in / gaps_out / border_size | `10 / 16 / 1` | Gaps, 1px border |
| conf/windows/border-1.lua | variant | active_border / inactive_border | `on_primary / primary` | Default colors |
| conf/windows/border-1.lua | variant | resize_on_border / allow_tearing / layout | `true / false / "dwindle"` | Flags |
| conf/windows/border-2-reverse.lua | variant | gaps_in / gaps_out / border_size | `10 / 16 / 2` | 2px border |
| conf/windows/border-2-reverse.lua | variant | active_border / inactive_border | `primary / on_primary` | Reversed |
| conf/windows/border-2-reverse.lua | variant | resize_on_border / allow_tearing / layout | `true / false / "dwindle"` | Flags |
| conf/windows/border-2.lua | variant | gaps_in / gaps_out / border_size | `10 / 16 / 2` | 2px border |
| conf/windows/border-2.lua | variant | active_border / inactive_border | `on_primary / primary` | Default |
| conf/windows/border-2.lua | variant | resize_on_border / allow_tearing / layout | `true / false / "dwindle"` | Flags |
| conf/windows/border-3-reverse.lua | variant | gaps_in / gaps_out / border_size | `10 / 16 / 3` | 3px border |
| conf/windows/border-3-reverse.lua | variant | active_border / inactive_border | `primary / on_primary` | Reversed |
| conf/windows/border-3-reverse.lua | variant | resize_on_border / allow_tearing / layout | `true / false / "dwindle"` | Flags |
| conf/windows/border-3.lua | variant | gaps_in / gaps_out / border_size | `10 / 16 / 3` | 3px border |
| conf/windows/border-3.lua | variant | active_border / inactive_border | `on_primary / primary` | Default |
| conf/windows/border-3.lua | variant | resize_on_border / allow_tearing / layout | `true / false / "dwindle"` | Flags |
| conf/windows/border-4-reverse.lua | variant | gaps_in / gaps_out / border_size | `10 / 16 / 4` | 4px border |
| conf/windows/border-4-reverse.lua | variant | active_border / inactive_border | `primary / on_primary` | Reversed |
| conf/windows/border-4-reverse.lua | variant | resize_on_border / allow_tearing / layout | `true / false / "dwindle"` | Flags |
| conf/windows/border-4.lua | variant | gaps_in / gaps_out / border_size | `10 / 16 / 4` | 4px border |
| conf/windows/border-4.lua | variant | active_border / inactive_border | `on_primary / primary` | Default |
| conf/windows/border-4.lua | variant | resize_on_border / allow_tearing / layout | `true / false / "dwindle"` | Flags |
| conf/windows/default.lua | variant | gaps_in / gaps_out / border_size | `10 / 16 / 2` | Default gaps, 2px border |
| conf/windows/default.lua | variant | active_border | `{ colors = {primary, on_primary}, angle = 90 }` | Gradient active border |
| conf/windows/default.lua | variant | inactive_border | `on_primary` | Inactive color |
| conf/windows/default.lua | variant | resize_on_border / allow_tearing / layout | `true / false / "dwindle"` | Flags |
| conf/windows/gamemode.lua | variant | gaps_in / gaps_out / border_size | `0 / 0 / 1` | No gaps, 1px border |
| conf/windows/gamemode.lua | variant | active_border / inactive_border | `on_surface / on_primary` | Game-mode colors |
| conf/windows/gamemode.lua | variant | resize_on_border / allow_tearing / layout | `true / false / "dwindle"` | Flags |
| conf/windows/glass.lua | variant — ACTIVE | gaps_in / gaps_out / border_size | `10 / 16 / 1` | Glass look, 1px border |
| conf/windows/glass.lua | variant | active_border | `{ colors = {primary, on_primary}, angle = 90 }` | Gradient active border |
| conf/windows/glass.lua | variant | inactive_border | `on_primary` | OVERRIDDEN to `0xff000000` by hyprland-gui.lua |
| conf/windows/glass.lua | variant | resize_on_border / allow_tearing / layout | `true / false / "dwindle"` | Flags (tearing OVERRIDDEN true) |
| conf/windows/no-border-more-gaps.lua | variant | gaps_in / gaps_out / border_size | `20 / 40 / 0` | Large gaps, no border |
| conf/windows/no-border-more-gaps.lua | variant | active_border / inactive_border | `on_surface / primary` | Colors (invisible at size 0) |
| conf/windows/no-border-more-gaps.lua | variant | resize_on_border / allow_tearing / layout | `true / false / "dwindle"` | Flags |
| conf/windows/no-border.lua | variant | gaps_in / gaps_out / border_size | `10 / 16 / 0` | No border |
| conf/windows/no-border.lua | variant | active_border / inactive_border | `on_surface / primary` | Colors |
| conf/windows/no-border.lua | variant | resize_on_border / allow_tearing / layout | `true / false / "dwindle"` | Flags |
| conf/windows/transparent.lua | variant | gaps_in / gaps_out / border_size | `10 / 16 / 1` | Gaps, 1px border |
| conf/windows/transparent.lua | variant | active_border | `{ colors = {"rgb(ffffff)", on_primary}, angle = 90 }` | White-to-primary gradient |
| conf/windows/transparent.lua | variant | inactive_border | `on_primary` | Inactive color |
| conf/windows/transparent.lua | variant | resize_on_border / allow_tearing / layout | `true / false / "dwindle"` | Flags |
| conf/windowrules/default.lua | "Default" — ACTIVE | — | *(empty file)* | No extra window rules |
| conf/workspaces/default.lua | "Default" — ACTIVE | — | *(empty file)* | No workspace rules |
| hypridle.conf | general | lock_cmd | `pidof hyprlock \|\| hyprlock` | Avoid multiple hyprlock instances |
| hypridle.conf | general | before_sleep_cmd | `loginctl lock-session` | Lock before suspend |
| hypridle.conf | general | after_sleep_cmd | `hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'` | Re-enable display after sleep |
| hypridle.conf | listener 1 | timeout | `480` | 8 minutes |
| hypridle.conf | listener 1 | on-timeout | `brightnessctl -s set 10` | Dim to 10% (avoid 0 on OLED) |
| hypridle.conf | listener 1 | on-resume | `brightnessctl -r` | Restore backlight |
| hypridle.conf | listener 2 | timeout | `600` | 10 minutes |
| hypridle.conf | listener 2 | on-timeout | `loginctl lock-session` | Lock screen |
| hypridle.conf | listener 3 | timeout | `660` | 11 minutes |
| hypridle.conf | listener 3 | on-timeout | `hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })'` | Screen off |
| hypridle.conf | listener 3 | on-resume | `hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })' && brightnessctl -r` | Screen on + restore brightness |
| hypridle.conf | listener 4 | timeout | `1800` | 30 minutes |
| hypridle.conf | listener 4 | on-timeout | `systemctl suspend` | Suspend |
| hyprlock.conf | variables | $ml4w_cache_folder | `$HOME/.cache/ml4w/hyprland-dotfiles` | Wallpaper cache |
| hyprlock.conf | source | source | `colors.conf` | Import Material colors |
| hyprlock.conf | general | ignore_empty_input | `true` | No unlock on empty password |
| hyprlock.conf | background | monitor | *(empty)* | All monitors |
| hyprlock.conf | background | path | `$ml4w_cache_folder/blurred_wallpaper.png` | Lock background (PNG only) |
| hyprlock.conf | input-field | monitor | *(empty)* | All monitors |
| hyprlock.conf | input-field | size | `200, 50` | Field size |
| hyprlock.conf | input-field | dots_size | `0.33` | Dot size (0.2 - 0.8) |
| hyprlock.conf | input-field | dots_spacing | `0.15` | Dot spacing (0.0 - 1.0) |
| hyprlock.conf | input-field | dots_center | `true` | Center dots |
| hyprlock.conf | input-field | dots_rounding | `-1` | -1 circle, -2 follow field |
| hyprlock.conf | input-field | inner_color | `$primary` | Inner color |
| hyprlock.conf | input-field | font_color | `$on_primary` | Font color |
| hyprlock.conf | input-field | font_family | `Fira Semibold` | Font |
| hyprlock.conf | input-field | outer_color | `$on_primary` | Outer color |
| hyprlock.conf | input-field | outline_thickness | `3` | Outline width |
| hyprlock.conf | input-field | fade_on_empty | `true` | Fade when empty |
| hyprlock.conf | input-field | fade_timeout | `1000` | ms before fade |
| hyprlock.conf | input-field | placeholder_text | `<i>Input Password...</i>` | Placeholder |
| hyprlock.conf | input-field | hide_input | `false` | Show dots |
| hyprlock.conf | input-field | rounding | `10` | Radius (-1 full circle) |
| hyprlock.conf | input-field | check_color | `$primary` | Success |
| hyprlock.conf | input-field | fail_color | `$error` | Failure |
| hyprlock.conf | input-field | fail_text | `<i>$FAIL <b>($ATTEMPTS)</b></i>` | Failure message |
| hyprlock.conf | input-field | capslock_color | `-1` | No change |
| hyprlock.conf | input-field | numlock_color | `-1` | No change |
| hyprlock.conf | input-field | bothlock_color | `-1` | No change when both locks active |
| hyprlock.conf | input-field | invert_numlock | `false` | No inversion |
| hyprlock.conf | input-field | swap_font_color | `false` | No swap |
| hyprlock.conf | input-field | position | `0, -20` | Offset |
| hyprlock.conf | input-field | halign / valign | `center / center` | Alignment |
| hyprlock.conf | input-field | shadow_passes / shadow_size / shadow_color / shadow_boost | `10 / 20 / $shadow / 1.6` | Shadow |
| hyprlock.conf | label (clock) | monitor | *(empty)* | All monitors |
| hyprlock.conf | label (clock) | text | `cmd[update:1000] echo "$TIME"` | Live clock, 1s update |
| hyprlock.conf | label (clock) | color | `$primary` | Text color |
| hyprlock.conf | label (clock) | font_size | `70` | Large clock |
| hyprlock.conf | label (clock) | font_family | `Fira Sans Semibold` | Font |
| hyprlock.conf | label (clock) | position | `-50, 20` | Offset |
| hyprlock.conf | label (clock) | halign / valign | `right / bottom` | Alignment |
| hyprlock.conf | label (clock) | shadow_passes / shadow_size | `5 / 10` | Shadow |
| hyprlock.conf | label (user) | monitor | *(empty)* | All monitors |
| hyprlock.conf | label (user) | text | `$USER` | Username |
| hyprlock.conf | label (user) | color | `$primary` | Text color |
| hyprlock.conf | label (user) | font_size | `20` | Font size |
| hyprlock.conf | label (user) | font_family | `Fira Sans Semibold` | Font |
| hyprlock.conf | label (user) | position | `-50, 120` | Offset |
| hyprlock.conf | label (user) | halign / valign | `right / bottom` | Alignment |
| hyprlock.conf | label (user) | shadow_passes / shadow_size | `5 / 10` | Shadow |
| hyprlock.conf | image (avatar) | monitor | *(empty)* | All monitors |
| hyprlock.conf | image (avatar) | path | `$ml4w_cache_folder/square_wallpaper.png` | Avatar |
| hyprlock.conf | image (avatar) | size | `280` | Lesser side if not 1:1 |
| hyprlock.conf | image (avatar) | rounding | `40` | Radius (negative = circle) |
| hyprlock.conf | image (avatar) | border_size | `4` | Border width |
| hyprlock.conf | image (avatar) | border_color | `$primary $on_primary 90deg` | Gradient border |
| hyprlock.conf | image (avatar) | rotate | `0` | Degrees CCW |
| hyprlock.conf | image (avatar) | reload_time | `-1` | No timed reload |
| hyprlock.conf | image (avatar) | position | `0, 200` | Offset |
| hyprlock.conf | image (avatar) | halign / valign | `center / center` | Alignment |
| hyprlock.conf | image (avatar) | shadow_passes / shadow_size / shadow_color / shadow_boost | `10 / 20 / $shadow / 1.6` | Shadow |
| hyprpaper.conf | wallpaper | preload | `$HOME/.config/hypr/assets/blank.png` | Preload blank |
| hyprpaper.conf | wallpaper | wallpaper | `,$HOME/.config/hypr/assets/blank.png` | Blank on all outputs |
| hyprpaper.conf | general | splash | `false` | No splash |
| hyprsunset.conf | profile 00:00 | time | `00:00` | Schedule time |
| hyprsunset.conf | profile 00:00 | temperature | `5000` | Temperature (display-mode.sh uses 4500/3000/6000) |
| hyprsunset.conf | profile 00:00 | gamma | `0.8` | Gamma |
| hyprtoolkit.conf | colors | background | `0xff101417` | Background |
| hyprtoolkit.conf | colors | base | `0xff1c2024` | Base |
| hyprtoolkit.conf | colors | text | `0xffe0e3e8` | Text |
| hyprtoolkit.conf | colors | alternate_base | `0xff262a2e` | Alternate base |
| hyprtoolkit.conf | colors | bright_text | `0xff2d3135` | Bright text |
| hyprtoolkit.conf | colors | link_text | `0xffcfc0e8` | Link text |
| hyprtoolkit.conf | colors | accent | `0xff95cdf7` | Accent |
| hyprtoolkit.conf | colors | accent_secondary | `0xffb7c9d9` | Secondary accent |
| hyprtoolkit.conf | static | rounding_large | `12` | Windows/cards radius (libadwaita) |
| hyprtoolkit.conf | static | rounding_small | `9` | Buttons/controls radius |
| hyprtoolkit.conf | static | font_family | `Ubuntu Sans` | Font |
| monitors.conf | generated by nwg-displays 2026-11-18 17:08:34 | monitor | `eDP-1,1920x1080@60.02,0x0,1.0,vrr,0` | DUP of monitors.lua in hyprlang form |
| workspaces.conf | whole file | — | *(empty file)* | No parameters |
| scripts/brightness.sh | defaults | backlight device | `DEVICE_DIR=$(ls -d /sys/class/backlight/* 2>/dev/null \| head -n 1)` | First backlight device |
| scripts/brightness.sh | fallback | CURR_PERCENT fallback | `20` | Used when sysfs/brightnessctl unavailable |
| scripts/brightness.sh | snap | step | multiples of 5 (1, 5, 10, ... 100) | Snap to 5% steps |
| scripts/brightness.sh | clamp | min / max | `1 / 100` | Never fully off |
| scripts/brightness.sh | exec | systemd-run | `systemd-run --user --wait --quiet brightnessctl set "${TARGET}%"` | Use systemd-run when available |
| scripts/cleanup.sh | flag | gamemode flag | `~/.cache/gamemode` removed if present | Clean stale game-mode flag |
| scripts/display-mode.sh | menu | rofi config | `~/.config/rofi/config-display-mode.rasi` | Menu theme |
| scripts/display-mode.sh | menu options | choices | `Grayscale / Blue light filter / Night mode / Dim / Focus mode / Reset all` | Display modes |
| scripts/display-mode.sh | Blue light filter | hyprsunset args | `-t 4500 -g 90` | 4500K, gamma 90 |
| scripts/display-mode.sh | Night mode | hyprsunset args | `-t 3000 -g 70` | 3000K, gamma 70 |
| scripts/display-mode.sh | Dim | hyprsunset args | `-t 6000 -g 60` | 6000K, gamma 60 |
| scripts/display-mode.sh | Focus mode | hyprsunset args | `-t 6000 -g 70` + `hyprshade on grayscale` | Dim + grayscale |
| scripts/display-mode.sh | Reset all | commands | `hyprshade off`, `pkill -x hyprsunset`, `hyprsunset -i &`, sleep 0.2, pkill again | Restore defaults |
| scripts/gamemode.sh | notifications | APP_NAME / NOTIFICATION_ICON | `"System" / "joystick"` | Notification metadata |
| scripts/gamemode.sh | state flag | gamemode-enabled | `~/.config/ml4w/settings/gamemode-enabled` | Presence toggles game mode |
| scripts/gamemode.sh | state flag | restart-wpauto | `$ml4w_cache_folder/restart-wpauto` | Restart wallpaper automation after game mode |
| scripts/gamemode.sh | deactivate | summary / message | `"Gamemode deactivated" / "Animations and blur are now enabled."` | Notification |
| scripts/gamemode.sh | activate | summary / message | `"Gamemode activated" / "Animations and blur are now disabled."` | Notification |
| scripts/gtk.sh | config | config file | `$HOME/.config/gtk-3.0/settings.ini` | GTK source |
| scripts/gtk.sh | config | gnome_schema | `org.gnome.desktop.interface` | GSettings schema |
| scripts/gtk.sh | mapping | gtk keys | `gtk-theme-name / gtk-icon-theme-name / gtk-cursor-theme-name / gtk-cursor-theme-size / gtk-font-name / gtk-application-prefer-dark-theme` | Read from settings.ini |
| scripts/gtk.sh | mapping | prefer_dark_theme_value | `prefer-light` if 0/false else `prefer-dark` | Color scheme |
| scripts/gtk.sh | cursor | cursor.conf | `~/.config/hypr/conf/cursor.conf` gets `exec-once = hyprctl setcursor $cursor_theme $cursor_size` | Apply cursor |
| scripts/hypridle.sh | service | SERVICE | `hypridle` | Daemon name |
| scripts/hypridle.sh | status | delay | `sleep 0.2` | Avoid startup race |
| scripts/hypridle.sh | actions | case args | `status / toggle` | Waybar module interface |
| scripts/keybindings.sh | launcher | launcher | `$HOME/.config/ml4w/scripts/ml4w-launcher which` | Detect walker vs rofi |
| scripts/keybindings.sh | formatter | mod_map | `{ [64]="SUPER", [8]="ALT", [4]="CTRL", [1]="SHIFT" }` | libxkbcommon modifier bits |
| scripts/keybindings.sh | source | command | `hyprctl binds -j \| jq -c '.[] \| select(.description != "")'` | Only described binds |
| scripts/keybindings.sh | rofi config | compact config | `~/.config/rofi/config-compact.rasi`, `--rofi-args "-sep \\0 -eh 2"` | Two-line entries |
| scripts/killactive.sh | panels | panel list | `sidebar / wallpaper / wallpaper-carousel / calendar` | Close QS overlay first |
| scripts/killactive.sh | special cases | "ML4W Welcome" | `qs ipc call welcome toggle` | Toggle welcome |
| scripts/killactive.sh | special cases | "ML4W Dotfiles Settings" | `qs -p $HOME/.local/share/ml4w-dotfiles-settings/quickshell ipc call settings toggle` | Toggle settings |
| scripts/killactive.sh | default | dispatcher | `hyprctl dispatch 'hl.dsp.window.close()'` | Close active window |
| scripts/launcher.sh | compatibility | exec | `$HOME/.config/ml4w/scripts/ml4w-launcher` | Delegate |
| scripts/load-gamemode.sh | batch keywords | animations:enabled | `0` | Disable animations |
| scripts/load-gamemode.sh | batch keywords | decoration:shadow:enabled | `0` | Disable shadows |
| scripts/load-gamemode.sh | batch keywords | decoration:blur:enabled | `0` | Disable blur |
| scripts/load-gamemode.sh | batch keywords | general:gaps_in / gaps_out | `0 / 0` | Remove gaps |
| scripts/load-gamemode.sh | batch keywords | general:border_size | `1` | 1px border |
| scripts/load-gamemode.sh | batch keywords | decoration:rounding | `0` | Square corners |
| scripts/loadconfig.sh | action | command | `hyprctl reload` | Reload config |
| scripts/moveTo.sh | logging | log format | `[$(date '+%Y-%m-%d %H:%M:%S')] $1` | Timestamped stdout |
| scripts/moveTo.sh | dispatch | move | `hl.dsp.window.move({ workspace = "$target_workspace", silent = true, window = "address:$address" })` | Silent move by address |
| scripts/moveTo.sh | dispatch | focus | `hl.dsp.focus({ workspace = "$target_workspace" })` | Switch workspace |
| scripts/power.sh | terminate_clients | TIMEOUT | `5` | Seconds before giving up on SIGTERM |
| scripts/power.sh | actions | exit / lock / reboot / shutdown / suspend / hibernate | `hl.dsp.exit() / hyprlock / systemctl reboot / systemctl poweroff / systemctl suspend / systemctl hibernate` | Power actions |
| scripts/restart-hypridle.sh | action | commands | `killall hypridle; sleep 1; hypridle &` | Restart idle daemon |
| scripts/screenshot.sh | defaults | SAVE_DIR | `"$HOME/Pictures"` | Default folder |
| scripts/screenshot.sh | defaults | SAVE_FILENAME | `"screenshot_$(date +%d%m%Y_%H%M%S).jpg"` | Default filename |
| scripts/screenshot.sh | settings | settings files | `~/.config/ml4w/settings/screenshot-folder`, `.../screenshot-filename` | Override defaults |
| scripts/screenshot.sh | flag | image_format | `png` default; jpeg for jpg/jpeg; ppm for ppm | Capture format |
| scripts/screenshot.sh | notifications | APP_NAME / NOTIFICATION_ICON | `"Screen Capture" / "camera-photo-symbolic"` | Notification metadata |
| scripts/screenshot.sh | flag | MENU_CLOSE_DELAY | `"0.6"` | Delay before capture |
| scripts/screenshot.sh | flag | GRIMBLAST_EDITOR | `$(cat ~/.config/ml4w/settings/screenshot-editor)` | Editor |
| scripts/screenshot.sh | instant flags | `--instant` / `--instant-area` | `take_instant_full` / `take_instant_area` | Quick capture |
| scripts/screenshot.sh | options | option_1 / option_2 | `Immediate / Delayed` | First menu |
| scripts/screenshot.sh | options | capture types | `Capture Everything / Capture Active Display / Capture Selection` + quick variants | Type menu |
| scripts/screenshot.sh | options | dividers/actions | `──────────────────── / Copy / Save / Copy & Save / Edit` | Menu entries |
| scripts/screenshot.sh | options | timers | `5s / 10s / 20s / 30s / 60s` | Delay choices |
| scripts/screenshot.sh | options | list_col / list_row | `1 / 2` | Rofi list size |
| scripts/screenshot.sh | launcher args | rofi / walker args | `-no-show-icons -width 30`; `--height 285` / `--height 440` | Menu sizing |
| scripts/screenshot.sh | external | editor note | `grimblast only supports png when copy is specified` | Commented constraint |
| scripts/systeminfo.sh | display | figlet font | `smslant` | Header font |
| scripts/text-extractor.sh | flags | SLURP_TIMEOUT | `10` | Region selection timeout |
| scripts/text-extractor.sh | flags | DEPS | `(grim slurp magick tesseract wl-copy timeout)` | Required tools |
| scripts/text-extractor.sh | flags | OCR_LANGUAGE default | `"eng"` | Fallback language |
| scripts/text-extractor.sh | flags | OCR pipeline | `magick -colorspace Gray -normalize -contrast-stretch 2% -sharpen 0x1.0 -resize 200%` + `tesseract --psm 6` | Preprocess + OCR |
| scripts/text-extractor.sh | flags | slurp colors | `-b "#00000080" -c "#888888ff" -w 1` | Selection overlay |
| scripts/toggle-animations.sh | state | cache_file | `$HOME/.cache/toggle_animation` | Toggle marker |
| scripts/toggle-animations.sh | guard | animation.conf check | `cat $HOME/.config/hypr/conf/animation.conf` contains `disabled` | Block toggle if disabled profile |
| scripts/toggle-scratchpad.sh | flags | CLASS | `"dev-scratchpad"` | Window class |
| scripts/toggle-scratchpad.sh | flags | terminal command | `kitty --class "$CLASS" --title "Scratchpad" -e tmux new-session -A -s scratch &` | Persistent scratchpad |
| scripts/toggleallfloat.sh | action | command | `hyprctl dispatch workspaceopt allfloat` | Toggle all floating |
| scripts/toggleallfloat.sh | notification | message | `"Windows on this workspace toggled to floating/tiling"` | Notification |
| scripts/xdg.sh | timers | _sleep1 / _sleep2 / _sleep3 / _sleep4 | `0.1 / 0.5 / 2 / 1` | Startup delays |
| scripts/xdg.sh | env | dbus | `dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=hyprland` | Export env |
| scripts/xdg.sh | portals | killall list | `xdg-desktop-portal-hyprland / gnome / kde / lxqt / wlr / gtk / xdg-desktop-portal` | Clean portals |
| scripts/xdg.sh | services | stop/start list | `pipewire / wireplumber / xdg-desktop-portal(-gnome/-kde/-wlr/-hyprland)` | Restart stack |
| effects/wallpaper/blackwhite | effect | command | `magick $IMAGE_PATH -set colorspace Gray -separate -average $IMAGE_PATH` | Grayscale |
| effects/wallpaper/blackwhite-blur | effect | command 1 | `magick $IMAGE_PATH -set colorspace Gray -separate -average $IMAGE_PATH` | Grayscale |
| effects/wallpaper/blackwhite-blur | effect | command 2 | `magick $IMAGE_PATH -blur "50x30" $IMAGE_PATH` | Blur |
| effects/wallpaper/blackwhite-brightness40 | effect | command 1 | `magick $IMAGE_PATH -set colorspace Gray -separate -average $IMAGE_PATH` | Grayscale |
| effects/wallpaper/blackwhite-brightness40 | effect | command 2 | `magick $IMAGE_PATH -brightness-contrast -60% $IMAGE_PATH` | 40% brightness |
| effects/wallpaper/blackwhite-brightness60 | effect | command 1 | `magick $IMAGE_PATH -set colorspace Gray -separate -average $IMAGE_PATH` | Grayscale |
| effects/wallpaper/blackwhite-brightness60 | effect | command 2 | `magick $IMAGE_PATH -brightness-contrast -40% $IMAGE_PATH` | 60% brightness |
| effects/wallpaper/blackwhite-brightness80 | effect | command 1 | `magick $IMAGE_PATH -set colorspace Gray -separate -average $IMAGE_PATH` | Grayscale |
| effects/wallpaper/blackwhite-brightness80 | effect | command 2 | `magick $IMAGE_PATH -brightness-contrast -20% $IMAGE_PATH` | 80% brightness |
| effects/wallpaper/blur1 | effect | command | `magick $IMAGE_PATH -blur "50x30" $IMAGE_PATH` | Strong blur |
| effects/wallpaper/blur1-brightness40 | effect | command 1 | `magick $IMAGE_PATH -blur "50x30" $IMAGE_PATH` | Blur |
| effects/wallpaper/blur1-brightness40 | effect | command 2 | `magick $IMAGE_PATH -brightness-contrast -60% $IMAGE_PATH` | 40% brightness |
| effects/wallpaper/blur1-brightness60 | effect | command 1 | `magick $IMAGE_PATH -blur "50x30" $IMAGE_PATH` | Blur |
| effects/wallpaper/blur1-brightness60 | effect | command 2 | `magick $IMAGE_PATH -brightness-contrast -40% $IMAGE_PATH` | 60% brightness |
| effects/wallpaper/blur1-brightness80 | effect | command 1 | `magick $IMAGE_PATH -blur "50x30" $IMAGE_PATH` | Blur |
| effects/wallpaper/blur1-brightness80 | effect | command 2 | `magick $IMAGE_PATH -brightness-contrast -20% $IMAGE_PATH` | 80% brightness |
| effects/wallpaper/blur2 | effect | command | `magick $IMAGE_PATH -blur "10x30" $IMAGE_PATH` | Lighter blur |
| effects/wallpaper/negate | effect | command | `magick $IMAGE_PATH -negate $IMAGE_PATH` | Invert colors |
| effects/wallpaper/negate-brightness40 | effect | command 1 | `magick $IMAGE_PATH -negate $IMAGE_PATH` | Invert |
| effects/wallpaper/negate-brightness40 | effect | command 2 | `magick $IMAGE_PATH -brightness-contrast -60% $IMAGE_PATH` | 40% brightness |
| effects/wallpaper/negate-brightness60 | effect | command 1 | `magick $IMAGE_PATH -negate $IMAGE_PATH` | Invert |
| effects/wallpaper/negate-brightness60 | effect | command 2 | `magick $IMAGE_PATH -brightness-contrast -40% $IMAGE_PATH` | 60% brightness |
| effects/wallpaper/negate-brightness80 | effect | command 1 | `magick $IMAGE_PATH -negate $IMAGE_PATH` | Invert |
| effects/wallpaper/negate-brightness80 | effect | command 2 | `magick $IMAGE_PATH -brightness-contrast -20% $IMAGE_PATH` | 80% brightness |
| cache/aur.sh | AUR helper | value | `yay` | Package manager for AUR operations |
| cache/bluetooth.sh | Bluetooth app | value | `blueman-manager` | Bluetooth manager |
| cache/blur.sh | blur effect | value | `50x30` | Blur radius used by wallpaper blur effects |
| cache/browser.sh | Browser | value | `brave` | Default browser |
| cache/calculator.sh | Calculator | value | `flatpak run org.gnome.Calculator` | Calculator command |
| cache/dock-autohide | Dock flag | — | *(empty file = flag off)* | Dock autohide disabled |
| cache/dock-border.css | Dock border | window.border-width | `2px` | Dock border width |
| cache/dock-theme | Dock theme | value | `glass` | Dock style |
| cache/editor.sh | Editor | shebang | `#!/bin/bash` | Script interpreter |
| cache/editor.sh | Editor | command | `gnome-text-editor "$@"` | Default text editor |
| cache/email | Email client | value | `evolution` | Mail app |
| cache/emojipicker.sh | Emoji picker | value | `flatpak run com.tomjwatson.Emote` | Emoji app |
| cache/filemanager | File manager | value | `nautilus --new-window` | File manager command |
| cache/hide-fastfetch | Sidebar flag | — | *(empty file = flag off)* | Fastfetch not hidden |
| cache/hyprpicker.sh | Color picker | value | `hyprpicker -a -f hex` | Pick color as hex |
| cache/installupdates.sh | Update installer | command | `$(cat ~/.config/ml4w/settings/terminal.sh) --class dotfiles-floating -e ~/.config/ml4w/scripts/ml4w-install-system-updates` | Terminal class + update script |
| cache/kitty-cursor-trail.conf | Kitty flag | cursor_trail | `1` | Kitty cursor trail on |
| cache/launcher | Launcher | value | `rofi` | App launcher (overrides Walker) |
| cache/networkmanager.sh | Network manager | command | `$(cat ~/.config/ml4w/settings/terminal.sh) --class dotfiles-floating -e ~/.config/ml4w/scripts/ml4w-network` | Terminal network tool |
| cache/rofi-border-radius.rasi | Rofi style | border-radius | `2em` | Rofi corners |
| cache/rofi-border.rasi | Rofi style | border-width | `1px` | Rofi border |
| cache/rofi-font.rasi | Rofi style | configuration.font | `"Fira Sans 11"` | Rofi font |
| cache/rofi_bordersize.sh | Rofi flag | value | `3` | Rofi border size |
| cache/screenshot-editor | Screenshot editor | value | `pinta` | GRIMBLAST_EDITOR |
| cache/screenshot-filename | Screenshot setting | value | `screenshot_$(date +%Y%m%d_%H%M%S).jpg` | Filename pattern (script default uses `%d%m%Y`) |
| cache/screenshot-folder | Screenshot setting | value | `~/Pictures` | Save folder |
| cache/sidepad-active | Sidebar panel | value | `ml4w-kitty` | Active sidepad |
| cache/sidepad-position | Sidebar panel | value | `left` | Sidepad side |
| cache/software.sh | Software flag | — | *(empty file = flag off)* | Software entry disabled |
| cache/statusbar | Status bar | value | `quickshell` | Bar backend (not waybar) |
| cache/statusbar.json | Status bar flags | bar.enabled | `false` | Legacy waybar bar disabled |
| cache/statusbar.json | Status bar flags | bar.alwaysExpanded | `false` | Bar not always expanded |
| cache/system-monitor.sh | System monitor launcher | command | `$(cat ~/.config/ml4w/settings/terminal.sh) --class dotfiles-floating -e btop` | Terminal btop |
| cache/systemmonitor | System monitor | value | `btop` | Monitor app |
| cache/terminal.sh | Terminal | value | `kitty` | Terminal emulator (conflicts with custom.lua SUPER+RETURN = kitty) |
| cache/walker-theme | Walker theme | value | `glass` | Walker style |
| cache/wallpaper-app | Wallpaper app | value | `quickshell` | Backend; skips ML4W restore in autostart |
| cache/wallpaper-automation | Wallpaper timer | value | `60` | Seconds between rotations |
| cache/wallpaper-effect | Wallpaper effect | value | `off` | No effect applied |
| cache/wallpaper-folder | Wallpaper folder | value | `$HOME/.config/ml4w/wallpapers` | Wallpaper source |
| cache/wallpaper-transition-effect | Wallpaper transition | value | `simple` | Transition style |
| cache/waybar-disabled | Waybar flag | — | *(empty file = flag off)* | Waybar not disabled marker |
| cache/waybar-theme.sh | Waybar theme | value | `/ml4w-glass-center;/ml4w-glass-center/default` | Theme path |
| cache/waybar_appmenu.sh | Waybar module flag | value | `True` | App menu shown |
| cache/waybar_backlight.sh | Waybar module flag | value | `False` | Backlight hidden |
| cache/waybar_chatgpt.sh | Waybar module flag | value | `True` | ChatGPT module shown |
| cache/waybar_custom_timedateformat.sh | Waybar format | — | *(empty file)* | No custom datetime format |
| cache/waybar_dateformat.sh | Waybar format | value | `%a` | Abbreviated weekday |
| cache/waybar_network.sh | Waybar module flag | value | `True` | Network shown |
| cache/waybar_quicklinks.sh | Waybar module flag | value | `False` | Quicklinks hidden |
| cache/waybar_screenlock.sh | Waybar module flag | value | `True` | Screenlock shown |
| cache/waybar_settings.sh | Waybar module flag | value | `True` | Settings shown |
| cache/waybar_systray.sh | Waybar module flag | value | `True` | Systray shown |
| cache/waybar_taskbar.sh | Waybar module flag | value | `False` | Taskbar hidden |
| cache/waybar_timeformat.sh | Waybar format | value | `%H:%M` | Clock format |
| cache/waybar_timezone.sh | Waybar format | — | *(empty file)* | System timezone used |
| cache/waybar_toggle.sh | Waybar flag | value | `True` | Waybar shown |
| cache/waybar_window.sh | Waybar module flag | value | `True` | Window module shown |
| cache/waybar_workspaces.sh | Waybar module flag | value | `5` | Show 5 workspaces |
| cache-dotfiles/current_wallpaper | state | path | `/home/sahil/.config/ml4w/wallpapers/dark10-dunes-moonlit.png` | Current wallpaper |
| cache-dotfiles/current_wallpaper.rasi | state | current-image | `url("/home/sahil/.cache/ml4w/hyprland-dotfiles/blurred_wallpaper.png", height)` | Rofi wallpaper preview |
| cache/waybar-quicklinks.json | custom/quicklink_browser | format | `` | Browser icon |
| cache/waybar-quicklinks.json | custom/quicklink_browser | on-click | `~/.config/ml4w/settings/browser.sh` | Open browser |
| cache/waybar-quicklinks.json | custom/quicklink_browser | tooltip-format | `Open Browser` | Tooltip |
| cache/waybar-quicklinks.json | custom/quicklink_filemanager | format / on-click / tooltip-format | ` / ~/.config/ml4w/settings/filemanager / Open Filemanager` | File manager link |
| cache/waybar-quicklinks.json | custom/quicklink_email | format / on-click / tooltip-format | ` / ~/.config/ml4w/settings/email / Open Email Client` | Email link |
| cache/waybar-quicklinks.json | custom/quicklink_chromium | format / on-click / tooltip-format | ` / chromium / Open Chromium` | Chromium link (not in group) |
| cache/waybar-quicklinks.json | custom/quicklink_edge | format / on-click / tooltip-format | ` / edge / Open Edge` | Edge link (not in group) |
| cache/waybar-quicklinks.json | custom/quicklink_firefox | format / on-click / tooltip-format | ` / firefox / Open Firefox` | Firefox link (not in group) |
| cache/waybar-quicklinks.json | custom/quicklink_thunderbird | format / on-click / tooltip-format | ` / thunderbird / Open Thunderbird` | Thunderbird link (not in group) |
| cache/waybar-quicklinks.json | custom/quicklink_calculator | format / on-click / tooltip-format | ` / ~/.config/ml4w/settings/calculator.sh / Open calculator` | Calculator link (not in group) |
| cache/waybar-quicklinks.json | custom/quicklinkempty | — | `{}` | Required empty spacer |
| cache/waybar-quicklinks.json | group/quicklinks | orientation | `horizontal` | Horizontal group |
| cache/waybar-quicklinks.json | group/quicklinks | modules | `[ "custom/quicklink_browser", "custom/quicklink_email", "custom/quicklink_filemanager", "custom/quicklinkempty" ]` | Active quicklinks order |
---

## DISABLED / COMMENTED

| File | Section/context | Parameter/key | Exact value | Purpose/effect (short) |
|---|---|---|---|---|
| hypridle.conf | general | lock_cmd (alternative) | `playerctl --all-players pause && pidof hyprlock \|\| hyprlock` | Alternative: pause audio before locking; line 2 wins |
| hypridle.conf | listener (keyboard backlight) | timeout | `480` | Would dim keyboard backlight after 8 min |
| hypridle.conf | listener (keyboard backlight) | on-timeout | `brightnessctl -sd rgb:kbd_backlight set 0` | Would turn off keyboard backlight |
| hypridle.conf | listener (keyboard backlight) | on-resume | `brightnessctl -rd rgb:kbd_backlight` | Would restore keyboard backlight |
| hyprlock.conf | image (avatar) | reload_cmd | *(empty — comment explains: command to get new path; don't use follow commands like tail -F)* | No dynamic reload |
| conf/layouts/default.lua | master | new_status | `"master"` | Commented out for compatibility reasons |
| conf/layouts/laptop.lua | master | new_status | `"master"` | Commented out for compatibility reasons (ACTIVE layout uses default) |
| conf/keybindings/default.lua | Windows | SUPER + Q (alternative) | `hl.dsp.window.close()`, desc "Kill active window" | Simple close instead of killactive.sh; disabled |
| conf/keybindings/default.lua | Windows | SUPER + SHIFT + G | `hl.dsp.group.active("f")`, desc "Switch to next group window" | Group navigation; disabled |
| conf/keybindings/default.lua | Workspace scroll (old) | SUPER + mouse_down | `hl.dsp.focus({ workspace = "e+1" })`, desc "Switch to next workspace" | Unthrottled; replaced by throttled version |
| conf/keybindings/default.lua | Workspace scroll (old) | SUPER + mouse_up | `hl.dsp.focus({ workspace = "e-1" })`, desc "Switch to previous workspace" | Unthrottled; replaced by throttled version |
| conf/animations/default.lua | "Default" legacy alternatives | animation layers | `{ enabled=true, speed=2, bezier="md3_decel", style="slide" }` | Replaced by layersIn/layersOut |
| conf/animations/default.lua | "Default" legacy alternatives | animation workspaces (alt 1) | `{ enabled=true, speed=2.5, bezier="softAcDecel", style="slide" }` | Legacy alternative |
| conf/animations/default.lua | "Default" legacy alternatives | animation workspaces (alt 2) | `{ enabled=true, speed=7, bezier="menu_decel", style="slidefade 15%" }` | Legacy alternative; slidevert active instead |
| conf/animations/default.lua | "Default" legacy alternatives | animation specialWorkspace (alt) | `{ enabled=true, speed=3, bezier="md3_decel", style="slidefadevert 15%" }` | Legacy alternative; slidevert active instead |
| scripts/screenshot.sh | options | option_time_4 (custom) | `"Custom (in seconds)"` | Roadmap item |
| scripts/moveTo.sh | logging | file log line | `echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> ~/moveto_log.txt` | Debug file logging; stdout used instead |
| scripts/xdg.sh | autostart | waybar launch | `~/.config/waybar/launch.sh` | Waybar handled by conf/autostart.lua instead |


---

<a id="noctalia-parameters"></a>
# Noctalia / Hyprland parameter sheet

Source files: `mydotfiles/.config/noctalia/config.toml` (365 lines), `~/.local/state/noctalia/settings.toml` (137 lines, GUI-managed, overrides config.toml), `~/.local/state/noctalia/state.toml` (35 lines), `~/.config/noctalia/config.toml` (byte-for-byte identical to the mydotfiles copy — rows not duplicated), `mydotfiles/.config/hypr-noctalia/hyprland.conf` (392 lines), `mydotfiles/.config/hypr-noctalia/hypridle.conf` (20 lines).

Effective/runtime values marked `config-get` were measured live from the running Noctalia session (`noctalia msg config-get <path>`); `noctalia msg status` returned `{ barVisible: true, panelOpen: false, activePanelId: null, locked: false }`. Values shown in single quotes are the CLI's literal output. CONFLICT = config.toml and settings.toml disagree; settings.toml wins.

| File | Section | Parameter/key | Value in config.toml | Effective/runtime value (settings.toml / config-get) | Purpose (short) |
|---|---|---|---|---|---|
| config.toml (mydotfiles) | theme | source | "builtin" | 'builtin' | Theme source (builtin/community/custom) |
| config.toml (mydotfiles) | theme | custom_palette | "Peach" | 'Peach' | Custom palette name |
| config.toml (mydotfiles) | theme | mode | "dark" | 'dark' | App light/dark mode |
| config.toml (mydotfiles) | theme | shell_mode | "dark" | 'dark' | Shell light/dark mode |
| config.toml (mydotfiles) | shell | settings_window_translucent | true | true | Translucent settings window |
| config.toml (mydotfiles) | shell | corner_radius_scale | 1.35 | 1.3500000238418579 | Global corner-radius multiplier |
| config.toml (mydotfiles) | shell | offline_mode | false | false | Disable network features |
| config.toml (mydotfiles) | shell | shared_gl_context | true | true | Share one GL context across surfaces |
| config.toml (mydotfiles) | shell | font_family | "Fira Sans"  **CONFLICT** | 'Inter' | Shell UI font family |
| config.toml (mydotfiles) | shell | popup_shadows | true | true | Shadows on popups |
| config.toml (mydotfiles) | shell.animation | speed | 1.6 | 1.6000000238418579 | Shell animation speed multiplier |
| config.toml (mydotfiles) | shell.animation | enabled | true | true | Enable shell animations |
| config.toml (mydotfiles) | shell.shadow | alpha | 0.38 | 0.37999999523162842 | Shell shadow alpha |
| config.toml (mydotfiles) | shell.panel | control_center_position | "center" | 'center' | Control-center anchor position |
| config.toml (mydotfiles) | shell.panel | control_center_placement | "floating" | 'floating' | Control-center floating/attached |
| config.toml (mydotfiles) | shell.panel | list_item_background | true | true | Background behind list items |
| config.toml (mydotfiles) | shell.panel | border_color | "#7aa2f7aa" | '#7AA2F7AA' | Panel border color |
| config.toml (mydotfiles) | shell.panel | border_width | 1.5 | 1.5 | Panel border width |
| config.toml (mydotfiles) | shell.panel | transparency_mode | "glass" | 'glass' | Panel transparency mode (glass) |
| config.toml (mydotfiles) | backdrop | enabled | true | true | Enable backdrop blur/tint behind surfaces |
| config.toml (mydotfiles) | backdrop | blur_intensity | 0.55 | 0.55000001192092896 | Backdrop blur strength |
| config.toml (mydotfiles) | backdrop | tint_intensity | 0.15 | 0.15000000596046448 | Backdrop tint strength |
| config.toml (mydotfiles) | lockscreen | blur_intensity | 0.35 | 0.34999999403953552 | Lockscreen wallpaper blur |
| config.toml (mydotfiles) | lockscreen | transition | [] | [] | Lockscreen transition preset |
| config.toml (mydotfiles) | bar.main | panel_overlap | 1 | 1 | Bar overlap count |
| config.toml (mydotfiles) | bar.main | border | "outline_variant" | 'outline_variant' | Bar border token |
| config.toml (mydotfiles) | bar.main | radius_bottom_right | 16 | 16 | Bar bottom-right radius |
| config.toml (mydotfiles) | bar.main | radius_bottom_left | 16 | 16 | Bar bottom-left radius |
| config.toml (mydotfiles) | bar.main | radius_top_right | 16 | 16 | Bar top-right radius |
| config.toml (mydotfiles) | bar.main | radius_top_left | 16 | 16 | Bar top-left radius |
| config.toml (mydotfiles) | bar.main | hover_highlight | true | true | Highlight bar on hover |
| config.toml (mydotfiles) | bar.main | show_on_workspace_switch | true  **CONFLICT** | false | Show bar during workspace switch |
| config.toml (mydotfiles) | bar.main | auto_hide_reserve_space | true | true | Reserve space while auto-hidden |
| config.toml (mydotfiles) | bar.main | capsule_opacity | 0.78 | 0.77999997138977051 | Widget capsule opacity |
| config.toml (mydotfiles) | bar.main | font_weight | 600 | 600 | Bar font weight |
| config.toml (mydotfiles) | bar.main | contact_shadow | true | true | ContactShadow on bar |
| config.toml (mydotfiles) | bar.main | border_width | 1.0 | 1.0 | Bar border width |
| config.toml (mydotfiles) | bar.main | background_opacity | 0.42 | 0.41999998688697815 | Bar background opacity |
| config.toml (mydotfiles) | bar.main | compositor_blur | true | true | Compositor blur on bar |
| config.toml (mydotfiles) | bar.main | shadow | true | true | Bar drop shadow |
| config.toml (mydotfiles) | bar.main | smart_auto_hide | true | true | Smart auto-hide (hide on fullscreen) |
| config.toml (mydotfiles) | bar.main | auto_hide | false | false | Auto-hide bar |
| config.toml (mydotfiles) | bar.main | reserve_space | true  **CONFLICT** | false | Bar reserves layout space |
| config.toml (mydotfiles) | bar.main | capsule | true | true | Use capsule grouping |
| config.toml (mydotfiles) | bar.main | thickness | 32 | 32 | Bar thickness (px) |
| config.toml (mydotfiles) | bar.main | padding | 12 | 12 | Bar inner padding (px) |
| config.toml (mydotfiles) | bar.main | widget_spacing | 5 | 5 | Spacing between bar widgets |
| config.toml (mydotfiles) | bar.main | radius | 16 | 16 | Bar corner radius |
| config.toml (mydotfiles) | bar.main | capsule_padding | 3 | 3.0 | Capsule inner padding |
| config.toml (mydotfiles) | bar.main | capsule_thickness | 0.72 | 0.72000002861022949 | Capsule thickness factor |
| config.toml (mydotfiles) | bar.main | capsule_radius | 14.0 | 14.0 | Capsule radius |
| config.toml (mydotfiles) | bar.main | capsule_border | "outline_variant" | 'outline_variant' | Capsule border token |
| config.toml (mydotfiles) | bar.main | capsule_border_width | 1.0 | 1.0 | Capsule border width |
| config.toml (mydotfiles) | bar.main | margin_ends | "8%" | '8%' | Bar end margins |
| config.toml (mydotfiles) | bar.main | margin_edge | 6 | 6 | Bar edge margin (px) |
| config.toml (mydotfiles) | bar.main | concave_edge_corners | true | true | Concave corners at screen edges |
| config.toml (mydotfiles) | bar.main | start | ["group:g0", "workspaces", "active_window"] | [ 'group:g0', 'workspaces', 'active_window' ] | Left widget order |
| config.toml (mydotfiles) | bar.main | center | ["clock"] | [ 'clock' ] | Center widget order |
| config.toml (mydotfiles) | bar.main | end | ["media", "wallpaper", "clipboard", "screenshot", "group:g1", "group:g3"] | [ 'media', 'wallpaper', 'clipboard', 'screenshot', 'group:g1', 'group:g3' ] | Right widget order |
| config.toml (mydotfiles) | bar.main.capsule_group[g1] | id | "g1" (not overridden) | "g1" | Capsule group id |
| config.toml (mydotfiles) | bar.main.capsule_group[g1] | members | ["network", "bluetooth", "volume", "brightness", "battery", "sysmon"] (not overridden) | ["network", "bluetooth", "volume", "brightness", "battery", "sysmon"] | Capsule group members |
| config.toml (mydotfiles) | bar.main.capsule_group[g1] | fill | "surface_container_high" (not overridden) | "surface_container_high" | Capsule group fill |
| config.toml (mydotfiles) | bar.main.capsule_group[g1] | foreground | "primary" (not overridden) | "primary" | Capsule group foreground |
| config.toml (mydotfiles) | bar.main.capsule_group[g1] | padding | 6.0 (not overridden) | 6.0 | Capsule group padding |
| config.toml (mydotfiles) | bar.main.capsule_group[g1] | radius | 16 (not overridden) | 16 | Capsule group radius |
| config.toml (mydotfiles) | bar.main.capsule_group[g1] | border | "primary" (not overridden) | "primary" | Capsule group border |
| config.toml (mydotfiles) | bar.main.capsule_group[g1] | border_width | 1.0 (not overridden) | 1.0 | Capsule group border width |
| config.toml (mydotfiles) | bar.main.capsule_group[g1] | opacity | 0.86 (not overridden) | 0.86 | Capsule group opacity |
| config.toml (mydotfiles) | bar.main.capsule_group[g1] | enabled | true (not overridden) | true | Capsule group enabled |
| config.toml (mydotfiles) | bar.main.capsule_group[g1] | accordion | false (not overridden) | false | Capsule group accordion |
| config.toml (mydotfiles) | bar.main.capsule_group[g1] | widget_spacing | 8 (not overridden) | 8 | Capsule group widget spacing |
| config.toml (mydotfiles) | bar.main.capsule_group[g0] | id | "g0" (not overridden) | "g0" | Capsule group id |
| config.toml (mydotfiles) | bar.main.capsule_group[g0] | members | ["arch", "launcher", "cat", "pomo"] (not overridden) | ["arch", "launcher", "cat", "pomo"] | Capsule group members |
| config.toml (mydotfiles) | bar.main.capsule_group[g0] | fill | "surface_container_high" (not overridden) | "surface_container_high" | Capsule group fill |
| config.toml (mydotfiles) | bar.main.capsule_group[g0] | foreground | "primary" (not overridden) | "primary" | Capsule group foreground |
| config.toml (mydotfiles) | bar.main.capsule_group[g0] | padding | 5.0 (not overridden) | 5.0 | Capsule group padding |
| config.toml (mydotfiles) | bar.main.capsule_group[g0] | radius | 12 (not overridden) | 12 | Capsule group radius |
| config.toml (mydotfiles) | bar.main.capsule_group[g0] | border | "outline_variant" (not overridden) | "outline_variant" | Capsule group border |
| config.toml (mydotfiles) | bar.main.capsule_group[g0] | border_width | 1.0 (not overridden) | 1.0 | Capsule group border width |
| config.toml (mydotfiles) | bar.main.capsule_group[g0] | opacity | 0.86 (not overridden) | 0.86 | Capsule group opacity |
| config.toml (mydotfiles) | bar.main.capsule_group[g0] | enabled | true (not overridden) | true | Capsule group enabled |
| config.toml (mydotfiles) | bar.main.capsule_group[g0] | accordion | false (not overridden) | false | Capsule group accordion |
| config.toml (mydotfiles) | bar.main.capsule_group[g0] | widget_spacing | 6 (not overridden) | 6 | Capsule group widget spacing |
| config.toml (mydotfiles) | bar.main.capsule_group[g3] | id | "g3" (not overridden) | "g3" | Capsule group id |
| config.toml (mydotfiles) | bar.main.capsule_group[g3] | members | ["tray", "notifications", "privacy", "nightlight", "caffeine", "control-center", "session"] (not overridden) | ["tray", "notifications", "privacy", "nightlight", "caffeine", "control-center", "session"] | Capsule group members |
| config.toml (mydotfiles) | bar.main.capsule_group[g3] | fill | "surface_container" (not overridden) | "surface_container" | Capsule group fill |
| config.toml (mydotfiles) | bar.main.capsule_group[g3] | foreground | "on_surface_variant" (not overridden) | "on_surface_variant" | Capsule group foreground |
| config.toml (mydotfiles) | bar.main.capsule_group[g3] | padding | 5.0 (not overridden) | 5.0 | Capsule group padding |
| config.toml (mydotfiles) | bar.main.capsule_group[g3] | radius | 12 (not overridden) | 12 | Capsule group radius |
| config.toml (mydotfiles) | bar.main.capsule_group[g3] | border | "outline_variant" (not overridden) | "outline_variant" | Capsule group border |
| config.toml (mydotfiles) | bar.main.capsule_group[g3] | border_width | 1.0 (not overridden) | 1.0 | Capsule group border width |
| config.toml (mydotfiles) | bar.main.capsule_group[g3] | opacity | 0.86 (not overridden) | 0.86 | Capsule group opacity |
| config.toml (mydotfiles) | bar.main.capsule_group[g3] | enabled | true (not overridden) | true | Capsule group enabled |
| config.toml (mydotfiles) | bar.main.capsule_group[g3] | accordion | false (not overridden) | false | Capsule group accordion |
| config.toml (mydotfiles) | bar.main.capsule_group[g3] | widget_spacing | 6 (not overridden) | 6 | Capsule group widget spacing |
| config.toml (mydotfiles) | bar.main.dead_zone.actions | left | "panel-toggle launcher" | 'panel-toggle launcher' | Click action on left dead zone |
| config.toml (mydotfiles) | bar.main.dead_zone.actions | right | "panel-toggle control-center" | 'panel-toggle control-center' | Click action on right dead zone |
| config.toml (mydotfiles) | bar.main.dead_zone.actions | middle | "exec kitty" | 'exec kitty' | Click action on middle dead zone |
| config.toml (mydotfiles) | bar.main.dead_zone.actions | scroll_up | "workspace-switch prev" | 'workspace-switch prev' | Scroll-up action on dead zone |
| config.toml (mydotfiles) | bar.main.dead_zone.actions | scroll_down | "workspace-switch next" | 'workspace-switch next' | Scroll-down action on dead zone |
| config.toml (mydotfiles) | osd.kinds | media | false | false | OSD for media changes |
| config.toml (mydotfiles) | osd.kinds | media_volume | false | false | OSD for media volume changes |
| config.toml (mydotfiles) | system.monitor | enabled | true | true | Enable system monitor polling |
| config.toml (mydotfiles) | system.monitor | cpu_poll_seconds | 10.0 | 10.0 | CPU poll interval (s) |
| config.toml (mydotfiles) | system.monitor | memory_poll_seconds | 10.0 | 10.0 | Memory poll interval (s) |
| config.toml (mydotfiles) | system.monitor | gpu_poll_seconds | 0.0 | 0.0 | GPU poll interval (s, 0=off) |
| config.toml (mydotfiles) | system.monitor | network_poll_seconds | 0.0 | 0.0 | Network poll interval (s, 0=off) |
| config.toml (mydotfiles) | system.monitor | disk_poll_seconds | 0.0 | 0.0 | Disk poll interval (s, 0=off) |
| config.toml (mydotfiles) | shell.launcher | width | 820 | 820 | Launcher width (px) |
| config.toml (mydotfiles) | shell.launcher | track_usage | true | true | Track app launch counts |
| config.toml (mydotfiles) | shell.launcher | sort_by_usage | false | false | Sort apps by usage |
| config.toml (mydotfiles) | shell.launcher | colorize_icons | false | false | Colorize app icons |
| config.toml (mydotfiles) | shell.launcher | fetch_exchange_rates | false | false | Fetch exchange rates for calculator |
| config.toml (mydotfiles) | shell.launcher | default_view | "all" | 'all' | Default launcher view |
| config.toml (mydotfiles) | shell.launcher | show_app_actions | true | true | Show desktop-file app actions |
| config.toml (mydotfiles) | shell.launcher | category_icons_only | true | true | Show only icons in category list |
| config.toml (mydotfiles) | shell.launcher | search_position | "top" | 'top' | Search box position |
| config.toml (mydotfiles) | shell.launcher | pinned | ["kitty", "brave-browser", "org.gnome.Nautilus", "obsidian", "zen"] | [ 'kitty', 'brave-browser', 'org.gnome.Nautilus', 'obsidian', 'zen' ] | Pinned launcher apps |
| config.toml (mydotfiles) | shell.launcher.dmenu.entry.eyecare | command | "echo 'Night light'; echo 'Blue-light filter'; echo 'Grayscale'; echo 'Dim'; echo 'Reset all'" | "echo 'Night light'; echo 'Blue-light filter'; echo 'Grayscale'; echo 'Dim'; echo 'Reset all'" | D-menu 'eyecare' command |
| config.toml (mydotfiles) | shell.launcher.dmenu.entry.eyecare | exec | "/home/sahil/.local/bin/eye-care.sh {selection}" | '/home/sahil/.local/bin/eye-care.sh {selection}' | D-menu 'eyecare' exec |
| config.toml (mydotfiles) | shell.launcher.dmenu.entry.eyecare | prefix | "eye" | 'eye' | D-menu 'eyecare' prefix |
| config.toml (mydotfiles) | shell.launcher.dmenu.entry.eyecare | label | "Eye care" | 'Eye care' | D-menu 'eyecare' label |
| config.toml (mydotfiles) | shell.launcher.dmenu.entry.eyecare | glyph | "eye" | 'eye' | D-menu 'eyecare' glyph |
| config.toml (mydotfiles) | shell.launcher.dmenu.entry.eyecare | global | false | false | D-menu 'eyecare' global |
| config.toml (mydotfiles) | shell.launcher.dmenu.entry.glass | command | "/home/sahil/.local/bin/glass-mode.sh --list" | '/home/sahil/.local/bin/glass-mode.sh --list' | D-menu 'glass' command |
| config.toml (mydotfiles) | shell.launcher.dmenu.entry.glass | exec | "/home/sahil/.local/bin/glass-mode.sh {selection}" | '/home/sahil/.local/bin/glass-mode.sh {selection}' | D-menu 'glass' exec |
| config.toml (mydotfiles) | shell.launcher.dmenu.entry.glass | prefix | "glass" | 'glass' | D-menu 'glass' prefix |
| config.toml (mydotfiles) | shell.launcher.dmenu.entry.glass | label | "Glass mode" | 'Glass mode' | D-menu 'glass' label |
| config.toml (mydotfiles) | shell.launcher.dmenu.entry.glass | glyph | "eye" | 'eye' | D-menu 'glass' glyph |
| config.toml (mydotfiles) | shell.launcher.dmenu.entry.glass | global | false | false | D-menu 'glass' global |
| config.toml (mydotfiles) | shell.window_switcher | colorize_icons | false | false | window_switcher colorize icons |
| config.toml (mydotfiles) | shell.window_switcher | style | "icons" | 'icons' | window_switcher style |
| config.toml (mydotfiles) | shell.window_switcher | mru | true | true | window_switcher mru |
| config.toml (mydotfiles) | shell.window_switcher | show_caption | true | true | window_switcher show caption |
| config.toml (mydotfiles) | shell.window_switcher | show_count | true | true | window_switcher show count |
| config.toml (mydotfiles) | shell.window_switcher | show_app_icon | true | true | window_switcher show app icon |
| config.toml (mydotfiles) | shell.window_switcher | show_all_outputs | true | true | window_switcher show all outputs |
| config.toml (mydotfiles) | shell.window_switcher | current_workspace_only | false | false | window_switcher current workspace only |
| config.toml (mydotfiles) | shell.screenshot | directory | "/home/sahil/Pictures/screenshots" | '/home/sahil/Pictures/screenshots' | screenshot directory |
| config.toml (mydotfiles) | control_center | hidden_tabs | ["weather", "calendar", "screen-time"] | [ 'weather', 'calendar', 'screen-time' ] | Hidden control-center tabs |
| config.toml (mydotfiles) | control_center.media | show_visualizer | false  **CONFLICT** | true | Media visualizer in control center |
| config.toml (mydotfiles) | control_center.shortcuts#1 | type | "wifi" | '"wifi"' | Widget type |
| config.toml (mydotfiles) | control_center.shortcuts#2 | type | "bluetooth" | '"bluetooth"' | Widget type |
| config.toml (mydotfiles) | control_center.shortcuts#3 | type | "nightlight" | '"nightlight"' | Widget type |
| config.toml (mydotfiles) | control_center.shortcuts#4 | type | "caffeine" | '"caffeine"' | Widget type |
| config.toml (mydotfiles) | control_center.shortcuts#5 | type | "notification" | '"notification"' | Widget type |
| config.toml (mydotfiles) | control_center.shortcuts#6 | type | "power_profile" | '"power_profile"' | Widget type |
| config.toml (mydotfiles) | wallpaper.automation | enabled | false | false | Automatic wallpaper rotation |
| config.toml (mydotfiles) | plugins | auto_update | "none" | 'none' | Plugin auto-update mode |
| config.toml (mydotfiles) | plugins | enabled | ["noctalia/notes", "cleboost/ssh-launcher", "cleboost/zed-provider", "nightwatch75/file-search", "noctalia/bongocat", "thepunkoff/pomodoro"]  **CONFLICT** | [     'noctalia/notes',     'cleboost/ssh-launcher',     'nightwatch75/file-search',     'cleboost/zed-provider',     'noctalia/bongocat',     'thepunkoff/pomodoro' ] | Enabled plugin ids |
| config.toml (mydotfiles) | plugin_settings."noctalia/notes" | notes_dir | "/home/sahil/Documents/noctalia-notes" | '"/home/sahil/Documents/noctalia-notes"' | "noctalia/notes" notes dir |
| config.toml (mydotfiles) | plugin_settings."noctalia/notes" | extension | "md" | '"md"' | "noctalia/notes" extension |
| config.toml (mydotfiles) | plugin_settings."cleboost/ssh-launcher" | config_path | "/home/sahil/.ssh/config" | '"/home/sahil/.ssh/config"' | "cleboost/ssh-launcher" config path |
| config.toml (mydotfiles) | plugin_settings."cleboost/ssh-launcher" | max_results | 30 | '30' | "cleboost/ssh-launcher" max results |
| config.toml (mydotfiles) | plugin_settings."cleboost/zed-provider" | db_path | "/home/sahil/.local/share/zed/db/0-stable/db.sqlite" | '"/home/sahil/.local/share/zed/db/0-stable/db.sqlite"' | "cleboost/zed-provider" db path |
| config.toml (mydotfiles) | plugin_settings."cleboost/zed-provider" | max_results | 20 | '20' | "cleboost/zed-provider" max results |
| config.toml (mydotfiles) | plugin_settings."cleboost/zed-provider" | new_window | false | 'false' | "cleboost/zed-provider" new window |
| config.toml (mydotfiles) | plugin_settings."nightwatch75/file-search" | search_folder | "/home/sahil" | '"/home/sahil"' | "nightwatch75/file-search" search folder |
| config.toml (mydotfiles) | plugin_settings."nightwatch75/file-search" | exclude_dirs | ".git, node_modules, .cache, .venv" | '".git, node_modules, .cache, .venv"' | "nightwatch75/file-search" exclude dirs |
| config.toml (mydotfiles) | plugin_settings."nightwatch75/file-search" | space_enabled | false | 'false' | "nightwatch75/file-search" space enabled |
| config.toml (mydotfiles) | widget.active_window | display | "icon_and_text" | 'icon_and_text' | Active-window title display mode |
| config.toml (mydotfiles) | widget.active_window | max_length | 145 | 145 | Max title length (chars) |
| config.toml (mydotfiles) | widget.active_window | title_scroll | "on_hover" | 'on_hover' | Title scrolling behavior |
| config.toml (mydotfiles) | widget.active_window | show_empty_label | false | false | Show label when no window |
| config.toml (mydotfiles) | widget.clock | color | "on_surface" | 'on_surface' | Clock text color token |
| config.toml (mydotfiles) | widget.clock | capsule_fill | "surface_container_highest" | 'surface_container_highest' | Clock capsule fill token |
| config.toml (mydotfiles) | widget.clock | format | "{:%a %d %b  %H:%M}" | '{:%a %d %b  %H:%M}' | Clock format string |
| config.toml (mydotfiles) | widget.clock | tooltip_format | "%A, %B %d, %Y" | '%A, %B %d, %Y' | Clock tooltip date format |
| config.toml (mydotfiles) | widget.clock | font_scale | 1.15 | 1.1499999999999999 | Clock font scale |
| config.toml (mydotfiles) | widget.clock | font_weight | 700 | 700 | Clock font weight |
| config.toml (mydotfiles) | widget.clock | capsule_padding | 8 | 8 | Clock capsule padding |
| config.toml (mydotfiles) | widget.clock | capsule_radius | 14 | 14 | Clock capsule radius |
| config.toml (mydotfiles) | widget.clock | capsule_border | "secondary" | 'secondary' | Clock capsule border token |
| config.toml (mydotfiles) | widget.clock | capsule_border_width | 1.0 | 1.0 | Clock capsule border width |
| config.toml (mydotfiles) | widget.privacy | hide_inactive | true | true | Hide inactive privacy indicators |
| config.toml (mydotfiles) | widget.sysmon | peek | true | true | Sysmon peek-on-hover |
| config.toml (mydotfiles) | widget.volume | color | "primary" | 'primary' | Volume widget color token |
| config.toml (mydotfiles) | widget.volume | peek | true | true | Volume peek-on-hover |
| config.toml (mydotfiles) | widget.brightness | color | "tertiary" | 'tertiary' | Brightness widget color token |
| config.toml (mydotfiles) | widget.brightness | peek | true | true | Brightness peek-on-hover |
| config.toml (mydotfiles) | widget.brightness.actions | right | "panel-open launcher /eye" | 'panel-open launcher /eye' | Right-click brightness action |
| config.toml (mydotfiles) | widget.battery | color | "primary" | 'primary' | Battery widget color token |
| config.toml (mydotfiles) | widget.battery | peek | true | true | Battery peek-on-hover |
| config.toml (mydotfiles) | widget.tray | hide_passive | true | true | Hide passive tray icons |
| config.toml (mydotfiles) | widget.tray | drawer_item_size | 20 | 20 | Tray drawer item size |
| config.toml (mydotfiles) | widget.tray | drawer_columns | 3 | 3 | Tray drawer column count |
| config.toml (mydotfiles) | widget.tray | glyph_position | "before" | 'before' | Tray glyph position |
| config.toml (mydotfiles) | widget.tray | drawer | true | true | Use tray drawer |
| config.toml (mydotfiles) | widget.tray | peek | true | true | Tray peek-on-hover |
| config.toml (mydotfiles) | widget.eye | show_glyph | true | true | Eye widget shows glyph |
| config.toml (mydotfiles) | widget.eye | type | "custom_button" | 'custom_button' | Eye widget type |
| config.toml (mydotfiles) | widget.eye | glyph | "eye" | 'eye' | Eye widget glyph |
| config.toml (mydotfiles) | widget.eye | custom_label | "" | '' | Eye widget custom label |
| config.toml (mydotfiles) | widget.eye.actions | left | "panel-open launcher /eye" | 'panel-open launcher /eye' | Left-click eye action |
| config.toml (mydotfiles) | widget.arch | type | "custom_button" | 'custom_button' | Arch widget type |
| config.toml (mydotfiles) | widget.arch | custom_image | "/home/sahil/.config/noctalia/assets/archlinux-logo.svg" | '/home/sahil/.config/noctalia/assets/archlinux-logo.svg' | Arch widget image path |
| config.toml (mydotfiles) | widget.arch | custom_image_colorize | true | true | Colorize the Arch logo |
| config.toml (mydotfiles) | widget.arch | label | "" | '' | Arch widget label |
| config.toml (mydotfiles) | widget.arch.actions | left | "panel-toggle launcher" | 'panel-toggle launcher' | Left-click Arch action |
| config.toml (mydotfiles) | notification | max_visible | 4 | 4 | Max visible notifications |
| config.toml (mydotfiles) | notification | width | 380 | 380 | Notification width (px) |
| config.toml (mydotfiles) | notification | background_opacity | 0.88 | 0.87999999523162842 | Notification background opacity |
| config.toml (mydotfiles) | osd | position | "top_right" | 'top_right' | OSD screen position |
| config.toml (mydotfiles) | osd | background_opacity | 0.88 | 0.87999999523162842 | OSD background opacity |
| config.toml (mydotfiles) | osd | hide_delay_ms | 2000 | 2000 | OSD auto-hide delay (ms) |
| config.toml (mydotfiles) | dock | position | "bottom" | 'bottom' | Dock screen position |
| config.toml (mydotfiles) | dock | pinned | ["kitty", "brave-browser", "org.gnome.Nautilus", "firefox"] | [ 'kitty', 'brave-browser', 'org.gnome.Nautilus', 'firefox' ] | Pinned dock apps |
| config.toml (mydotfiles) | dock | reserve_space | false | false | Dock reserves layout space |
| config.toml (mydotfiles) | dock | auto_hide | false | false | Dock auto-hide |
| config.toml (mydotfiles) | dock | smart_auto_hide | true | true | Dock smart auto-hide |
| config.toml (mydotfiles) | dock | enabled | true | true | Enable dock |
| config.toml (mydotfiles) | dock | launcher_position | "start" | 'start' | Launcher icon position in dock |
| config.toml (mydotfiles) | dock | active_scale | 1.05 | 1.0499999523162842 | Active dock icon scale |
| config.toml (mydotfiles) | dock | magnification_scale | 1.35 | 1.3500000238418579 | Dock magnification scale |
| config.toml (mydotfiles) | dock | icon_size | 44 | 44 | Dock icon size (px) |
| config.toml (mydotfiles) | dock | margin_edge | 8 | 8 | Dock edge margin (px) |
| config.toml (mydotfiles) | dock | radius | 20 | 20 | Dock radius |
| config.toml (mydotfiles) | dock | border_width | 1.5 | 1.5 | Dock border width |
| config.toml (mydotfiles) | dock | background_opacity | 0.72 | 0.72000002861022949 | Dock background opacity |
| config.toml (mydotfiles) | dock | compositor_blur | true | true | Compositor blur on dock |
| config.toml (mydotfiles) | widget.workspaces | change_color_on_hover | true | true | Change workspace pill color on hover |
| config.toml (mydotfiles) | widget.workspaces | hide_when_empty | false | false | Hide empty workspace buttons |
| config.toml (mydotfiles) | widget.workspaces | pill_scale | 0.85 | 0.84999999999999998 | Workspace pill scale |
| config.toml (mydotfiles) | widget.workspaces | inactive_pill_size | 1.0 | 1.0 | Inactive pill size |
| config.toml (mydotfiles) | widget.workspaces | active_pill_size | 2.4 | 2.3999999999999999 | Active pill size |
| config.toml (mydotfiles) | widget.workspaces | urgent_color | "error" | 'error' | Urgent workspace color |
| config.toml (mydotfiles) | widget.workspaces | empty_color | "outline_variant" | 'outline_variant' | Empty workspace color |
| config.toml (mydotfiles) | widget.workspaces | occupied_color | "secondary" | 'secondary' | Occupied workspace color |
| config.toml (mydotfiles) | widget.workspaces | focused_color | "primary" | 'primary' | Focused workspace color |
| config.toml (mydotfiles) | widget.workspaces | show_icons | false | false | Show workspace app icons |
| config.toml (mydotfiles) | widget.workspaces | show_labels | false | false | Show workspace labels |
| config.toml (mydotfiles) | widget.workspaces | style | "focus_hint" | 'focus_hint' | Workspace widget style |
| config.toml (mydotfiles) | widget.workspaces | type | "workspaces" | 'workspaces' | Workspace widget type |
| config.toml (mydotfiles) | widget.cat | type | "noctalia/bongocat:cat" | 'noctalia/bongocat:cat' | Bongocat widget type |
| config.toml (mydotfiles) | widget.cat | audio_spectrum | true | true | Bongocat audio spectrum |
| config.toml (mydotfiles) | widget.cat | tappy_mode | true | true | Bongocat tappy mode |
| config.toml (mydotfiles) | widget.cat | input_devices | [] | [] | Bongocat input devices |
| config.toml (mydotfiles) | widget.pomo | type | "thepunkoff/pomodoro:widget" | 'thepunkoff/pomodoro:widget' | Pomodoro widget type |
| config.toml (mydotfiles) | widget.pomo | widget-glyph-main | "brain" | 'brain' | Pomodoro main glyph |
| config.toml (mydotfiles) | widget.pomo | widget-glyph-work | "brain" | 'brain' | Pomodoro work glyph |
| config.toml (mydotfiles) | widget.pomo | widget-glyph-break | "coffee" | 'coffee' | Pomodoro break glyph |
| config.toml (mydotfiles) | plugin_settings."thepunkoff/pomodoro" | work-duration | 25 | '25' | "thepunkoff/pomodoro" work-duration |
| config.toml (mydotfiles) | plugin_settings."thepunkoff/pomodoro" | short-break-duration | 5 | '5' | "thepunkoff/pomodoro" short-break-duration |
| config.toml (mydotfiles) | plugin_settings."thepunkoff/pomodoro" | long-break-duration | 15 | '15' | "thepunkoff/pomodoro" long-break-duration |
| config.toml (mydotfiles) | plugin_settings."thepunkoff/pomodoro" | sessions-before-long-break | 4 | '4' | "thepunkoff/pomodoro" sessions-before-long-break |
| config.toml (mydotfiles) | widget.network | color | "primary" | 'primary' | Network widget color token |
| config.toml (mydotfiles) | widget.network | peek | true | true | Network peek-on-hover |
| config.toml (mydotfiles) | widget.bluetooth | color | "secondary" | 'secondary' | Bluetooth widget color token |
| config.toml (mydotfiles) | widget.bluetooth | peek | true | true | Bluetooth peek-on-hover |
| config.toml (mydotfiles) | widget.media | title_scroll | "on_hover" | 'on_hover' | Media title scrolling |
| config.toml (mydotfiles) | widget.media | max_length | 200 | 200 | Max media title length |
| config.toml (mydotfiles) | widget.media | hide_when_idle | true | true | Hide media widget when idle |
| config.toml (mydotfiles) | widget.media | hide_when_no_media | true | true | Hide media widget with no media |
| config.toml (mydotfiles) | widget.media | art_size | 18 | 18 | Media album-art size |
| config.toml (mydotfiles) | widget.media | album_art_only | true | true | Show only album art |
| config.toml (~/.config) | — | (entire file) | — | byte-for-byte identical to mydotfiles copy | Same 365 lines; rows not duplicated |
| settings.toml (GUI) |  | config_version | — (GUI-only key) | 20 (GUI state; not exposed via config-get) | GUI settings schema version |
| settings.toml (GUI) | backdrop | enabled | true (matches config.toml) | true | Enable backdrop blur/tint behind surfaces |
| settings.toml (GUI) | bar.main | auto_hide | false (matches config.toml) | false | Auto-hide bar |
| settings.toml (GUI) | bar.main | auto_hide_reserve_space | true (matches config.toml) | true | Reserve space while auto-hidden |
| settings.toml (GUI) | bar.main | border_width | 1.0 (matches config.toml) | 1.0 | Bar border width |
| settings.toml (GUI) | bar.main | contact_shadow | true (matches config.toml) | true | ContactShadow on bar |
| settings.toml (GUI) | bar.main | font_weight | 600 (matches config.toml) | 600 | Bar font weight |
| settings.toml (GUI) | bar.main | reserve_space | true  **CONFLICT — overrides config.toml** | false | Bar reserves layout space |
| settings.toml (GUI) | bar.main | show_on_workspace_switch | true  **CONFLICT — overrides config.toml** | false | Show bar during workspace switch |
| settings.toml (GUI) | bar.main | smart_auto_hide | true (matches config.toml) | true | Smart auto-hide (hide on fullscreen) |
| settings.toml (GUI) | control_center.media | show_visualizer | false  **CONFLICT — overrides config.toml** | true | Media visualizer in control center |
| settings.toml (GUI) | dock | active_scale | 1.05 (matches config.toml) | 1.0499999523162842 | Active dock icon scale |
| settings.toml (GUI) | dock | auto_hide | false (matches config.toml) | false | Dock auto-hide |
| settings.toml (GUI) | dock | enabled | true (matches config.toml) | true | Enable dock |
| settings.toml (GUI) | dock | icon_size | 44 (matches config.toml) | 44 | Dock icon size (px) |
| settings.toml (GUI) | dock | launcher_position | 'start' (matches config.toml) | 'start' | Launcher icon position in dock |
| settings.toml (GUI) | dock | magnification_scale | 1.35 (matches config.toml) | 1.3500000238418579 | Dock magnification scale |
| settings.toml (GUI) | dock | margin_edge | 8 (matches config.toml) | 8 | Dock edge margin (px) |
| settings.toml (GUI) | dock | pinned | ['kitty', 'brave-browser', 'org.gnome.Nautilus', 'firefox'] (matches config.toml) | [ 'kitty', 'brave-browser', 'org.gnome.Nautilus', 'firefox' ] | Pinned dock apps |
| settings.toml (GUI) | dock | reserve_space | false (matches config.toml) | false | Dock reserves layout space |
| settings.toml (GUI) | dock | smart_auto_hide | true (matches config.toml) | true | Dock smart auto-hide |
| settings.toml (GUI) | lockscreen | blur_intensity | 0.35 (matches config.toml) | 0.34999999403953552 | Lockscreen wallpaper blur |
| settings.toml (GUI) | lockscreen | transition | [] (matches config.toml) | [] | Lockscreen transition preset |
| settings.toml (GUI) | lockscreen_widgets | enabled | — (GUI-only key) | false | Enable custom lockscreen widgets |
| settings.toml (GUI) | lockscreen_widgets | schema_version | — (GUI-only key) | 2 | Lockscreen widget schema version |
| settings.toml (GUI) | lockscreen_widgets | widget_order | — (GUI-only key) | [ 'lockscreen-login-box@eDP-1' ] | Ordered lockscreen widget ids |
| settings.toml (GUI) | lockscreen_widgets.grid | cell_size | — (GUI-only key) | 16 | Lockscreen grid cell size |
| settings.toml (GUI) | lockscreen_widgets.grid | major_interval | — (GUI-only key) | 4 | Lockscreen grid major interval |
| settings.toml (GUI) | lockscreen_widgets.grid | visible | — (GUI-only key) | true | Show lockscreen grid |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1" | box_height | — (GUI-only key) | 196.0 | Widget box height (px) |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1" | box_width | — (GUI-only key) | 810.0 | Widget box width (px) |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1" | cx | — (GUI-only key) | 960.0 | Widget center X (px) |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1" | cy | — (GUI-only key) | 898.0 | Widget center Y (px) |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1" | output | — (GUI-only key) | 'eDP-1' | Target output |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1" | placement_height | — (GUI-only key) | 1080.0 | Placement surface height (px) |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1" | placement_width | — (GUI-only key) | 1920.0 | Placement surface width (px) |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1" | rotation | — (GUI-only key) | 0.0 | Widget rotation (deg) |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1" | type | — (GUI-only key) | 'login_box' | Widget type |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1".settings | background_color | — (GUI-only key) | 'surface_container' | Login box background color token |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1".settings | background_opacity | — (GUI-only key) | 0.88 | Login box background opacity |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1".settings | background_radius | — (GUI-only key) | 12.0 | Login box background radius |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1".settings | center_password_text | — (GUI-only key) | false | Center password text |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1".settings | input_opacity | — (GUI-only key) | 1.0 | Password input opacity |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1".settings | input_radius | — (GUI-only key) | 6.0 | Password input radius |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1".settings | layout | — (GUI-only key) | 'regular' | Login box layout |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1".settings | show_caps_lock | — (GUI-only key) | true | Show Caps Lock indicator |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1".settings | show_keyboard_layout | — (GUI-only key) | true | Show keyboard-layout indicator |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1".settings | show_login_button | — (GUI-only key) | true | Show login button |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1".settings | show_media | — (GUI-only key) | true | Show media info on lockscreen |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1".settings | show_media_controls | — (GUI-only key) | true | Show media controls |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1".settings | show_password_reveal | — (GUI-only key) | true | Show password reveal toggle |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1".settings | show_session_buttons | — (GUI-only key) | true | Show session action buttons |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1".settings | show_unlock_hint | — (GUI-only key) | true | Show unlock hint |
| settings.toml (GUI) | lockscreen_widgets.widget."lockscreen-login-box@eDP-1".settings | show_weather | — (GUI-only key) | true | Show weather on lockscreen |
| settings.toml (GUI) | notification | max_visible | 4 (matches config.toml) | 4 | Max visible notifications |
| settings.toml (GUI) | notification | width | 380 (matches config.toml) | 380 | Notification width (px) |
| settings.toml (GUI) | osd | position | 'top_right' (matches config.toml) | 'top_right' | OSD screen position |
| settings.toml (GUI) | plugins | enabled | ['noctalia/notes', 'cleboost/ssh-launcher', 'cleboost/zed-provider', 'nightwatch75/file-search', 'noctalia/bongocat', 'thepunkoff/pomodoro']  **CONFLICT — overrides config.toml** | [     'noctalia/notes',     'cleboost/ssh-launcher',     'nightwatch75/file-search',     'cleboost/zed-provider',     'noctalia/bongocat',     'thepunkoff/pomodoro' ] | Enabled plugin ids |
| settings.toml (GUI) | shell | font_family | 'Fira Sans'  **CONFLICT — overrides config.toml** | 'Inter' | Shell UI font family |
| settings.toml (GUI) | shell | offline_mode | false (matches config.toml) | false | Disable network features |
| settings.toml (GUI) | shell | popup_shadows | true (matches config.toml) | true | Shadows on popups |
| settings.toml (GUI) | shell | settings_window_translucent | true (matches config.toml) | true | Translucent settings window |
| settings.toml (GUI) | shell.animation | enabled | true (matches config.toml) | true | Enable shell animations |
| settings.toml (GUI) | shell.animation | speed | 1.6 (matches config.toml) | 1.6000000238418579 | Shell animation speed multiplier |
| settings.toml (GUI) | shell.launcher | width | 820 (matches config.toml) | 820 | Launcher width (px) |
| settings.toml (GUI) | shell.panel | control_center_placement | 'floating' (matches config.toml) | 'floating' | Control-center floating/attached |
| settings.toml (GUI) | shell.panel | control_center_position | 'center' (matches config.toml) | 'center' | Control-center anchor position |
| settings.toml (GUI) | shell.panel | list_item_background | true (matches config.toml) | true | Background behind list items |
| settings.toml (GUI) | theme | builtin | — (GUI-only key) | 'Tokyo-Night' | Builtin theme id in use |
| settings.toml (GUI) | theme | community_palette | — (GUI-only key) | 'Oxocarbon' | Community palette id |
| settings.toml (GUI) | theme | custom_palette | 'Peach' (matches config.toml) | 'Peach' | Custom palette name |
| settings.toml (GUI) | theme | pure_black_dark | — (GUI-only key) | true | Pure-black background in dark mode |
| settings.toml (GUI) | theme | wallpaper_scheme | — (GUI-only key) | 'm3-rainbow' | Wallpaper-derived color scheme algorithm |
| settings.toml (GUI) | wallpaper | directory | — (GUI-only key) | '/home/sahil/Pictures/wallpaper' | Wallpaper search directory |
| settings.toml (GUI) | wallpaper.default | path | — (GUI-only key) | '/home/sahil/Pictures/wallpaper/wallhaven-4l8r9p_1920x1080.jpg' (GUI state; not exposed via config-get) | Default wallpaper path |
| settings.toml (GUI) | wallpaper.last | path | — (GUI-only key) | '/home/sahil/Pictures/wallpaper/wallhaven-4l8r9p_1920x1080.jpg' (GUI state; not exposed via config-get) | Last-used wallpaper path |
| settings.toml (GUI) | wallpaper.monitors.eDP-1 | path | — (GUI-only key) | '/home/sahil/Pictures/wallpaper/wallhaven-4l8r9p_1920x1080.jpg' (GUI state; not exposed via config-get) | Per-monitor wallpaper (eDP-1) |
| settings.toml (GUI) | widget.eye | custom_label | '' (matches config.toml) | '' | Eye widget custom label |
| settings.toml (GUI) | widget.eye | show_glyph | true (matches config.toml) | true | Eye widget shows glyph |
| settings.toml (GUI) | widget.media | album_art_only | true (matches config.toml) | true | Show only album art |
| settings.toml (GUI) | widget.workspaces | show_icons | false (matches config.toml) | false | Show workspace app icons |
| settings.toml (GUI) | widget.workspaces | style | 'focus_hint' (matches config.toml) | 'focus_hint' | Workspace widget style |
| state.toml (GUI) | annotate | color_arrow | "0.96,0.2,0.28,1" (runtime state, not config-get) | "0.96,0.2,0.28,1" | Screenshot annotate arrow color (RGBA) |
| state.toml (GUI) | annotate | color_blur | "0.96,0.2,0.28,1" (runtime state, not config-get) | "0.96,0.2,0.28,1" | Screenshot annotate blur color (RGBA) |
| state.toml (GUI) | annotate | color_brush | "0.96,0.2,0.28,1" (runtime state, not config-get) | "0.96,0.2,0.28,1" | Screenshot annotate brush color (RGBA) |
| state.toml (GUI) | annotate | color_circle | "0.96,0.2,0.28,1" (runtime state, not config-get) | "0.96,0.2,0.28,1" | Screenshot annotate circle color (RGBA) |
| state.toml (GUI) | annotate | color_crop | "0.96,0.2,0.28,1" (runtime state, not config-get) | "0.96,0.2,0.28,1" | Screenshot annotate crop color (RGBA) |
| state.toml (GUI) | annotate | color_eraser | "0.96,0.2,0.28,1" (runtime state, not config-get) | "0.96,0.2,0.28,1" | Screenshot annotate eraser color (RGBA) |
| state.toml (GUI) | annotate | color_highlighter | "1,0.91,0.2,1" (runtime state, not config-get) | "1,0.91,0.2,1" | Screenshot annotate highlighter color (RGBA) |
| state.toml (GUI) | annotate | color_line | "0.96,0.2,0.28,1" (runtime state, not config-get) | "0.96,0.2,0.28,1" | Screenshot annotate line color (RGBA) |
| state.toml (GUI) | annotate | color_move | "0.96,0.2,0.28,1" (runtime state, not config-get) | "0.96,0.2,0.28,1" | Screenshot annotate move color (RGBA) |
| state.toml (GUI) | annotate | color_numbering | "0.96,0.2,0.28,1" (runtime state, not config-get) | "0.96,0.2,0.28,1" | Screenshot annotate numbering color (RGBA) |
| state.toml (GUI) | annotate | color_rectangle | "0.96,0.2,0.28,1" (runtime state, not config-get) | "0.96,0.2,0.28,1" | Screenshot annotate rectangle color (RGBA) |
| state.toml (GUI) | annotate | color_text | "0.96,0.2,0.28,1" (runtime state, not config-get) | "0.96,0.2,0.28,1" | Screenshot annotate text color (RGBA) |
| state.toml (GUI) | annotate | fill | "off" (runtime state, not config-get) | "off" | Annotate fill on/off |
| state.toml (GUI) | annotate | tool | "text" (runtime state, not config-get) | "text" | Last annotate tool |
| state.toml (GUI) | annotate | toolbar_positions | "{}" (runtime state, not config-get) | "{}" | Annotate toolbar positions (serialized) |
| state.toml (GUI) | annotate | width_arrow | "6" (runtime state, not config-get) | "6" | Screenshot annotate arrow width |
| state.toml (GUI) | annotate | width_blur | "32" (runtime state, not config-get) | "32" | Screenshot annotate blur width |
| state.toml (GUI) | annotate | width_brush | "6" (runtime state, not config-get) | "6" | Screenshot annotate brush width |
| state.toml (GUI) | annotate | width_circle | "6" (runtime state, not config-get) | "6" | Screenshot annotate circle width |
| state.toml (GUI) | annotate | width_crop | "6" (runtime state, not config-get) | "6" | Screenshot annotate crop width |
| state.toml (GUI) | annotate | width_eraser | "28" (runtime state, not config-get) | "28" | Screenshot annotate eraser width |
| state.toml (GUI) | annotate | width_highlighter | "24" (runtime state, not config-get) | "24" | Screenshot annotate highlighter width |
| state.toml (GUI) | annotate | width_line | "6" (runtime state, not config-get) | "6" | Screenshot annotate line width |
| state.toml (GUI) | annotate | width_move | "6" (runtime state, not config-get) | "6" | Screenshot annotate move width |
| state.toml (GUI) | annotate | width_numbering | "32" (runtime state, not config-get) | "32" | Screenshot annotate numbering width |
| state.toml (GUI) | annotate | width_rectangle | "6" (runtime state, not config-get) | "6" | Screenshot annotate rectangle width |
| state.toml (GUI) | annotate | width_text | "24" (runtime state, not config-get) | "24" | Screenshot annotate text width |
| state.toml (GUI) | security_migrations | calendar_credentials_v1 | true (runtime state, not config-get) | true | Calendar credential migration applied |
| state.toml (GUI) | theme_templates | applied_builtin_ids | "" (runtime state, not config-get) | "" | Applied builtin theme template ids |
| state.toml (GUI) | theme_templates | applied_community_ids | "" (runtime state, not config-get) | "" | Applied community theme template ids |
| hyprland.conf | hl.env | OZONE_PLATFORM | — (Lua config) | wayland | Environment variable exported to session |
| hyprland.conf | hl.env | ELECTRON_OZONE_PLATFORM_HINT | — (Lua config) | wayland | Environment variable exported to session |
| hyprland.conf | hl.env | QT_QPA_PLATFORM | — (Lua config) | wayland;xcb | Environment variable exported to session |
| hyprland.conf | hl.env | QT_QPA_PLATFORMTHEME | — (Lua config) | qt6ct | Environment variable exported to session |
| hyprland.conf | hl.env | QT_WAYLAND_DISABLE_WINDOWDECORATION | — (Lua config) | 1 | Environment variable exported to session |
| hyprland.conf | hl.env | GDK_SCALE | — (Lua config) | 1 | Environment variable exported to session |
| hyprland.conf | hl.env | GDK_BACKEND | — (Lua config) | wayland,x11,* | Environment variable exported to session |
| hyprland.conf | hl.env | CLUTTER_BACKEND | — (Lua config) | wayland | Environment variable exported to session |
| hyprland.conf | hl.env | MOZ_ENABLE_WAYLAND | — (Lua config) | 1 | Environment variable exported to session |
| hyprland.conf | hl.env | XCURSOR_THEME | — (Lua config) | Sweet-cursors | Environment variable exported to session |
| hyprland.conf | hl.env | XCURSOR_SIZE | — (Lua config) | 24 | Environment variable exported to session |
| hyprland.conf | hl.env | HYPRCURSOR_SIZE | — (Lua config) | 24 | Environment variable exported to session |
| hyprland.conf | hl.env | SDL_VIDEODRIVER | — (Lua config) | wayland | Environment variable exported to session |
| hyprland.conf | hl.env | QT_QPA_PLATFORMTHEME | — (Lua config) (disabled) | qt6ct (commented out) | Disabled: Breeze theme suspected in screen-share picker crash |
| hyprland.conf | hl.plugin.load | hyprglass.so | — (Lua config) | /home/sahil/.local/share/hyprland/plugins/hyprglass.so | Load hyprglass plugin |
| hyprland.conf | hl.config.general | gaps_in | — (Lua config) | 8 | Hyprland general parameter |
| hyprland.conf | hl.config.general | gaps_out | — (Lua config) | 16 | Hyprland general parameter |
| hyprland.conf | hl.config.general | border_size | — (Lua config) | 2 | Hyprland general parameter |
| hyprland.conf | hl.config.general | col.active_border | — (Lua config) | rgba(7aa2f7ff) | Hyprland general parameter |
| hyprland.conf | hl.config.general | col.inactive_border | — (Lua config) | rgba(3b4261ff) | Hyprland general parameter |
| hyprland.conf | hl.config.general | layout | — (Lua config) | dwindle | Hyprland general parameter |
| hyprland.conf | hl.config.decoration | rounding | — (Lua config) | 14 | Hyprland decoration parameter |
| hyprland.conf | hl.config.decoration.blur | enabled | — (Lua config) | true | Hyprland decoration parameter |
| hyprland.conf | hl.config.decoration.blur | size | — (Lua config) | 6 | Hyprland decoration parameter |
| hyprland.conf | hl.config.decoration.blur | passes | — (Lua config) | 2 | Hyprland decoration parameter |
| hyprland.conf | hl.config.decoration.blur | new_optimizations | — (Lua config) | true | Hyprland decoration parameter |
| hyprland.conf | hl.config.decoration.blur | ignore_opacity | — (Lua config) | true | Hyprland decoration parameter |
| hyprland.conf | hl.config.decoration.blur | xray | — (Lua config) | false | Hyprland decoration parameter |
| hyprland.conf | hl.config.decoration.blur | noise | — (Lua config) | 0.04 | Hyprland decoration parameter |
| hyprland.conf | hl.config.decoration.blur | contrast | — (Lua config) | 1.0 | Hyprland decoration parameter |
| hyprland.conf | hl.config.decoration.blur | brightness | — (Lua config) | 0.9 | Hyprland decoration parameter |
| hyprland.conf | hl.config.decoration.blur | popups | — (Lua config) | true | Hyprland decoration parameter |
| hyprland.conf | hl.config.decoration.shadow | enabled | — (Lua config) | true | Hyprland decoration parameter |
| hyprland.conf | hl.config.decoration.shadow | range | — (Lua config) | 20 | Hyprland decoration parameter |
| hyprland.conf | hl.config.decoration.shadow | render_power | — (Lua config) | 3 | Hyprland decoration parameter |
| hyprland.conf | hl.config.decoration.shadow | color | — (Lua config) | rgba(16161e66) | Hyprland decoration parameter |
| hyprland.conf | hl.config.animations | enabled | — (Lua config) | true | Hyprland animations parameter |
| hyprland.conf | hl.config.input | kb_layout | — (Lua config) | us | Hyprland input parameter |
| hyprland.conf | hl.config.input | follow_mouse | — (Lua config) | 1 | Hyprland input parameter |
| hyprland.conf | hl.config.input.touchpad | natural_scroll | — (Lua config) | true | Hyprland input parameter |
| hyprland.conf | hl.config.dwindle | preserve_split | — (Lua config) | true | Hyprland dwindle parameter |
| hyprland.conf | hl.config.binds | allow_workspace_cycles | — (Lua config) | true | Hyprland binds parameter |
| hyprland.conf | hl.config.binds | pass_mouse_when_bound | — (Lua config) | false | Hyprland binds parameter |
| hyprland.conf | hl.config.binds | scroll_event_delay | — (Lua config) | 1 | Hyprland binds parameter |
| hyprland.conf | hl.config.misc | disable_hyprland_logo | — (Lua config) | true | Hyprland misc parameter |
| hyprland.conf | hl.config.misc | disable_splash_rendering | — (Lua config) | true | Hyprland misc parameter |
| hyprland.conf | hl.config.misc | allow_session_lock_restore | — (Lua config) | true | Hyprland misc parameter |
| hyprland.conf | hl.config.xwayland | force_zero_scaling | — (Lua config) | true | Hyprland xwayland parameter |
| hyprland.conf | hl.curve | smooth | — (Lua config) | { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.0} } } | Named bezier easing curve |
| hyprland.conf | hl.animation | global | — (Lua config) | enabled=true, speed=10, bezier=smooth | Animation leaf: enabled/speed/bezier/style |
| hyprland.conf | hl.animation | windows | — (Lua config) | enabled=true, speed=7, bezier=smooth | Animation leaf: enabled/speed/bezier/style |
| hyprland.conf | hl.animation | windowsIn | — (Lua config) | enabled=true, speed=8, bezier=smooth, style=popin 97% | Animation leaf: enabled/speed/bezier/style |
| hyprland.conf | hl.animation | windowsOut | — (Lua config) | enabled=true, speed=8, bezier=smooth, style=popin 97% | Animation leaf: enabled/speed/bezier/style |
| hyprland.conf | hl.animation | fade | — (Lua config) | enabled=true, speed=10, bezier=smooth | Animation leaf: enabled/speed/bezier/style |
| hyprland.conf | hl.animation | workspaces | — (Lua config) | enabled=true, speed=9, bezier=smooth, style=slidefade 8% | Animation leaf: enabled/speed/bezier/style |
| hyprland.conf | hl.monitor | output | — (Lua config) | eDP-1 | Monitor output |
| hyprland.conf | hl.monitor | mode | — (Lua config) | 1920x1080@60.02 | Monitor mode |
| hyprland.conf | hl.monitor | position | — (Lua config) | '0x0' | Monitor position |
| hyprland.conf | hl.monitor | scale | — (Lua config) | 1.0 | Monitor scale |
| hyprland.conf | hl.monitor | vrr | — (Lua config) | 0 | Monitor vrr |
| hyprland.conf | window_rule[zen-opacity].match | class | — (Lua config) | ^(zen)$ | window_rule zen-opacity: match.class |
| hyprland.conf | window_rule[zen-opacity] | opacity | — (Lua config) | 1.0 1.0 | window_rule zen-opacity: opacity |
| hyprland.conf | window_rule[pavucontrol].match | class | — (Lua config) | .*org.pulseaudio.pavucontrol.* | window_rule pavucontrol: match.class |
| hyprland.conf | window_rule[pavucontrol] | float | — (Lua config) | true | window_rule pavucontrol: float |
| hyprland.conf | window_rule[pavucontrol] | center | — (Lua config) | true | window_rule pavucontrol: center |
| hyprland.conf | window_rule[pavucontrol] | size | — (Lua config) | 700 600 | window_rule pavucontrol: size |
| hyprland.conf | window_rule[Picture-in-Picture].match | title | — (Lua config) | ^([Pp]icture[-\s]?[Ii]n[-\s]?[Pp]icture)(.*)$ | window_rule Picture-in-Picture: match.title |
| hyprland.conf | window_rule[Picture-in-Picture] | float | — (Lua config) | true | window_rule Picture-in-Picture: float |
| hyprland.conf | window_rule[Picture-in-Picture] | pin | — (Lua config) | true | window_rule Picture-in-Picture: pin |
| hyprland.conf | window_rule[Picture-in-Picture] | focus_on_activate | — (Lua config) | false | window_rule Picture-in-Picture: focus_on_activate |
| hyprland.conf | window_rule[Picture-in-Picture] | no_initial_focus | — (Lua config) | true | window_rule Picture-in-Picture: no_initial_focus |
| hyprland.conf | window_rule[Picture-in-Picture] | suppress_event | — (Lua config) | activate | window_rule Picture-in-Picture: suppress_event |
| hyprland.conf | window_rule[special-workspace-color].match | workspace | — (Lua config) | special:scratchpad | window_rule special-workspace-color: match.workspace |
| hyprland.conf | window_rule[special-workspace-color] | border_color | — (Lua config) | rgb(f5c2e4) rgb(45475a) | window_rule special-workspace-color: border_color |
| hyprland.conf | window_rule[gtk-file-dialog].match | class | — (Lua config) | xdg-desktop-portal-gtk | window_rule gtk-file-dialog: match.class |
| hyprland.conf | window_rule[gtk-file-dialog] | float | — (Lua config) | true | window_rule gtk-file-dialog: float |
| hyprland.conf | window_rule[gtk-file-dialog] | center | — (Lua config) | true | window_rule gtk-file-dialog: center |
| hyprland.conf | window_rule[gtk-file-dialog] | size | — (Lua config) | 800 600 | window_rule gtk-file-dialog: size |
| hyprland.conf | window_rule[network-editor].match | class | — (Lua config) | nm-connection-editor | window_rule network-editor: match.class |
| hyprland.conf | window_rule[network-editor] | float | — (Lua config) | true | window_rule network-editor: float |
| hyprland.conf | window_rule[network-editor] | center | — (Lua config) | true | window_rule network-editor: center |
| hyprland.conf | window_rule[network-editor] | size | — (Lua config) | 800 700 | window_rule network-editor: size |
| hyprland.conf | window_rule[dotfiles-floating].match | class | — (Lua config) | dotfiles-floating | window_rule dotfiles-floating: match.class |
| hyprland.conf | window_rule[dotfiles-floating] | float | — (Lua config) | true | window_rule dotfiles-floating: float |
| hyprland.conf | window_rule[dotfiles-floating] | center | — (Lua config) | true | window_rule dotfiles-floating: center |
| hyprland.conf | window_rule[dotfiles-floating] | size | — (Lua config) | 1000 700 | window_rule dotfiles-floating: size |
| hyprland.conf | layer_rule[noctalia-bar-no-anim].match | namespace | — (Lua config) | ^noctalia-bar-.+$ | layer_rule noctalia-bar-no-anim: match.namespace |
| hyprland.conf | layer_rule[noctalia-bar-no-anim] | no_anim | — (Lua config) | true | layer_rule noctalia-bar-no-anim: no_anim |
| hyprland.conf | hl.gesture[3f vertical] | action | — (Lua config) | workspace | Touchpad gesture action |
| hyprland.conf | hl.gesture[3f vertical] | fingers/direction | — (Lua config) | 3 / vertical | Touchpad gesture trigger |
| hyprland.conf | hl.gesture[3f horizontal] | action | — (Lua config) | scroll_move | Touchpad gesture action |
| hyprland.conf | hl.gesture[3f horizontal] | fingers/direction | — (Lua config) | 3 / horizontal | Touchpad gesture trigger |
| hyprland.conf | hl.gesture[3f horizontal] | scale | — (Lua config) | 0.9 | Gesture scroll scale |
| hyprland.conf | hl.gesture[4f pinchout] | action | — (Lua config) | hl.dispatch(hl.dsp.window.fullscreen({ action = "set" })) | Touchpad gesture action |
| hyprland.conf | hl.gesture[4f pinchout] | fingers/direction | — (Lua config) | 4 / pinchout | Touchpad gesture trigger |
| hyprland.conf | hl.gesture[4f pinchin] | action | — (Lua config) | hl.dispatch(hl.dsp.window.fullscreen({ action = "unset" })) | Touchpad gesture action |
| hyprland.conf | hl.gesture[4f pinchin] | fingers/direction | — (Lua config) | 4 / pinchin | Touchpad gesture trigger |
| hyprland.conf | hyprglass.preset[liquid] | inherits | — (Lua config) | pomme | HyprGlass preset 'liquid' |
| hyprland.conf | hyprglass.preset[liquid] | refraction_strength | — (Lua config) | 8.0 | HyprGlass preset 'liquid' |
| hyprland.conf | hyprglass.preset[liquid] | chromatic_aberration | — (Lua config) | 1.0 | HyprGlass preset 'liquid' |
| hyprland.conf | hyprglass.preset[liquid] | specular_strength | — (Lua config) | 1.0 | HyprGlass preset 'liquid' |
| hyprland.conf | hyprglass.preset[liquid] | specular_angle | — (Lua config) | 0.0 | HyprGlass preset 'liquid' |
| hyprland.conf | hyprglass.preset[liquid] | bevel_strength | — (Lua config) | 1.0 | HyprGlass preset 'liquid' |
| hyprland.conf | hyprglass.preset[liquid] | bevel_size | — (Lua config) | 6.0 | HyprGlass preset 'liquid' |
| hyprland.conf | hyprglass.preset[liquid] | bevel_color | — (Lua config) | 0xffffff00 | HyprGlass preset 'liquid' |
| hyprland.conf | hyprglass.preset[liquid] | bevel_tint | — (Lua config) | 0.0 | HyprGlass preset 'liquid' |
| hyprland.conf | hyprglass.preset[liquid] | bevel_angle | — (Lua config) | 315.0 | HyprGlass preset 'liquid' |
| hyprland.conf | hyprglass.preset[liquid] | bevel_shadow | — (Lua config) | 0.5 | HyprGlass preset 'liquid' |
| hyprland.conf | hyprglass.preset[liquid] | fresnel_strength | — (Lua config) | 1.0 | HyprGlass preset 'liquid' |
| hyprland.conf | hyprglass.preset[liquid] | edge_height | — (Lua config) | 30 | HyprGlass preset 'liquid' |
| hyprland.conf | hyprglass.preset[liquid] | edge_thickness_px | — (Lua config) | 20 | HyprGlass preset 'liquid' |
| hyprland.conf | hyprglass.preset[liquid] | fresnel_reflection | — (Lua config) | 0.4 | HyprGlass preset 'liquid' |
| hyprland.conf | hyprglass.preset[liquid] | lens_distortion | — (Lua config) | 0.5 | HyprGlass preset 'liquid' |
| hyprland.conf | hyprglass.preset[liquid] | blur_strength | — (Lua config) | 2.0 | HyprGlass preset 'liquid' |
| hyprland.conf | hyprglass.preset[liquid] | blur_iterations | — (Lua config) | 3 | HyprGlass preset 'liquid' |
| hyprland.conf | hyprglass.preset[liquid] | noise_strength | — (Lua config) | 0.0 | HyprGlass preset 'liquid' |
| hyprland.conf | hyprglass.preset[liquid] | glass_opacity | — (Lua config) | 0.9 | HyprGlass preset 'liquid' |
| hyprland.conf | hyprglass.preset[liquid] | tint_color | — (Lua config) | 0x8899aa22 | HyprGlass preset 'liquid' |
| hyprland.conf | hyprglass.preset[matte] | inherits | — (Lua config) | subtle | HyprGlass preset 'matte' |
| hyprland.conf | hyprglass.preset[matte] | noise_strength | — (Lua config) | 0.5 | HyprGlass preset 'matte' |
| hyprland.conf | hyprglass.preset[matte] | frost | — (Lua config) | 1.0 | HyprGlass preset 'matte' |
| hyprland.conf | hyprglass.preset[matte] | frost_blur | — (Lua config) | 2.0 | HyprGlass preset 'matte' |
| hyprland.conf | hyprglass.preset[matte] | refraction_strength | — (Lua config) | 0.3 | HyprGlass preset 'matte' |
| hyprland.conf | hyprglass.preset[matte] | refraction_spread | — (Lua config) | 1.0 | HyprGlass preset 'matte' |
| hyprland.conf | hyprglass.preset[matte] | refraction_flow | — (Lua config) | 0.0 | HyprGlass preset 'matte' |
| hyprland.conf | hyprglass.preset[matte] | chromatic_aberration | — (Lua config) | 0.0 | HyprGlass preset 'matte' |
| hyprland.conf | hyprglass.preset[matte] | specular_strength | — (Lua config) | 0.0 | HyprGlass preset 'matte' |
| hyprland.conf | hyprglass.preset[matte] | fresnel_strength | — (Lua config) | 0.0 | HyprGlass preset 'matte' |
| hyprland.conf | hyprglass.preset[matte] | bevel_strength | — (Lua config) | 0.0 | HyprGlass preset 'matte' |
| hyprland.conf | hyprglass.preset[matte] | edge_height | — (Lua config) | 0.0 | HyprGlass preset 'matte' |
| hyprland.conf | hyprglass.preset[matte] | edge_thickness_px | — (Lua config) | 0.0 | HyprGlass preset 'matte' |
| hyprland.conf | hyprglass.preset[matte] | lens_distortion | — (Lua config) | 0.0 | HyprGlass preset 'matte' |
| hyprland.conf | hyprglass.preset[matte] | blur_strength | — (Lua config) | 2.0 | HyprGlass preset 'matte' |
| hyprland.conf | hyprglass.preset[matte] | blur_iterations | — (Lua config) | 5 | HyprGlass preset 'matte' |
| hyprland.conf | hyprglass.preset[matte] | glass_opacity | — (Lua config) | 1.0 | HyprGlass preset 'matte' |
| hyprland.conf | hyprglass.preset[matte] | tint_color | — (Lua config) | 0x8899aa22 | HyprGlass preset 'matte' |
| hyprland.conf | hyprglass.preset[lens] | inherits | — (Lua config) | clear | HyprGlass preset 'lens' |
| hyprland.conf | hyprglass.preset[lens] | edge_height | — (Lua config) | 30 | HyprGlass preset 'lens' |
| hyprland.conf | hyprglass.preset[lens] | edge_thickness_px | — (Lua config) | 20 | HyprGlass preset 'lens' |
| hyprland.conf | hyprglass.preset[lens] | fresnel_reflection | — (Lua config) | 1.0 | HyprGlass preset 'lens' |
| hyprland.conf | hyprglass.preset[lens] | refraction_strength | — (Lua config) | 0.6 | HyprGlass preset 'lens' |
| hyprland.conf | hyprglass.preset[lens] | chromatic_aberration | — (Lua config) | 0.5 | HyprGlass preset 'lens' |
| hyprland.conf | hyprglass.preset[lens] | lens_distortion | — (Lua config) | 1.0 | HyprGlass preset 'lens' |
| hyprland.conf | hyprglass.preset[lens] | fresnel_strength | — (Lua config) | 0.6 | HyprGlass preset 'lens' |
| hyprland.conf | hyprglass.preset[lens] | specular_strength | — (Lua config) | 0.8 | HyprGlass preset 'lens' |
| hyprland.conf | hyprglass.preset[lens] | blur_strength | — (Lua config) | 1.5 | HyprGlass preset 'lens' |
| hyprland.conf | hyprglass.preset[lens] | blur_iterations | — (Lua config) | 3 | HyprGlass preset 'lens' |
| hyprland.conf | hyprglass.preset[lens] | noise_strength | — (Lua config) | 0.0 | HyprGlass preset 'lens' |
| hyprland.conf | hyprglass.preset[lens] | glass_opacity | — (Lua config) | 0.8 | HyprGlass preset 'lens' |
| hyprland.conf | hyprglass.preset[lens] | tint_color | — (Lua config) | 0x8899aa22 | HyprGlass preset 'lens' |
| hyprland.conf | hyprglass.preset[lens] | refraction_flow | — (Lua config) | 0.0 | HyprGlass preset 'lens' |
| hyprland.conf | hyprglass.preset[lens] | refraction_spread | — (Lua config) | 1.0 | HyprGlass preset 'lens' |
| hyprland.conf | hyprglass.config. | enabled | — (Lua config) | false | HyprGlass global config |
| hyprland.conf | hyprglass.config. | default_theme | — (Lua config) | dark | HyprGlass global config |
| hyprland.conf | hyprglass.config. | default_preset | — (Lua config) | liquid | HyprGlass global config |
| hyprland.conf | hyprglass.config. | manage_window_blur | — (Lua config) | true | HyprGlass global config |
| hyprland.conf | hyprglass.config. | skip_opaque_windows | — (Lua config) | true | HyprGlass global config |
| hyprland.conf | hyprglass.config. | blur_fold | — (Lua config) | true | HyprGlass global config |
| hyprland.conf | hyprglass.config.events | geometry | — (Lua config) | false | HyprGlass global config |
| hyprland.conf | hyprglass.config.layers | enabled | — (Lua config) | true | HyprGlass global config |
| hyprland.conf | hyprglass.config.layers | mask_mode | — (Lua config) | auto | HyprGlass global config |
| hyprland.conf | hyprglass.config.layers | mask_threshold | — (Lua config) | 0.15 | HyprGlass global config |
| hyprland.conf | hyprglass.config.layers | live_resample | — (Lua config) | false | HyprGlass global config |
| hyprland.conf | hyprglass.config.layers.popups | enabled | — (Lua config) | true | HyprGlass global config |
| hyprland.conf | hyprglass.layer.noctalia-bar-main | preset | — (Lua config) | liquid | HyprGlass per-layer preset/mask |
| hyprland.conf | hyprglass.layer.noctalia-bar-main | mask_mode | — (Lua config) | auto | HyprGlass per-layer preset/mask |
| hyprland.conf | hyprglass.layer.noctalia-dock | preset | — (Lua config) | liquid | HyprGlass per-layer preset/mask |
| hyprland.conf | hyprglass.layer.noctalia-dock | mask_mode | — (Lua config) | auto | HyprGlass per-layer preset/mask |
| hyprland.conf | hyprglass.layer.noctalia-dock | mask_feather | — (Lua config) | 0.45 | HyprGlass per-layer preset/mask |
| hyprland.conf | hyprglass.layer.noctalia-dock.popups | enabled | — (Lua config) | true | HyprGlass per-layer preset/mask |
| hyprland.conf | hyprglass.layer.noctalia-dock.popups | preset | — (Lua config) | liquid | HyprGlass per-layer preset/mask |
| hyprland.conf | hyprglass.layer.noctalia-panel | preset | — (Lua config) | liquid | HyprGlass per-layer preset/mask |
| hyprland.conf | hyprglass.layer.noctalia-panel | mask_mode | — (Lua config) | contour | HyprGlass per-layer preset/mask |
| hyprland.conf | hyprglass.layer.noctalia-panel | mask_threshold | — (Lua config) | 0.15 | HyprGlass per-layer preset/mask |
| hyprland.conf | hyprglass.layer.noctalia-attached-panel | preset | — (Lua config) | liquid | HyprGlass per-layer preset/mask |
| hyprland.conf | hyprglass.layer.noctalia-attached-panel | mask_mode | — (Lua config) | contour | HyprGlass per-layer preset/mask |
| hyprland.conf | hyprglass.layer.noctalia-attached-panel | mask_threshold | — (Lua config) | 0.15 | HyprGlass per-layer preset/mask |
| hyprland.conf | hyprglass.layer.noctalia-notification | preset | — (Lua config) | liquid | HyprGlass per-layer preset/mask |
| hyprland.conf | hyprglass.layer.noctalia-notification | mask_mode | — (Lua config) | contour | HyprGlass per-layer preset/mask |
| hyprland.conf | hyprglass.layer.noctalia-notification | mask_threshold | — (Lua config) | 0.15 | HyprGlass per-layer preset/mask |
| hyprland.conf | hyprglass.layer.noctalia-osd | preset | — (Lua config) | liquid | HyprGlass per-layer preset/mask |
| hyprland.conf | hyprglass.layer.noctalia-window-switcher | preset | — (Lua config) | liquid | HyprGlass per-layer preset/mask |
| hyprland.conf | hyprglass.layer.noctalia-overview-launcher | preset | — (Lua config) | liquid | HyprGlass per-layer preset/mask |
| hyprland.conf | hyprglass.layer.noctalia-overview-launcher | mask_mode | — (Lua config) | contour | HyprGlass per-layer preset/mask |
| hyprland.conf | hyprglass.layer.noctalia-overview-launcher | mask_threshold | — (Lua config) | 0.15 | HyprGlass per-layer preset/mask |
| hyprland.conf | hyprglass.toggle-bind | SUPER + SHIFT + G | — (Lua config) | function() toggles hg.config({ enabled = glass_on }) | Runtime glass on/off toggle |
| hyprland.conf | on-hook hyprland.start | hl.exec_cmd | — (Lua config) | os.getenv("HOME") .. "/.config/hypr-noctalia/isolate-ml4w.sh &" | Startup command in hyprland.start hook |
| hyprland.conf | on-hook hyprland.start | hl.exec_cmd | — (Lua config) | "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE" | Startup command in hyprland.start hook |
| hyprland.conf | on-hook hyprland.start | hl.exec_cmd | — (Lua config) | "systemctl --user start hyprpolkitagent.service" | Startup command in hyprland.start hook |
| hyprland.conf | on-hook hyprland.start | hl.exec_cmd | — (Lua config) | "hypridle -c " .. os.getenv("HOME") .. "/.config/hypr-noctalia/hypridle.conf" | Startup command in hyprland.start hook |
| hyprland.conf | on-hook hyprland.start | hl.exec_cmd | — (Lua config) | "noctalia" | Startup command in hyprland.start hook |
| hyprland.conf | hl.bind | SUPER + ALT + G | — (Lua config) | hl.dsp.exec_cmd("noctalia msg panel-open launcher /glass") | Glass mode menu |
| hyprland.conf | hl.bind | SUPER + SHIFT + G | — (Lua config) | function()         glass_on = not glass_on         hg.config({ layers = { enabled = glass_on } })     end | Toggle shell glass on/off |
| hyprland.conf | hl.bind | SUPER + RETURN | — (Lua config) | hl.dsp.exec_cmd("kitty") | Kitty |
| hyprland.conf | hl.bind | SUPER + SHIFT + RETURN | — (Lua config) | hl.dsp.exec_cmd("wezterm") | WezTerm |
| hyprland.conf | hl.bind | SUPER + B | — (Lua config) | hl.dsp.exec_cmd("brave") | Brave |
| hyprland.conf | hl.bind | SUPER + E | — (Lua config) | hl.dsp.exec_cmd("nautilus") | Files |
| hyprland.conf | hl.bind | SUPER + D | — (Lua config) | hl.dsp.exec_cmd("noctalia msg panel-toggle launcher") | Noctalia launcher |
| hyprland.conf | hl.bind | SUPER + SPACE | — (Lua config) | hl.dsp.exec_cmd("noctalia msg panel-toggle launcher") | Noctalia launcher (Super+Space) |
| hyprland.conf | hl.bind | SUPER + V | — (Lua config) | hl.dsp.exec_cmd("noctalia msg panel-toggle clipboard") | Clipboard history |
| hyprland.conf | hl.bind | SUPER + SHIFT + C | — (Lua config) | hl.dsp.exec_cmd("noctalia msg panel-toggle control-center") | Control center |
| hyprland.conf | hl.bind | SUPER + CTRL + P | — (Lua config) | hl.dsp.exec_cmd("noctalia msg panel-toggle session") | Power/session menu (ML4W Super+Ctrl+P) |
| hyprland.conf | hl.bind | SUPER + SHIFT + N | — (Lua config) | hl.dsp.exec_cmd("noctalia msg notification-dnd-toggle") | Toggle Do Not Disturb |
| hyprland.conf | hl.bind | SUPER + L | — (Lua config) | hl.dsp.exec_cmd("noctalia msg session lock") | Lock (Noctalia IPC; loginctl lock-session is fallback) |
| hyprland.conf | hl.bind | ALT + TAB | — (Lua config) | hl.dsp.exec_cmd("noctalia msg window-switcher hold") | Noctalia window switcher |
| hyprland.conf | hl.bind | SUPER + TAB | — (Lua config) | hl.dsp.exec_cmd("noctalia msg window-switcher") | Window overview (ML4W Super+Tab) |
| hyprland.conf | hl.bind | SUPER + SHIFT + TAB | — (Lua config) | hl.dsp.exec_cmd("noctalia msg window-switcher reverse") | Window overview reverse |
| hyprland.conf | hl.bind | ALT + SHIFT + TAB | — (Lua config) | hl.dsp.exec_cmd("noctalia msg window-switcher hold reverse") | Window switcher reverse (ML4W Alt+Shift+Tab) |
| hyprland.conf | hl.bind | SUPER + H | — (Lua config) | hl.dsp.exec_cmd("noctalia msg caffeine-toggle") | Toggle idle inhibitor (calls/presentations) |
| hyprland.conf | hl.bind | SUPER + CTRL + RETURN | — (Lua config) | hl.dsp.exec_cmd("noctalia msg panel-toggle launcher") | Launcher (ML4W Super+Ctrl+Return) |
| hyprland.conf | hl.bind | SUPER + CTRL + L | — (Lua config) | hl.dsp.exec_cmd("noctalia msg session lock") | Lock (ML4W Super+Ctrl+L) |
| hyprland.conf | hl.bind | SUPER + F4 | — (Lua config) | hl.dsp.exec_cmd("noctalia msg brightness-up 5%") | Brightness up (ML4W fallback) |
| hyprland.conf | hl.bind | SUPER + F3 | — (Lua config) | hl.dsp.exec_cmd("noctalia msg brightness-down 5%") | Brightness down (ML4W fallback) |
| hyprland.conf | hl.bind | SUPER + F2 | — (Lua config) | hl.dsp.exec_cmd("noctalia msg brightness-down 5%") | Brightness down (ML4W fallback) |
| hyprland.conf | hl.bind | SUPER + SHIFT + H | — (Lua config) | hl.dsp.exec_cmd("noctalia msg nightlight-force-toggle") | Night light force toggle (ML4W Super+Shift+H) |
| hyprland.conf | hl.bind | SUPER + CTRL + H | — (Lua config) | hl.dsp.exec_cmd("noctalia msg panel-open launcher /eye") | Eye-care menu in Noctalia launcher (ML4W Super+Ctrl+H) |
| hyprland.conf | hl.bind | SUPER + CTRL + E | — (Lua config) | hl.dsp.exec_cmd("noctalia msg panel-open launcher /emo") | Emoji picker (ML4W Super+Ctrl+E) |
| hyprland.conf | hl.bind | SUPER + W | — (Lua config) | hl.dsp.exec_cmd("noctalia msg wallpaper-next") | Next wallpaper (ML4W Super+W) |
| hyprland.conf | hl.bind | SUPER + SHIFT + W | — (Lua config) | hl.dsp.exec_cmd("noctalia msg wallpaper-random") | Random wallpaper (ML4W Super+Shift+W) |
| hyprland.conf | hl.bind | SUPER + CTRL + W | — (Lua config) | hl.dsp.exec_cmd("noctalia msg panel-toggle wallpaper") | Wallpaper picker (ML4W Super+Ctrl+W) |
| hyprland.conf | hl.bind | SUPER + SHIFT + M | — (Lua config) | hl.dsp.exec_cmd("noctalia msg theme-mode-toggle") | Toggle theme mode (ML4W Super+Shift+M) |
| hyprland.conf | hl.bind | SUPER + CTRL + B | — (Lua config) | hl.dsp.exec_cmd("noctalia msg bar-toggle") | Toggle bar |
| hyprland.conf | hl.bind | SUPER + CTRL + D | — (Lua config) | hl.dsp.exec_cmd("noctalia msg dock-toggle") | Toggle dock |
| hyprland.conf | hl.bind | SUPER + Q | — (Lua config) | hl.dsp.window.close() | Close window |
| hyprland.conf | hl.bind | SUPER + SHIFT + Q | — (Lua config) | hl.dsp.window.kill() | Force-kill active window (ML4W) |
| hyprland.conf | hl.bind | SUPER + F | — (Lua config) | hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }) | Fullscreen |
| hyprland.conf | hl.bind | SUPER + M | — (Lua config) | hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }) | Maximize |
| hyprland.conf | hl.bind | SUPER + T | — (Lua config) | hl.dsp.window.float({ action = "toggle" }) | Float |
| hyprland.conf | hl.bind | SUPER + J | — (Lua config) | hl.dsp.layout("togglesplit") | Toggle split |
| hyprland.conf | hl.bind | SUPER + PRINT | — (Lua config) | hl.dsp.exec_cmd("noctalia msg screenshot-fullscreen") | Full screenshot (ML4W Super+Print) |
| hyprland.conf | hl.bind | SUPER + ALT + F | — (Lua config) | hl.dsp.exec_cmd("noctalia msg screenshot-fullscreen") | Instant full screenshot (ML4W) |
| hyprland.conf | hl.bind | SUPER + ALT + S | — (Lua config) | hl.dsp.exec_cmd("noctalia msg screenshot-region") | Region screenshot (ML4W) |
| hyprland.conf | hl.bind | SUPER + CTRL + F | — (Lua config) | hl.dsp.exec_cmd("noctalia msg screenshot-window") | Focused-window screenshot |
| hyprland.conf | hl.bind | SUPER + A | — (Lua config) | hl.dsp.exec_cmd("noctalia msg screenshot-annotate") | Freeze and annotate screenshot |
| hyprland.conf | hl.bind | SUPER + ALT + A | — (Lua config) | hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/ocr-region.sh") | Region OCR to clipboard (ML4W Super+Alt+A) |
| hyprland.conf | hl.bind | SUPER + SHIFT + T | — (Lua config) | hl.dsp.exec_cmd("hyprctl dispatch workspaceopt allfloat") | Toggle float for all windows on workspace (ML4W) |
| hyprland.conf | hl.bind | SUPER + ALT + T | — (Lua config) | function()     hl.dispatch(hl.dsp.window.float({ action = "toggle" }))     hl.dispatch(hl.dsp.window.pin()) end | Float + pin window (ML4W) |
| hyprland.conf | hl.bind | SUPER + G | — (Lua config) | hl.dsp.group.toggle() | Toggle window group (ML4W) |
| hyprland.conf | hl.bind | SUPER + K | — (Lua config) | hl.dsp.layout("swapsplit") | Swap split (ML4W) |
| hyprland.conf | hl.bind | SUPER + SHIFT + R | — (Lua config) | hl.dsp.exec_cmd("hyprctl reload") | Reload Hyprland config (ML4W) |
| hyprland.conf | hl.bind | SUPER + left | — (Lua config) | hl.dsp.focus({ direction = "left" }) | Focus left |
| hyprland.conf | hl.bind | SUPER + right | — (Lua config) | hl.dsp.focus({ direction = "right" }) | Focus right |
| hyprland.conf | hl.bind | SUPER + up | — (Lua config) | hl.dsp.focus({ direction = "up" }) | Focus up |
| hyprland.conf | hl.bind | SUPER + down | — (Lua config) | hl.dsp.focus({ direction = "down" }) | Focus down |
| hyprland.conf | hl.bind | SUPER + mouse:272 | — (Lua config) | hl.dsp.window.drag() [mouse=true] | Move window |
| hyprland.conf | hl.bind | SUPER + mouse:273 | — (Lua config) | hl.dsp.window.resize() [mouse=true] | Resize window |
| hyprland.conf | hl.bind | SUPER + SHIFT + right | — (Lua config) | hl.dsp.window.resize({ x = 100, y = 0, relative = true }) [repeating=true] | Increase window width (ML4W) |
| hyprland.conf | hl.bind | SUPER + SHIFT + left | — (Lua config) | hl.dsp.window.resize({ x = -100, y = 0, relative = true }) [repeating=true] | Decrease window width (ML4W) |
| hyprland.conf | hl.bind | SUPER + SHIFT + down | — (Lua config) | hl.dsp.window.resize({ x = 0, y = 100, relative = true }) [repeating=true] | Increase window height (ML4W) |
| hyprland.conf | hl.bind | SUPER + SHIFT + up | — (Lua config) | hl.dsp.window.resize({ x = 0, y = -100, relative = true }) [repeating=true] | Decrease window height (ML4W) |
| hyprland.conf | hl.bind | SUPER + ALT + left | — (Lua config) | hl.dsp.window.swap({ direction = "l" }) | Swap tiled window left (ML4W) |
| hyprland.conf | hl.bind | SUPER + ALT + right | — (Lua config) | hl.dsp.window.swap({ direction = "r" }) | Swap tiled window right (ML4W) |
| hyprland.conf | hl.bind | SUPER + ALT + up | — (Lua config) | hl.dsp.window.swap({ direction = "u" }) | Swap tiled window up (ML4W) |
| hyprland.conf | hl.bind | SUPER + ALT + down | — (Lua config) | hl.dsp.window.swap({ direction = "d" }) | Swap tiled window down (ML4W) |
| hyprland.conf | hl.bind | SUPER + S | — (Lua config) | hl.dsp.workspace.toggle_special("scratchpad") | Toggle scratchpad (ML4W) |
| hyprland.conf | hl.bind | SUPER + SHIFT + S | — (Lua config) | function()     hl.dispatch(hl.dsp.window.move({ workspace = "special:scratchpad" }))     hl.dispatch(hl.dsp.window.set_prop({ prop = "active_border_color", value = "rgba(f5c2e4ff)" }))     hl.dispatch(hl.dsp.window.set_prop({ prop = "inactive_border_color", value = "rgba(45475aff)" })) end | Move window to special workspace with pink border marker |
| hyprland.conf | hl.bind | SUPER + mouse_down | — (Lua config) | throttled_scroll(hl.dsp.focus({ workspace = "e+1" })) | Next workspace (ML4W) |
| hyprland.conf | hl.bind | SUPER + mouse_up | — (Lua config) | throttled_scroll(hl.dsp.focus({ workspace = "e-1" })) | Previous workspace (ML4W) |
| hyprland.conf | hl.bind | XF86AudioRaiseVolume | — (Lua config) | hl.dsp.exec_cmd("noctalia msg volume-up 5") [repeating=true] | Keybinding |
| hyprland.conf | hl.bind | XF86AudioLowerVolume | — (Lua config) | hl.dsp.exec_cmd("noctalia msg volume-down 5") [repeating=true] | Keybinding |
| hyprland.conf | hl.bind | XF86AudioMute | — (Lua config) | hl.dsp.exec_cmd("noctalia msg volume-mute") | Keybinding |
| hyprland.conf | hl.bind | XF86MonBrightnessUp | — (Lua config) | hl.dsp.exec_cmd("noctalia msg brightness-up 5%") [repeating=true] | Keybinding |
| hyprland.conf | hl.bind | XF86MonBrightnessDown | — (Lua config) | hl.dsp.exec_cmd("noctalia msg brightness-down 5%") [repeating=true] | Keybinding |
| hyprland.conf | hl.bind | XF86AudioMicMute | — (Lua config) | hl.dsp.exec_cmd("noctalia msg mic-mute") [locked=true] | Mute microphone with OSD |
| hyprland.conf | hl.bind | XF86AudioNext | — (Lua config) | hl.dsp.exec_cmd("playerctl next") [locked=true] | Next track (ML4W) |
| hyprland.conf | hl.bind | XF86AudioPrev | — (Lua config) | hl.dsp.exec_cmd("playerctl previous") [locked=true] | Previous track (ML4W) |
| hyprland.conf | hl.bind | XF86AudioPlay | — (Lua config) | hl.dsp.exec_cmd("playerctl play-pause") [locked=true] | Play/pause (ML4W) |
| hyprland.conf | hl.bind | XF86AudioPause | — (Lua config) | hl.dsp.exec_cmd("playerctl play-pause") [locked=true] | Pause (ML4W) |
| hyprland.conf | hl.bind (loop) | SUPER + 1 | — (Lua config) | hl.dsp.focus({ workspace = 1 }) | Workspace 1 |
| hyprland.conf | hl.bind (loop) | SUPER + SHIFT + 1 | — (Lua config) | hl.dsp.window.move({ workspace = 1 }) | Move to workspace 1 |
| hyprland.conf | hl.bind (loop) | SUPER + 2 | — (Lua config) | hl.dsp.focus({ workspace = 2 }) | Workspace 2 |
| hyprland.conf | hl.bind (loop) | SUPER + SHIFT + 2 | — (Lua config) | hl.dsp.window.move({ workspace = 2 }) | Move to workspace 2 |
| hyprland.conf | hl.bind (loop) | SUPER + 3 | — (Lua config) | hl.dsp.focus({ workspace = 3 }) | Workspace 3 |
| hyprland.conf | hl.bind (loop) | SUPER + SHIFT + 3 | — (Lua config) | hl.dsp.window.move({ workspace = 3 }) | Move to workspace 3 |
| hyprland.conf | hl.bind (loop) | SUPER + 4 | — (Lua config) | hl.dsp.focus({ workspace = 4 }) | Workspace 4 |
| hyprland.conf | hl.bind (loop) | SUPER + SHIFT + 4 | — (Lua config) | hl.dsp.window.move({ workspace = 4 }) | Move to workspace 4 |
| hyprland.conf | hl.bind (loop) | SUPER + 5 | — (Lua config) | hl.dsp.focus({ workspace = 5 }) | Workspace 5 |
| hyprland.conf | hl.bind (loop) | SUPER + SHIFT + 5 | — (Lua config) | hl.dsp.window.move({ workspace = 5 }) | Move to workspace 5 |
| hyprland.conf | hl.bind (loop) | SUPER + 6 | — (Lua config) | hl.dsp.focus({ workspace = 6 }) | Workspace 6 |
| hyprland.conf | hl.bind (loop) | SUPER + SHIFT + 6 | — (Lua config) | hl.dsp.window.move({ workspace = 6 }) | Move to workspace 6 |
| hyprland.conf | hl.bind (loop) | SUPER + 7 | — (Lua config) | hl.dsp.focus({ workspace = 7 }) | Workspace 7 |
| hyprland.conf | hl.bind (loop) | SUPER + SHIFT + 7 | — (Lua config) | hl.dsp.window.move({ workspace = 7 }) | Move to workspace 7 |
| hyprland.conf | hl.bind (loop) | SUPER + 8 | — (Lua config) | hl.dsp.focus({ workspace = 8 }) | Workspace 8 |
| hyprland.conf | hl.bind (loop) | SUPER + SHIFT + 8 | — (Lua config) | hl.dsp.window.move({ workspace = 8 }) | Move to workspace 8 |
| hyprland.conf | hl.bind (loop) | SUPER + 9 | — (Lua config) | hl.dsp.focus({ workspace = 9 }) | Workspace 9 |
| hyprland.conf | hl.bind (loop) | SUPER + SHIFT + 9 | — (Lua config) | hl.dsp.window.move({ workspace = 9 }) | Move to workspace 9 |
| hyprland.conf | hl.bind (loop) | SUPER + 0 | — (Lua config) | hl.dsp.focus({ workspace = 10 }) | Workspace 10 |
| hyprland.conf | hl.bind (loop) | SUPER + SHIFT + 0 | — (Lua config) | hl.dsp.window.move({ workspace = 10 }) | Move to workspace 10 |
| hyprland.conf | scroll helper | throttled_scroll timeout | — (Lua config) | 200 ms (oneshot timer) | Debounce for Super+wheel workspace scroll |
| hypridle.conf | general | after_sleep_cmd | — (hypridle config) | hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })' | Idle timeout action |
| hypridle.conf | listener[0] | timeout | — (hypridle config) | 480 | Idle timeout action |
| hypridle.conf | listener[0] | on-timeout | — (hypridle config) | brightnessctl -s set 10 | Idle timeout action |
| hypridle.conf | listener[0] | on-resume | — (hypridle config) | brightnessctl -r | Idle timeout action |
| hypridle.conf | listener[1] | timeout | — (hypridle config) | 660 | Idle timeout action |
| hypridle.conf | listener[1] | on-timeout | — (hypridle config) | hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })' | Idle timeout action |
| hypridle.conf | listener[1] | on-resume | — (hypridle config) | hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })' | Idle timeout action |

## Enabled plugins and their exact settings keys

`plugins.enabled` (runtime order): `noctalia/notes`, `cleboost/ssh-launcher`, `nightwatch75/file-search`, `cleboost/zed-provider`, `noctalia/bongocat`, `thepunkoff/pomodoro`. config.toml lists the same six IDs but with `cleboost/zed-provider` before `nightwatch75/file-search` (order-only conflict).

| Plugin | Configured settings keys (exact) | Values | Widget binding |
|---|---|---|---|
| `noctalia/notes` | `notes_dir`, `extension` | `/home/sahil/Documents/noctalia-notes`, `md` | — |
| `cleboost/ssh-launcher` | `config_path`, `max_results` | `/home/sahil/.ssh/config`, `30` | — |
| `nightwatch75/file-search` | `search_folder`, `exclude_dirs`, `space_enabled` | `/home/sahil`, `.git, node_modules, .cache, .venv`, `false` | — |
| `cleboost/zed-provider` | `db_path`, `max_results`, `new_window` | `/home/sahil/.local/share/zed/db/0-stable/db.sqlite`, `20`, `false` | — |
| `noctalia/bongocat` | none in `plugin_settings`; widget keys `type`, `audio_spectrum`, `tappy_mode`, `input_devices` | `noctalia/bongocat:cat`, `true`, `true`, `[]` | `widget.cat` (g0 capsule) |
| `thepunkoff/pomodoro` | `work-duration`, `short-break-duration`, `long-break-duration`, `sessions-before-long-break` | `25`, `5`, `15`, `4` | `widget.pomo` (g0 capsule), glyphs `brain`/`brain`/`coffee` |

`plugins.auto_update = "none"` (config.toml; not overridden).
