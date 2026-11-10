# Signal Ownership Matrix

Single-owner-per-signal contract enforced automatically by
[`check-ownership.py`](file:///home/sahil/mydotfiles/tests/signals/check-ownership.py) via `devcheck`.

Every active `(signal, host_context)` pair may have **at most one** non-allowlisted owner.

## Matrix

| Signal | Host Context | Owner | Suppressed Non-Owners |
| --- | --- | --- | --- |
| git | kitty+tmux | tmux:status-right | ohmyposh, kitty:tab_bar |
| git | bare-kitty | kitty:tab_bar | ohmyposh, tmux:status-right |
| git | wezterm+shell | none | ohmyposh |
| cwd | kitty+tmux | ohmyposh:path | tmux:status-left, kitty:tab_bar |
| cwd | bare-kitty | ohmyposh:path | kitty:tab_bar |
| cwd | wezterm+shell | ohmyposh:path | wezterm:tab-title |
| pane_command | kitty+tmux | tmux:window-status | tmux:status-left |
| agents | kitty+tmux | tmux:status-right | kitty:tab_bar |
| agents | bare-kitty | kitty:tab_bar | tmux:status-right |
| containers | kitty+tmux | tmux:status-right | kitty:tab_bar |
| containers | bare-kitty | kitty:tab_bar | tmux:status-right |
| battery | kitty+tmux | kitty:tab_bar | — |
| battery | bare-kitty | kitty:tab_bar | — |
| battery | wezterm+shell | wezterm:right-status | — |
| clock | kitty+tmux | kitty:tab_bar | — |
| clock | bare-kitty | kitty:tab_bar | — |
| clock | wezterm+shell | wezterm:right-status | — |

## Allowlisted Exceptions

Only the explicit pairs below may emit a secondary representation without failing the gate:

| Signal | Host Context | Emitter | Justification |
| --- | --- | --- | --- |
| pane_command | kitty+tmux | tmux:pane-border-format | `pane-border-status` is disabled on 1-pane windows and enabled (`top`) only on split layouts (`window_panes > 1`) so each pane divider identifies its own pane (`#P: #{pane_current_command}`). |
| fallback_title | wezterm+shell | wezterm:tab-title:no-osc7 | `compose_title` drops `cwd` whenever OSC 7 reports a directory; only when a pane has no OSC 7 yet (or pathless URL) does it retain `"process ~ base_title"` so blank titles remain legible. |
