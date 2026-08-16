# AI agents

This setup doesn't run an in-editor AI assistant (avante was removed — see git history). Instead, it launches **CLI coding agents** from inside nvim into a real pane, so every existing nvim/tmux feature keeps working on them.

## The one keymap

- `<leader>a` — pick & open an agent (Claude Code, opencode).

If only one agent is configured, it opens directly. With two or more, a picker (`vim.ui.select`) shows the list first.

## Where it opens

The launcher (`lua/plugins/editor/ai-tools.lua`) picks a host based on the environment:

| Context | Opens as |
|---------|----------|
| Inside **tmux** | A new tmux pane on the **right** (55% width) |
| Outside tmux | A floating nvim terminal window (~92% × 90%) |

Inside tmux the agent pane is a first-class tmux pane, so all of this just works on it:

- Hop in/out with `<C-h>` / `<C-l>` (vim-tmux-navigator).
- Resize with tmux.nvim bindings.
- Full pane scrollback and history.

## Adding a new agent — one line

The whole integration is a single entry in the `tools` table:

```lua
local tools = {
  { name = 'Claude Code', cmd = 'claude' },
  { name = 'opencode', cmd = 'opencode' },
  -- { name = 'Codex', cmd = 'codex' },
  -- { name = 'Aider', cmd = 'aider --watch' },
}
```

Uncomment a line or paste a new one; `<leader>a` auto-lists it. That's the entire change — no other wiring.

## Why a pane instead of a plugin

- The agent's TUI renders in a real terminal buffer/pane, so it handles mouse, colors, and escape sequences correctly.
- You can keep a normal editor buffer on one side and the agent on the other, same as any split.
- No plugin updates to track, no API-key handling inside nvim — each agent manages its own auth.
