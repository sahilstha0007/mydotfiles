#!/usr/bin/env bash
# Run every nvim spec headless. Exits non-zero if any spec fails.
#
# The specs use a two-channel failure protocol, and BOTH channels have to be
# watched. Getting this wrong is not hypothetical:
#
#   1. A failing assertion prints a line starting "FAIL: " and carries on.
#      Exit code is always 0, so grepping the exit code reports green on a
#      suite where every check failed.
#   2. A spec that calls error() — a missing fixture, a bad path — dies before
#      it prints anything. There is no FAIL line, and the exit code is still 0.
#
# Channel 2 is how tests/opencode_harness_spec.lua sat red for an unknown
# stretch: it throws at line 112 on a fixture that no longer exists, and this
# script called it "ok". So: FAIL lines AND a non-zero exit AND the E-codes
# nvim uses for an aborted chunk. All three, or the suite lies to you.
set -uo pipefail
repo_root="$(cd "$(dirname "$(readlink -f "$0")")/../../.." && pwd)"
tests_dir="$repo_root/tests/nvim"
cd "$(dirname "$0")/.." || exit 1

fail=0
for spec in "$tests_dir"/*_spec.lua; do
  [ -e "$spec" ] || continue
  log=$(mktemp)
  timeout 120 nvim --headless -u "$tests_dir/minimal_init.lua" -l "$spec" >"$log" 2>&1
  rc=$?
  if [ "$rc" -ne 0 ] || grep -q '^FAIL:' "$log" || grep -qE '^E[0-9]{3,4}:' "$log"; then
    fail=1
    printf 'FAIL  %s\n' "$spec"
    grep -E '^FAIL:|^E[0-9]{3,4}:' "$log" | head -5 | sed 's/^/        /'
  else
    printf 'ok    %s\n' "$spec"
  fi
  rm -f "$log"
done

# Regression assertions against full config (duplicate keymaps, parser merges, LSP capabilities)
log=$(mktemp)
NVIM_NO_AUTO_INSTALL=1 nvim --headless -u init.lua -c 'lua
-- 1. Duplicate Keymap Spec Guard
local seen_keys = {}
for name, plugin in pairs(require("lazy.core.config").plugins) do
  for _, k in ipairs(plugin.keys or {}) do
    local lhs = type(k) == "table" and k[1] or k
    local mode = (type(k) == "table" and k.mode) or "n"
    local modes = type(mode) == "table" and mode or { mode }
    for _, m in ipairs(modes) do
      local id = m .. ":" .. lhs
      assert(not seen_keys[id] or seen_keys[id] == name,
        string.format("Keymap collision on %s between %s and %s", id, seen_keys[id], name))
      seen_keys[id] = name
    end
  end
end

-- 2. LSP Watcher & Parser Merge Guard
require("lazy").load({ plugins = { "nvim-lspconfig" } })
local star = vim.lsp.config["*"]
assert(star and star.capabilities and star.capabilities.workspace and star.capabilities.workspace.didChangeWatchedFiles.dynamicRegistration == false,
  "LSP dynamicRegistration for didChangeWatchedFiles should be false")

local Plugin = require("lazy.core.plugin")
local ts = require("lazy.core.config").plugins["nvim-treesitter"]
local ts_opts = Plugin.values(ts, "opts", false)
assert(vim.tbl_contains(ts_opts.ensure_installed or {}, "gomod"),
  "gomod should be present in nvim-treesitter ensure_installed")

local mti = require("lazy.core.config").plugins["mason-tool-installer.nvim"]
local mti_opts = Plugin.values(mti, "opts", false)
assert(vim.tbl_contains(mti_opts.ensure_installed or {}, "js-debug-adapter"),
  "js-debug-adapter should be present in mason-tool-installer ensure_installed")
' -c 'qa!' >"$log" 2>&1
rc=$?
if [ "$rc" -ne 0 ] || grep -q '^FAIL:' "$log" || grep -qE '^E[0-9]{3,4}:' "$log"; then
  fail=1
  printf 'FAIL  regression assertions\n'
  grep -E '^FAIL:|^E[0-9]{3,4}:' "$log" | head -5 | sed 's/^/        /'
else
  printf 'ok    regression assertions\n'
fi
rm -f "$log"

if [ "$fail" -eq 0 ]; then
  echo
  echo "all specs green"
fi
exit "$fail"
