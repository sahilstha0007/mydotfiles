---@type Config
return {
   -- behaviours
   automatically_reload_config = true,
   exit_behavior = 'CloseOnCleanExit', -- if the shell program exited with a successful status
   exit_behavior_messaging = 'Verbose',
   status_update_interval = 1000,
   audible_bell = 'Disabled',

   -- nvim binds <C-Arrow> to window resize; tmux binds -n S-Arrow to pane
   -- navigation. Without the kitty keyboard protocol those are the same bytes
   -- at the PTY, so tmux wins and nvim's resize never fires. This lets tmux
   -- tell them apart. Revert if a TUI misbehaves and report it.
   enable_kitty_keyboard = true,

   -- Kitty graphics protocol: lets yazi (prefix+b) render native image/video
   -- previews inline. Without it yazi falls back to text-only. Enabled for
   -- wezterm's own renderer only — the real Kitty terminal is a separate app
   -- and is unaffected by this file. If a TUI ever draws garbage or misplaces
   -- rows, this is the first flag to turn back off.
   enable_kitty_graphics = true,

   scrollback_lines = 20000,

   hyperlink_rules = {
      -- Matches: a URL in parens: (URL)
      {
         regex = '\\((\\w+://\\S+)\\)',
         format = '$1',
         highlight = 1,
      },
      -- Matches: a URL in brackets: [URL]
      {
         regex = '\\[(\\w+://\\S+)\\]',
         format = '$1',
         highlight = 1,
      },
      -- Matches: a URL in curly braces: {URL}
      {
         regex = '\\{(\\w+://\\S+)\\}',
         format = '$1',
         highlight = 1,
      },
      -- Matches: a URL in angle brackets: <URL>
      {
         regex = '<(\\w+://\\S+)>',
         format = '$1',
         highlight = 1,
      },
      -- Then handle URLs not wrapped in brackets
      {
         regex = '\\b\\w+://\\S+[)/a-zA-Z0-9-]+',
         format = '$0',
      },
      -- implicit mailto link
      {
         regex = '\\b\\w+@[\\w-]+(\\.[\\w-]+)+\\b',
         format = 'mailto:$0',
      },
   },
}
