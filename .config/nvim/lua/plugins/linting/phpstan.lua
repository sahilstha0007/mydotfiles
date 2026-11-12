local function get_root()
  local current_file = vim.api.nvim_buf_get_name(0)
  if current_file == '' then
    return vim.fn.getcwd()
  end
  local root = vim.fs.find(
    { 'phpstan.neon', 'phpstan.neon.dist', 'composer.json', 'vendor' },
    { path = vim.fs.dirname(current_file), upward = true }
  )[1]
  return root and vim.fs.dirname(root) or vim.fn.getcwd()
end

-- Return a factory so nvim-lint evaluates cwd and project-local vs Mason binary
-- per buffer instead of freezing cwd at startup.
return function()
  local root = get_root()
  local local_bin = root .. '/vendor/bin/phpstan'
  local cmd = vim.fn.executable(local_bin) == 1 and local_bin or 'phpstan'

  return {
    name = 'phpstan',
    cmd = cmd,
    stdin = false,
    append_fname = true,
    args = {
      '--memory-limit=2G',
      'analyse',
      '--error-format=raw',
      '--no-progress',
    },
    stream = 'both',
    ignore_exitcode = true,
    cwd = root,
    parser = require('lint.parser').from_pattern(
      '^(.+):(%d+):(.+)$',
      { 'file', 'lnum', 'message' },
      nil,
      {
        source = 'phpstan',
        severity = vim.diagnostic.severity.WARN,
      }
    ),
  }
end
