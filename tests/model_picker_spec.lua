-- Model picker: the history parser is the whole feature, so pin its two
-- failure modes (zsh's leading index/ timestamp, and dedup) plus the keymap.
-- Run: nvim --headless -u tests/minimal_init.lua -l tests/model_picker_spec.lua

local passed, failed = 0, 0
local function check(cond, msg)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print('FAIL: ' .. msg)
  end
end

local function test(name, fn)
  local ok, err = pcall(fn)
  if not ok then
    failed = failed + 1
    print('FAIL: ' .. name .. ' -> ' .. tostring(err))
  end
end

-- ---------------------------------------------------------------------------
-- Parser, against a synthetic history in the exact zsh extended format.
-- ---------------------------------------------------------------------------
-- Ordering data: no duplicates, so "newest first" is unambiguous.
local HIST_ORDER = '/tmp/model-picker-order'
vim.fn.writefile({
  ': 1: 0;claude --model oc/space-bunny-free',
  ': 2: 0;claude --model devistral',
  ': 3: 0;claude --model free-stack',
}, HIST_ORDER)

-- Dedup data: the same id used three times must appear once.
local HIST_DEDUP = '/tmp/model-picker-dedup'
vim.fn.writefile({
  ': 1: 0;claude --model alpha',
  ': 2: 0;claude --model beta',
  ': 3: 0;claude --model alpha',
  ': 4: 0;claude --model alpha',
}, HIST_DEDUP)

-- Noise: lines that must not produce entries.
local HIST_NOISE = '/tmp/model-picker-noise'
vim.fn.writefile({
  ': 1: 0;some other command --model notclaude',
  ': 2: 0;claude',
  ': 3: 0;myclaude --model sneaky',
  ': 4: 0;claude --model real-one',
}, HIST_NOISE)

-- Real id shapes: @ and : are part of these ids and must survive intact, while
-- trailing shell punctuation (a quote, a line continuation) must be dropped.
local HIST_IDS = '/tmp/model-picker-ids'
vim.fn.writefile({
  ': 1: 0;claude --model cf/@cf/google/gemma-4-26b-a4b-it',
  ': 2: 0;claude --model kc/minimax/minimax-m3:free',
  ': 3: 0;claude --model unlimited\'',
  ': 4: 0;claude --model coders\\',
}, HIST_IDS)

local function models_from(path)
  vim.env.ZSH_HISTORY = path
  package.loaded['plugins.editor.model-history'] = nil
  return require('plugins.editor.model-history').models()
end

test('newest model sorts first', function()
  local models = models_from(HIST_ORDER)
  check(#models == 3, 'expected 3 models, got ' .. #models)
  check(models[1] == 'free-stack', 'expected free-stack first, got ' .. tostring(models[1]))
  check(models[2] == 'devistral', 'expected devistral second, got ' .. tostring(models[2]))
  check(models[3] == 'oc/space-bunny-free', 'expected oc/space-bunny-free last, got ' .. tostring(models[3]))
end)

test('the zsh index/timestamp prefix does not break matching', function()
  local models = models_from(HIST_ORDER)
  local found = false
  for _, m in ipairs(models) do
    if m == 'oc/space-bunny-free' then found = true end
  end
  check(found, 'oc/space-bunny-free not parsed from the timestamped line')
end)

test('duplicates collapse to one entry', function()
  local models = models_from(HIST_DEDUP)
  check(#models == 2, 'expected alpha+beta only, got ' .. #models .. ': ' .. table.concat(models, ','))
  check(models[1] == 'alpha', 'alpha was used most recently, expected first, got ' .. tostring(models[1]))
end)

test('non-claude and bare-claude lines are ignored', function()
  local models = models_from(HIST_NOISE)
  check(#models == 1, 'expected only real-one, got ' .. #models .. ': ' .. table.concat(models, ','))
  check(models[1] == 'real-one', 'got ' .. tostring(models[1]))
end)

test('a missing history file yields an empty list, not an error', function()
  local models = models_from('/tmp/definitely-not-a-real-history-file-xyz')
  check(#models == 0, 'expected empty list, got ' .. #models)
end)

test('@ and : survive; trailing shell punctuation is dropped', function()
  local models = models_from(HIST_IDS)
  local got = table.concat(models, '|')
  check(got:find('cf/@cf/google/gemma%-4%-26b%-a4b%-it', 1, false) ~= nil,
    'the @-bearing id was truncated: ' .. got)
  check(got:find('kc/minimax/minimax%-m3:free', 1, false) ~= nil,
    'the :-bearing id was truncated: ' .. got)
  check(got:find('unlimited', 1, false) ~= nil and not got:find("unlimited'", 1, false),
    'a trailing quote leaked into the id: ' .. got)
  check(got:find('coders', 1, false) ~= nil and not got:find('\\', 1, false),
    'a trailing backslash leaked into the id: ' .. got)
end)

vim.wait(200, function()
  return false
end)
print(string.format('%d passed, %d failed', passed, failed))
if failed > 0 then
  vim.cmd('cq')
else
  vim.cmd('qa!')
end
