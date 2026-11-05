-- Minimal init for the spec suite.
--
-- Why this exists: the first run of undo_isolation_spec used the user's full
-- config, and the spec's undo measurements were being distorted by it
-- (options.lua and plugins set buffer options, undotree was loaded, and the
-- spec's own `u` assertions stopped reproducing). A test that measures the
-- environment it happens to run in measures the config, not the behaviour.
--
-- Run a spec:
--   nvim --headless -u tests/minimal_init.lua -c "lua dofile('tests/NAME.lua')" -c "qa!"
--
-- To run the suite against a MUTATED COPY instead of the live config, point
-- this at the copy:
--   NVIM_CONFIG_ROOT=/tmp/mut/nvim nvim --headless -u tests/minimal_init.lua ...
-- The default is derived from this file's own location, so a copied tree is
-- self-testing. It was previously a hardcoded absolute path, which meant a
-- spec run inside a copied tree still put the LIVE config on the runtimepath
-- and every mutant of that copy passed green.
local _src = debug.getinfo(1, 'S').source:sub(2)
local _cand = vim.fn.fnamemodify(_src, ':p:h:h')
local config_root = vim.env.NVIM_CONFIG_ROOT or (vim.fn.isdirectory(_cand .. '/lua') == 1 and _cand or (vim.fn.fnamemodify(_cand, ':h') .. '/.config/nvim'))
vim.opt.rtp:prepend(config_root)
vim.opt.swapfile = false
vim.opt.shadafile = 'NONE'
-- Undo must behave like stock nvim here, or the measurements are meaningless.
vim.opt.undolevels = 1000
vim.opt.undoreload = 10000
