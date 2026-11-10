local home = require('wezterm').home_dir

---@type Config
local options = {
   default_prog = { 'zsh', '-l' },
   launch_menu = {
      { label = 'Zsh', args = { 'zsh', '-l' } },
      { label = 'Bash', args = { 'bash', '-l' } },
      { label = 'Project Hub', args = { 'zsh', '-lc', 'exec "$HOME/.local/bin/project-hub"' } },
      { label = 'tmux (attach or start)', args = { 'zsh', '-l', '-c', 'tmux attach-session -t main 2>/dev/null || tmux new-session -s main' } },
   },
   set_environment_variables = {
      TERMINAL_STACK_PROFILE = 'wezterm',
      TMUX_TMPDIR = home .. '/.cache/tmux',
   },
}

return options
