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

local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')

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

-- Pull the template lines out of the <leader>nn handler: every string literal
-- that is NOT wrapped in os.date(...) is a literal the vault must match.
local function daily_template()
  local src = source_of()
  local start = src:find("'<leader>nn'", 1, true)
  check(start, 'could not find <leader>nn in snacks.lua')
  local stop = src:find("desc = 'Daily Note", start, true)
  check(stop, 'could not find the end of the <leader>nn handler')
  local body = src:sub(start, stop)

  -- Scope to the TEMPLATE TABLE only. Scraping every quoted string in the
  -- handler also picks up the ordinal() helper and the concatenations around
  -- os.date, whose quotes close mid-expression -- an earlier version of this
  -- extraction reported a literal ")" as a frontmatter key.
  local tstart = body:find('template = table.concat', 1, true)
  check(tstart, 'could not find the template table in the <leader>nn handler')
  local tend = body:find("}, '\\n')", tstart, true)
  check(tend, 'could not find the end of the template table')
  local table_body = body:sub(tstart, tend)

  -- Collect the template's own literals. Exclude:
  --   * bare strftime formats ('%A', '%Y-%m-%dT%H:%M', ...) -- dynamic parts,
  --     tested separately against a known date
  --   * '---' separators and the empty trailing line -- structural
  local lines = {}
  for raw in table_body:gmatch "'([^']*)'" do
    if raw ~= '' and raw ~= '---' and raw ~= '\n' and not raw:match '^%%' then
      table.insert(lines, raw)
    end
  end
  return lines
end

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
    'workout: true',
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

  local function ordinal(n)
    local suffixes = { [1] = 'st', [2] = 'nd', [3] = 'rd' }
    local s = suffixes[n % 10]
    if not s or (n % 100 >= 11 and n % 100 <= 13) then
      s = 'th'
    end
    return n .. s
  end

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
    src:match 'local function ordinal',
    'snacks.lua must define an ordinal() helper next to the <leader>nn handler'
  )
  -- `os.date '%-d'` is a call with a STRING literal, not parentheses -- the
  -- first attempt required `os.date(...)` and could never match. And the
  -- strftime format `%-d` contains a literal `-` that ALSO needs escaping in a
  -- Lua pattern, so it is `%%%-d`, not `%%-d`. Getting that wrong is silent:
  -- the pattern just never matches, and the assertion then fails for a
  -- reason that has nothing to do with the code under test. Verified against
  -- the real file rather than reasoned about: `%%-d` -> no match,
  -- `%%%-d` -> matches.
  local ORDINAL_CALL = "ordinal%(tonumber%(os%.date '%%%-d'%)"
  check(
    src:match(ORDINAL_CALL),
    'the heading must render the day through ordinal(tonumber(os.date %-d))'
  )
  -- No CODE path may render a bare day: if one survives, some note still gets
  -- written without its ordinal. Scanned over comment-stripped lines only --
  -- the prose in this file legitimately mentions "%-d" while explaining the
  -- bug, and counting that as a violation makes the check unfixable.
  local bare = 0
  for line in src:gmatch '[^\n]+' do
    local code = line:gsub('%-%-.*$', '') -- drop a trailing `--` comment
    if
      code:match 'os%.date'
      and code:match "'%%%-d'"
      and not code:match(ORDINAL_CALL)
    then
      bare = bare + 1
    end
  end
  check(
    bare == 0,
    ('found %d code line(s) rendering a bare %%-d not wrapped in ordinal()'):format(
      bare
    )
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
      if l == '---' then
      -- opening delimiter
      else
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
