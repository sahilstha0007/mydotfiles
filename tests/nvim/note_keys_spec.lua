-- The three note/search keys added 2026-10-06, and the two contracts they
-- quietly broke.
--
-- Why these need pinning at all: a keymap is trivially deletable, and its
-- absence is invisible until you press it. But the sharper risk here is the
-- opposite -- a keymap that is present, fires, and writes a note the vault's
-- own queries cannot read. Both happened during the first implementation:
-- the frontmatter drifted from the real notes, and the filename did too.
--
-- So this spec does not test "does the key exist". It tests "does what the
-- key produces match what the vault already contains", by diffing against
-- the actual files in 06 - Daily/ rather than against a copy of the
-- implementation's own assumptions.
--
-- Run: nvim --headless -u tests/minimal_init.lua -l tests/note_keys_spec.lua

local failures = {}

local function test(name, fn)
  local ok, err = pcall(fn)
  if not ok then
    table.insert(failures, name .. ': ' .. tostring(err))
  end
end

local function check(value, message)
  if not value then
    error(message or 'check failed', 2)
  end
end

local _src = debug.getinfo(1, 'S').source:sub(2)
local _cand = vim.fn.fnamemodify(_src, ':p:h:h')
local root = vim.env.NVIM_CONFIG_ROOT or (vim.fn.isdirectory(_cand .. '/lua') == 1 and _cand or (vim.fn.fnamemodify(_cand, ':h') .. '/.config/nvim'))

-- ---------------------------------------------------------------- the keys

-- The three maps live in snacks' picker spec, and their handlers close over a
-- picker that does not exist headless. So this spec reads the SOURCE rather
-- than calling through snacks. That is deliberate: the contracts being pinned
-- here are the literal strings the vault depends on, and those are visible in
-- the source without booting anything.
--
-- It also sidesteps the 'VeryLazy' trap -- snacks' keymaps are registered off
-- UIEnter, so a headless spec that asked vim for the maps would find none,
-- exactly as an earlier health fix silently did nothing for the same reason.
local function source_of()
  local path = root .. '/lua/plugins/editor/snacks.lua'
  return table.concat(vim.fn.readfile(path), '\n')
end

-- The frontmatter KEYS the vault's daily notes carry, in order.
--
-- This used to be scraped out of the config's own inline template literal,
-- which meant the spec asserted "the config matches itself" and passed no
-- matter what the vault actually contained. That is precisely the drift class
-- it was written to catch: the inline copy diverged (workout: true vs false,
-- and the whole note body missing) while the spec stayed green.
--
-- The config no longer keeps a copy -- it reads the vault template at runtime.
-- So the source of truth here is the same: the vault. Asserted against a real
-- note when one is reachable, otherwise against Obsidian's own daily-notes
-- config plus the template file, so this still runs on a machine without the
-- vault rather than silently skipping.
-- Substitutes the vault template using the CONFIG'S OWN implementation.
--
-- This used to be a verbatim copy of the handler's logic inside the spec,
-- which made it useless as a check: mutating the config's month mapping to
-- os.date 'MM' left the spec reporting ok while the config rendered
-- "2026-MM-08". Verified against a copy of the repo. Both sides now require
-- utils.templater, so a regression in one fails the other.
local Templater = require 'utils.templater'

-- The literal, non-date lines the daily note must contain: the frontmatter
-- keys and the body headings. Templater expressions are substituted away
-- first, so what is left is exactly what the note would show.
local function daily_template()
  local vault = Templater.vault_root()
  check(vault, 'vault not found; set ATLAS_VAULT to run this spec')

  -- Templater.template_path owns the vault-relative-path resolution. The spec
  -- had its own copy and disagreed with the config's: the config joined the
  -- Obsidian `template` value onto the templates folder, doubling the path,
  -- so the template read failed and the key silently produced a bare
  -- frontmatter block. Both read one implementation now.
  local path = Templater.template_path(vault)
  check(path, 'could not resolve the daily template path')
  check(vim.fn.filereadable(path) == 1, 'template not readable: ' .. path)

  local rendered = Templater.expand(table.concat(vim.fn.readfile(path), '\n'))
  check(
    rendered,
    'Templater.expand gave up on the daily template -- it has an expression form the config does not handle'
  )
  check(
    not string.find(rendered, '<%', 1, true),
    'template still has unsubstituted Templater expressions: '
      .. tostring(rendered:match '<%%[^%%]*%%>')
  )

  local lines = {}
  for raw in rendered:gmatch '[^\n]+' do
    local code = raw:gsub('%-%-.*$', '')
    if
      code ~= ''
      and code ~= '---'
      and not code:match '^%-%s%d%d%d%d%-%d%d%-%d%dT'
    then
      table.insert(lines, code)
    end
  end
  return lines
end

--- Collapse runs of whitespace, newlines included.
---
--- Needed because stylua reflows code across lines and a pattern written for a
--- single line silently stops matching when the formatter wraps it -- which
--- looks identical to the code actually being broken. Used by two tests that
--- both match against whole files.
local function normalize(text)
  return (text:gsub('%s+', ' '))
end

-- --------------------------------------------------- 0. date values
--
-- Added after mutation testing showed the rest of this file was blind to a
-- wrong-but-plausible date. Every other assertion here checks the SHAPE of the
-- note -- which keys, which headings, which filename -- and the frontmatter
-- keys contain no dates at all. So replacing the month mapping in
-- utils/templater.lua with os.date 'MM' rendered "2026-MM-08" in every note
-- and this spec still reported ok. Verified against a copy of the repo.
--
-- These assert resolved VALUES, computed from os.date at run time so the test
-- does not depend on what day it is. Synthetic format strings only: no vault
-- content is read or printed here.
test('moment resolves every format the daily template uses', function()
  local today = os.date '%Y-%m-%d'
  check(
    Templater.moment 'YYYY-MM-DD' == today,
    ('moment("YYYY-MM-DD") must be today, got %q not %q'):format(
      Templater.moment 'YYYY-MM-DD',
      today
    )
  )

  local month_name = os.date '%B'
  check(
    Templater.moment 'MMMM' == month_name,
    ('moment("MMMM") must be the full month name, got %q not %q'):format(
      Templater.moment 'MMMM',
      month_name
    )
  )

  -- The bug that started this: "YYYY-MM-DD" rendered "2026-MM-08" because the
  -- MM mapping was missing and the token survived into the note. Assert the
  -- literal token is gone from every rendered form, not just that the date
  -- happens to look right.
  for _, fmt in ipairs { 'YYYY-MM-DD', 'dddd, MMMM Do, YYYY', 'dddd' } do
    local rendered = Templater.moment(fmt)
    check(
      not string.find(rendered, 'MM', 1, true),
      ('moment(%q) left an unsubstituted MM token: %q'):format(fmt, rendered)
    )
    check(
      not string.find(rendered, 'YYYY', 1, true),
      ('moment(%q) left an unsubstituted YYYY token: %q'):format(fmt, rendered)
    )
  end
end)

-- Every token moment() claims to support, checked against the value os.date
-- produces for it. Mutation testing showed the hand-written cases above cover
-- only the tokens the daily template happens to use: mutating the MMM, ddd, or
-- HH:mm mappings left the spec green, because nothing exercised them. A test
-- list is a guess at what matters; this table is the implementation's own
-- contract, so adding a token without a case fails here.
test('moment resolves every token it supports', function()
  local cases = {
    { 'YYYY', os.date '%Y' },
    { 'MMMM', os.date '%B' },
    { 'MMM', os.date '%b' },
    { 'MM', os.date '%m' },
    { 'dddd', os.date '%A' },
    { 'ddd', os.date '%a' },
    { 'DD', os.date '%d' },
    { 'HH:mm', os.date '%H:%M' },
  }
  for _, case in ipairs(cases) do
    local token, want = case[1], case[2]
    local got = Templater.moment(token)
    check(
      got == want,
      ('moment(%q) must be %q, got %q'):format(token, want, got)
    )
    -- And the token must not survive into the output.
    check(
      not string.find(got, token, 1, true),
      ('moment(%q) left the token itself in the output: %q'):format(token, got)
    )
  end
end)

test('moment resolves Do as an English ordinal', function()
  local n = tonumber(os.date '%-d')
  local want = Templater.ordinal(n)
  check(
    Templater.moment 'Do' == want,
    ('moment("Do") must be %q, got %q'):format(want, Templater.moment 'Do')
  )
end)

test('expand substitutes the multi-argument Templater forms', function()
  -- The vault template uses 4-argument tp.date.now() calls and a
  -- concatenation expression with a literal prefix. Each of these is a form
  -- that has escaped a previous version of this matcher, so each is pinned.
  local out = Templater.expand 'date: <%tp.date.now("YYYY-MM-DD")%>\n'
  check(
    out:find(os.date '%Y-%m-%d', 1, true) ~= nil,
    'expand must resolve a bare single-argument tp.date.now call'
  )

  out =
    Templater.expand 'heading: <% tp.date.now("MMMM", 0, tp.file.title, "YYYYMMDD") %>\n'
  check(
    out:find(os.date '%B', 1, true) ~= nil,
    'expand must resolve a spaced multi-argument tp.date.now call'
  )

  out =
    Templater.expand 'item: <% "- " + tp.date.now("dddd", 0, tp.file.title, "YYYYMMDD").toLowerCase() %>\n'
  check(
    out:find('- ' .. os.date('%A'):lower(), 1, true) ~= nil,
    'expand must resolve a lowercased tp.date.now inside a concatenation, keeping the literal prefix'
  )
  check(
    out:find('.toLowerCase', 1, true) == nil,
    'expand must not leave .toLowerCase visible in the note'
  )
end)

test(
  'expand gives up rather than emit a raw expression it cannot render',
  function()
    local out = Templater.expand 'x: <% tp.user.some_unhandled_thing() %>\n'
    check(
      out == nil,
      'an unrendered non-date expression must make expand return nil, not a half-rendered note'
    )
  end
)

-- --------------------------------------------------- 1. frontmatter literal

test('daily note frontmatter matches the vault exactly', function()
  local got = daily_template()

  -- The keys below are what every existing note carries. If the template
  -- drops or renames one, the vault's Dataview/Dashboard queries go quiet.
  local required = {
    'tags:',
    '  - Daily',
    'cssclasses:',
    '  - daily-dash',
    'dsa: 0',
    'build: 0',
    'learn: 0',
    -- false, not true. This list originally pinned `workout: true`, which
    -- was the drift itself: the vault's template says false. The spec had
    -- baked in the wrong value instead of reading the vault, which is the
    -- failure mode this file exists to prevent.
    'workout: false',
  }
  for _, want in ipairs(required) do
    check(
      vim.tbl_contains(got, want),
      ('template is missing the line %q -- the vault queries key off it'):format(
        want
      )
    )
  end

  -- And no keys the vault does not have, which would be dead frontmatter.
  -- `date` is exempt: it is real, but its value is an os.date() call, so the
  -- literal extracted here is the format string, not a key name.
  local known = { date = true }
  for _, v in ipairs(required) do
    local k = v:match '^(%S+):'
    if k then
      known[k] = true
    end
  end
  for _, line in ipairs(got) do
    local key = line:match '^(%S+):'
    if key then
      check(
        known[key],
        ('template emits frontmatter key %q, which no existing note uses'):format(
          key
        )
      )
    end
  end
end)

-- ------------------------------------------------------- 2. weekday casing

test('weekday is lowercased to match the vault cssclasses', function()
  -- cssclasses drives the daily-dash styling. The notes carry `wednesday`,
  -- not `Wednesday`; a mismatched case silently drops the styling rather
  -- than erroring, which is exactly the kind of thing nobody notices for
  -- months. This asserts the transformation the code actually performs.
  local lower = ('Wednesday'):lower()
  check(lower == 'wednesday', 'lower() must produce the bare weekday')

  local src = source_of()
  check(
    src:match "os%.date%('%%A'%)%:lower%(%)",
    'the weekday must be explicitly lowercased -- bare %A is capitalised'
  )
end)

-- ------------------------------------------------- 3. heading ordinal form

test('heading carries an English ordinal suffix like the real notes', function()
  -- Every note in the vault is "September 23rd", "September 5th" -- not
  -- "September 23". A bare day number is not what any of them use, so a
  -- note written by this key would be the only one in the folder without it.
  local src = source_of()

  local ordinal = Templater.ordinal

  -- spot-check the tricky English cases
  check(ordinal(1) == '1st', '1st')
  check(ordinal(2) == '2nd', '2nd')
  check(ordinal(3) == '3rd', '3rd')
  check(ordinal(4) == '4th', '4th')
  check(ordinal(11) == '11th', '11th -- teens take "th" despite ending in 1')
  check(ordinal(12) == '12th', '12th -- teens take "th" despite ending in 2')
  check(ordinal(13) == '13th', '13th -- teens take "th" despite ending in 3')
  check(ordinal(21) == '21st', '21st -- back to "st" past the teens')
  check(ordinal(22) == '22nd', '22nd')
  check(ordinal(23) == '23rd', '23rd -- the one actually in the vault')
  check(ordinal(101) == '101st', '101st')

  -- The implementation must USE such a helper, not bare %-d.
  --
  -- The negation alone is not enough: an earlier version of this test also
  -- asserted a local ordinal() helper above, which tested the TEST's own copy
  -- and so passed no matter what the config did. Assert on the config's
  -- function specifically, by name, and require it to be applied to the
  -- day-of-month.
  check(
    Templater.ordinal(5) == '5th',
    'utils/templater.lua must export the ordinal() helper the config uses'
  )
  -- `os.date '%-d'` is a call with a STRING literal, not parentheses -- the
  -- first attempt required `os.date(...)` and could never match. And the
  -- strftime format `%-d` contains a literal `-` that ALSO needs escaping in a
  -- Lua pattern, so it is `%%%-d`, not `%%-d`. Getting that wrong is silent:
  -- the pattern just never matches, and the assertion then fails for a
  -- reason that has nothing to do with the code under test. Verified against
  -- the real file rather than reasoned about: `%%-d` -> no match,
  -- `%%%-d` -> matches.
  -- Both call sites must render the day through ordinal(): the fallback
  -- heading in snacks.lua, and the "Do" token in utils/templater.lua.
  -- Checking only the config would miss a regression in the module -- which is
  -- the only path that produces a heading when the vault template is present,
  -- i.e. the common case.
  local templater_src =
    table.concat(vim.fn.readfile(root .. '/lua/utils/templater.lua'), '\n')
  -- Whitespace is normalised first because stylua wraps this call across
  -- several lines. That wrapping is not cosmetic: the fallback heading reads
  --
  --   '# ' .. os.date '%A, %B ' .. Templater.ordinal( tonumber(os.date '%-d') )
  --
  -- so a line-at-a-time match can never see os.date inside the same line as
  -- ordinal(, and a single-line pattern stops matching the moment the
  -- formatter reflows it. Both failures look identical -- "must render the day
  -- through ordinal(...)" -- while meaning opposite things. Match the
  -- normalised whole file instead.
  -- `[%w_%.]*` allows a qualifier before the call name, so this matches all
  -- three real spellings: `M.ordinal(` in templater.lua, `Templater.ordinal(`
  -- in snacks.lua, and a bare `ordinal(`. Matching only the bare form is a
  -- false failure the moment the call is namespaced, and the check would then
  -- only pass for a file that has no ordinal call at all -- the worst kind of
  -- test: green until the code stops existing.
  local ORDINAL_CALL =
    "[%w_%.]*ordinal%s*%(%s*tonumber%s*%(%s*os%.date%s*'%%%-d'%s*%)"
  check(
    normalize(src):match(ORDINAL_CALL),
    'snacks.lua must render the fallback heading through ordinal(tonumber(os.date %-d))'
  )
  check(
    normalize(templater_src):match(ORDINAL_CALL),
    "templater.lua's moment() must render the Do token through ordinal(tonumber(os.date %-d))"
  )
  -- The two checks above are the load-bearing ones: each file must render the
  -- day through ordinal(). This scan is the belt-and-braces guard that no OTHER
  -- os.date '%-d' has crept in unwrapped.
  --
  -- It runs over normalised WHOLE-FILE text, not line by line. Line-scoped was
  -- what this used to do, and it flagged the wrapped fallback call's
  -- continuation line (`tonumber(os.date '%-d')` alone on its own line) as a
  -- bare render -- a false failure for a call that IS wrapped. At line scope
  -- there is no way to see the `ordinal(` that opened two lines up.
  --
  -- Comments are stripped first, because this file's own prose legitimately
  -- contains "%-d" while explaining the bug, and a bare day in a comment is
  -- not a code path. Then every remaining os.date '%-d' is counted, and the
  -- only ones allowed are those inside an ordinal(...) call -- which the two
  -- file-level checks already proved exist.
  local function strip_comments(text)
    local out = {}
    for line in text:gmatch '[^\n]+' do
      out[#out + 1] = (line:gsub('%-%-.*$', ''))
    end
    return normalize(table.concat(out, '\n'))
  end
  local function count_bare_days(text)
    local n, count = 0, 0
    while true do
      local s, e = text:find("os%.date%s*'%%%-d'", n + 1)
      if not s then
        break
      end
      count = count + 1
      n = e
    end
    return count
  end

  -- Every os.date '%-d' in either file must sit inside an ordinal(...) call.
  -- Count the ordinal-wrapped occurrences too and compare, so a stray bare
  -- render cannot hide among the legitimate ones.
  for _, pair in ipairs {
    { 'snacks.lua', src },
    { 'templater.lua', templater_src },
  } do
    local name, text = pair[1], pair[2]
    local bare = count_bare_days(strip_comments(text))
    local wrapped = 0
    for _ in strip_comments(text):gmatch(ORDINAL_CALL) do
      wrapped = wrapped + 1
    end
    check(
      bare == wrapped,
      ('%s renders the day %d time(s) but wraps %d in ordinal() -- a bare %%-d slipped in'):format(
        name,
        bare,
        wrapped
      )
    )
  end
end)

-- ------------------------------------------------------- 3.5 write target
--
-- The note used to be written via Snacks.scratch.open{ name = ... }, which
-- lands in stdpath('data')/scratch under a hashed filename -- invisible to
-- Obsidian. A comment claimed the vault copy was made by hand with `min`; no
-- such mapping exists in this config, so the note went nowhere while looking
-- written. These assert the destination, which is the whole point of the key.
test('the daily note is written into the vault, not scratch', function()
  local vault = Templater.vault_root()
  check(vault, 'vault not found; set ATLAS_VAULT to run this spec')

  local folder = Templater.daily_folder(vault)
  check(folder, 'could not read the daily folder from Obsidian config')
  check(
    vim.fn.isdirectory(vault .. '/' .. folder) == 1,
    ('daily folder %q does not exist in the vault'):format(folder)
  )

  local path = Templater.daily_note_path(vault, '20261008')
  check(path, 'daily_note_path returned nil for a readable vault')
  check(
    path == ('%s/%s/20261008.md'):format(vault, folder),
    ('note path must be <vault>/<folder>/YYYYMMDD.md, got %q'):format(path)
  )

  -- Pin the folder to Obsidian's own config rather than to whatever
  -- daily_folder() returns, since a mutation can corrupt both sides in the
  -- same way and they would agree.
  --
  -- Known limit: this cannot catch a resolver that hardcodes today's correct
  -- folder. Hardcoding '06 - Daily' renders an identical path, so no assertion
  -- on the output can tell it from the real implementation -- verified by
  -- mutating to that literal and watching the spec stay green. Hardcoding a
  -- DIFFERENT folder is caught, which is what would actually break the vault.
  -- Distinguishing the rest needs a fixture vault, not a bigger assertion.
  local cfg =
    table.concat(vim.fn.readfile(vault .. '/.obsidian/daily-notes.json'), '\n')
  local want_folder = vim.json.decode(cfg).folder
  check(
    folder == want_folder,
    ('daily_folder() must read Obsidian config, got %q want %q'):format(
      folder,
      want_folder
    )
  )

  -- The handler must pass that path as `file`. scratch.get() prefers `file`
  -- over `name`, so this is what actually redirects the write; asserting only
  -- on the resolver would pass even if the handler kept passing name= alone.
  local handler = normalize(
    table.concat(
      vim.fn.readfile(root .. '/lua/plugins/editor/snacks.lua'),
      '\n'
    )
  )
  check(
    handler:find 'daily_note_path%(vault, date%)' ~= nil,
    'the <leader>nn handler must resolve the note path via daily_note_path(vault, date)'
  )
  check(
    handler:find 'file = target' ~= nil,
    'the handler must pass file = to Snacks.scratch.open -- name alone writes to scratch'
  )
end)

-- ------------------------------------------------------ 4. filename format

test('daily note filename uses the vault YYYYMMDD convention', function()
  -- The folder is 20260923.md, not 2026-09-23.md. Writing a dashed name
  -- leaves a file the vault has never contained, and the date-based
  -- lookups in the dashboard will not match it.
  local src = source_of()
  -- Scope this to the FILENAME line only. The `date:` frontmatter value is
  -- legitimately dashed -- the vault's notes carry `date: 2026-09-23T20:54`,
  -- not `date: 20260923T20:54` -- so a blanket ban on '%Y-%m-%d' would demand
  -- breaking something that is already correct. Only the name is constrained.
  local nstart = source_of():find("'<leader>nn'", 1, true)
  local nend = src:find("desc = 'Daily Note", nstart, true)
  local body = src:sub(nstart, nend)
  local name_line = body:match '[^\n]*local date = [^\n]*'
  check(name_line, 'could not find the `local date = ...` line in the handler')
  check(
    not name_line:match '%%Y%-%%m%-%%d',
    ('the FILENAME date must be %%Y%%m%%d, got: %s'):format(name_line)
  )
  -- And the compact one must be present, as a string argument: the code calls
  -- `os.date '%Y%m%d'`, not `os.date('%Y%m%d')`. Requiring the parenthesised
  -- form is a false negative -- it never matches the idiomatic call, so the
  -- assertion fails while the code is right. Verified both forms against the
  -- real file rather than assumed.
  check(
    src:match "os%.date '%%Y%%m%%d'",
    "filename must be built with os.date '%Y%m%d' to match the vault convention"
  )
end)

-- ------------------------------------------- 5. cross-check a real note file

test(
  'a real vault note and the template agree on every frontmatter key',
  function()
    local daily = os.getenv 'ATLAS_DAILY'
    if not daily or vim.fn.isdirectory(daily) == 0 then
      -- Not fatal: the vault is outside this repo and may be absent on another
      -- machine. The literal checks above still pin the contract.
      return
    end

    local files = vim.fn.glob(daily .. '/*.md', false, true)
    check(#files > 0, 'no notes found in ' .. daily)
    local file = files[#files]
    local lines = vim.fn.readfile(file)

    local keys = {}
    for _, l in ipairs(lines) do
      if l == '---' and #keys > 0 then
        break
      end
      -- `---` is the frontmatter delimiter, not a key line.
      if l ~= '---' then
        local k = l:match '^(%S+):'
        if k then
          keys[k] = true
        end
      end
    end

    local got = daily_template()
    local template_keys = {}
    for _, l in ipairs(got) do
      local k = l:match '^(%S+):'
      if k then
        template_keys[k] = true
      end
    end

    for k in pairs(keys) do
      check(
        template_keys[k],
        ('the newest note (%s) has frontmatter key %q, the template does not'):format(
          vim.fn.fnamemodify(file, ':t'),
          k
        )
      )
    end
  end
)

if #failures > 0 then
  error(table.concat(failures, '\n'), 0)
end
print 'note_keys_spec: ok'
