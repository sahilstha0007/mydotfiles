local platform = require('utils.platform')

---@type Config
local options = {
   -- ref: https://wezfurlong.org/wezterm/config/lua/SshDomain.html
   ssh_domains = {},

   -- ref: https://wezfurlong.org/wezterm/multiplexing.html#unix-domains
   unix_domains = {},

   -- ref: https://wezfurlong.org/wezterm/config/lua/WslDomain.html
   wsl_domains = {},
}

if platform.is_win then
   local win_user = os.getenv('USERNAME') or os.getenv('USER') or 'user'
   local linux_user = os.getenv('USER') or win_user
   options.ssh_domains = {
      {
         name = 'ssh:wsl',
         username = linux_user,
         remote_address = 'localhost',
         multiplexing = 'None',
         default_prog = { 'fish', '-l' },
         assume_shell = 'Posix',
      },
   }

   options.wsl_domains = {
      {
         name = 'wsl:ubuntu-fish',
         distribution = 'Ubuntu',
         username = linux_user,
         default_cwd = '/home/' .. linux_user,
         default_prog = { 'fish', '-l' },
      },
      {
         name = 'wsl:ubuntu-bash',
         distribution = 'Ubuntu',
         username = linux_user,
         default_cwd = '/home/' .. linux_user,
         default_prog = { 'bash', '-l' },
      },
   }
end

return options
