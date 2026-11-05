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

   -- Patterns for QuickSelect (Ctrl+Shift+Space): matches compiler errors/warnings,
   -- git commit hashes, IP addresses, ports, and docker IDs in addition to default URLs.
   quick_select_patterns = {
      -- compiler errors and stack traces: path/to/file:line:col or file:line
      '[.\\w/\\-_]+\\.[a-zA-Z0-9]+:[0-9]+(:[0-9]+)?',
      -- git commit hashes (7 to 40 hex digits)
      '\\b[0-9a-f]{7,40}\\b',
      -- IPv4 addresses and ports
      '\\b[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}(:[0-9]+)?\\b',
      -- localhost with port
      '\\blocalhost:[0-9]+\\b',
   },

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
      -- Clickable compiler errors and stack traces: path/to/file.ext:42:15 or file.ext:42
      {
         regex = '([\\w\\d_./-]+\\.[a-zA-Z0-9_-]+):(\\d+)(?::(\\d+))?',
         format = 'file://$1#$2',
      },
   },
}
