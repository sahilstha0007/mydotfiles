-- Project Python environment detector shared by basedpyright and venv-selector.
local M = {}

local VENV_DIRS = { '.venv', 'venv', '.env', 'env', '.pixi' }

---Detect a project-local or active shell Python interpreter.
---@param start_dir? string Directory to search upward from (defaults to cwd)
---@return string|nil python_path
---@return string|nil env_type 'venv' | 'anaconda'
function M.detect(start_dir)
  local dir = (start_dir and start_dir ~= '') and start_dir or vim.fn.getcwd()
  local home = vim.uv.os_homedir()
  local matches = vim.fs.find(VENV_DIRS, {
    path = dir,
    upward = true,
    type = 'directory',
    stop = home,
    limit = math.huge,
  })

  for _, candidate in ipairs(matches) do
    local name = vim.fs.basename(candidate)
    if name == '.pixi' then
      local py = candidate .. '/envs/default/bin/python'
      if vim.fn.executable(py) == 1 then
        return py, 'anaconda'
      end
    else
      local py = candidate .. '/bin/python'
      if vim.fn.executable(py) == 1 then
        return py, 'venv'
      end
    end
  end

  local venv = vim.env.VIRTUAL_ENV
  if venv and venv ~= '' then
    local py = venv .. '/bin/python'
    if vim.fn.executable(py) == 1 then
      return py, 'venv'
    end
  end

  local conda = vim.env.CONDA_PREFIX
  if conda and conda ~= '' then
    local py = conda .. '/bin/python'
    if vim.fn.executable(py) == 1 then
      return py, 'anaconda'
    end
  end

  return nil, nil
end

---Detect a Python interpreter starting from a buffer's directory.
---@param bufnr? integer
---@return string|nil python_path
---@return string|nil env_type
function M.detect_for_buf(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(bufnr)
  local start_dir = name ~= '' and vim.fs.dirname(name) or vim.fn.getcwd()
  return M.detect(start_dir)
end

return M
