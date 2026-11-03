local platform = require('utils.platform')
local home = require('wezterm').home_dir

---@type Config
local options = {
   default_prog = {},
   launch_menu = {},
   set_environment_variables = {
      TERMINAL_STACK_PROFILE = 'wezterm',
      -- TMUX_TMPDIR is owned by ~/.zshenv ($HOME/.cache/tmux) so kitty and
      -- wezterm attach to the SAME tmux server and share sessions. Kept
      -- here for non-zsh programs launched by wezterm; must match .zshenv.
      TMUX_TMPDIR = home .. '/.cache/tmux',
   },
}

if platform.is_win then
   options.default_prog = { 'pwsh', '-NoLogo' }
   options.launch_menu = {
      { label = 'PowerShell Core', args = { 'pwsh', '-NoLogo' } },
      { label = 'PowerShell Desktop', args = { 'powershell' } },
      { label = 'Command Prompt', args = { 'cmd' } },
      { label = 'Nushell', args = { 'nu' } },
      { label = 'Msys2', args = { 'ucrt64.cmd' } },
      {
         label = 'Git Bash',
         args = { 'C:\\Users\\kevin\\scoop\\apps\\git\\current\\bin\\bash.exe' },
      },
   }
elseif platform.is_mac then
   options.default_prog = { '/opt/homebrew/bin/fish', '-l' }
   options.launch_menu = {
      { label = 'Bash', args = { 'bash', '-l' } },
      { label = 'Fish', args = { '/opt/homebrew/bin/fish', '-l' } },
      { label = 'Nushell', args = { '/opt/homebrew/bin/nu', '-l' } },
      { label = 'Zsh', args = { 'zsh', '-l' } },
   }
elseif platform.is_linux then
   options.default_prog = { 'zsh', '-l' }
   options.launch_menu = {
      { label = 'Zsh', args = { 'zsh', '-l' } },
      { label = 'Bash', args = { 'bash', '-l' } },
      { label = 'Fish', args = { 'fish', '-l' } },
      { label = 'tmux (attach or start)', args = { 'zsh', '-l', '-c', 'tmux attach-session -t main 2>/dev/null || tmux new-session -s main' } },
   }
end

return options
