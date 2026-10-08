-- Templater date-expression rendering for the Atlas daily note.
--
-- Extracted from the <leader>nn handler so that tests/note_keys_spec.lua can
-- exercise the REAL implementation instead of a copy of it.
--
-- That copy is exactly what went wrong before: the spec kept its own
-- `expand_template` copy of the substitution rules, so a mutation to the
-- config's `moment()` (removing the MM month mapping, say) left the spec
-- passing -- verified, the config produced "2026-MM-08" and the spec said ok.
-- A test that re-implements the thing it tests checks its own assumptions.
-- So this module is the single source of truth and both sides require it.

local M = {}

--- English ordinal: 1st/2nd/3rd/4th, but 11th/12th/13th and 21st/22nd.
function M.ordinal(n)
  local suffix = ({ [1] = 'st', [2] = 'nd', [3] = 'rd' })[n % 10]
  if not suffix or (n % 100 >= 11 and n % 100 <= 13) then
    suffix = 'th'
  end
  return n .. suffix
end

--- Translate a moment.js-style format string to today's date.
--
-- Order is load-bearing: each gsub feeds the next, so MMMM must be tried
-- before MM and Do before DD. MM was missing entirely at first, which turned
-- "YYYY-MM-DD" into "2026-MM-08" -- a date that looks plausible enough to
-- pass a glance and is silently wrong.
function M.moment(fmt)
  return (
    fmt
      :gsub('YYYY', os.date '%Y')
      :gsub('MMMM', os.date '%B')
      :gsub('MMM', os.date '%b')
      :gsub('MM', os.date '%m')
      :gsub('dddd', os.date '%A')
      :gsub('ddd', os.date '%a')
      :gsub('Do', M.ordinal(tonumber(os.date '%-d')))
      :gsub('DD', os.date '%d')
      :gsub('HH:mm', os.date '%H:%M')
  )
end

--- Render the Templater expressions in a daily-note template.
---
--- Every expression in the vault's daily template reduces to
--- tp.date.now(FMT, ...), optionally followed by .toLowerCase(), optionally
--- wrapped in a larger <% %> with literal text around it:
---   <%tp.date.now("YYYY-MM-DD")%>
---   <% tp.date.now("dddd, MMMM Do, YYYY", 0, tp.file.title, "YYYYMMDD") %>
---   <% "- " + tp.date.now("dddd", 0, tp.file.title, "YYYYMMDD").toLowerCase() %>
---
--- `[^%)]*` skips any further arguments, so ONE pattern covers both the 1-arg
--- and 4-arg forms. Earlier versions enumerated forms separately and each time
--- the template had one nobody had matched: bare <%dddd%> tokens (0
--- substitutions), then the spaced heading, then the 4-arg heading. Counting
--- the expressions actually present and generalising was the fix each round;
--- guessing the next unseen form was not.
---
--- Returns nil when any tp.date.now survives, so the caller can fall back
--- rather than paste a raw Templater expression into a note.
function M.expand(s)
  -- The CONCATENATION form has to be handled before anything else, and as a
  -- whole. It is not a date expression that happens to sit in a tag -- the
  -- whole tag is a Templater expression joining a literal prefix to the date:
  --
  --   <% "- " + tp.date.now("dddd", ...).toLowerCase() %>
  --
  -- Substituting only the call and then unwrapping the tag yields
  -- `"- " + thursday` -- the quotes and the `+` survive into the note. That
  -- regression was real and was caught by the spec, after being introduced by
  -- an over-eager "generalisation" that deleted the earlier handler for this
  -- exact case. Matching it as one unit and emitting the prefix plus the
  -- value is the only thing that renders correctly.
  s = s:gsub(
    '<%%%s*"([^"]*)"%s*%+%s*tp%.date%.now%("([^"]*)"[^%)]*%)%.toLowerCase%(%)%s*%%>',
    function(prefix, fmt)
      return prefix .. M.moment(fmt):lower()
    end
  )
  -- Same shape without the .toLowerCase() suffix.
  s = s:gsub(
    '<%%%s*"([^"]*)"%s*%+%s*tp%.date%.now%("([^"]*)"[^%)]*%)%s*%%>',
    function(prefix, fmt)
      return prefix .. M.moment(fmt)
    end
  )

  -- These two take the OPTIONAL surrounding tags with them, so a template made
  -- only of the four supported forms leaves no `<% %>` behind at all. That is
  -- what makes the guard below a complete statement rather than a guess.
  s = s:gsub(
    '<%%%s*tp%.date%.now%("([^"]*)"[^%)]*%)%.toLowerCase%(%)%s*%%>',
    function(fmt)
      return M.moment(fmt):lower()
    end
  )
  s = s:gsub('<%%%s*tp%.date%.now%("([^"]*)"[^%)]*%)%s*%%>', function(fmt)
    return M.moment(fmt)
  end)

  -- Any tag still standing is a Templater expression this does not handle.
  -- Returning nil sends the caller to its fallback, which is right: the old
  -- behaviour unwrapped every leftover tag and pasted the expression into the
  -- note as visible text, so an unrecognised `tp.user.something()` shipped to
  -- the vault instead of falling back.
  if string.find(s, '<%', 1, true) then
    return nil
  end

  return s
end

--- Root of the Atlas vault, or nil if the path does not look like one.
---
--- Requiring .obsidian/ means a typo'd path falls back to the minimal inline
--- note instead of half-reading a real vault that isn't there.
function M.vault_root()
  local candidate = os.getenv 'ATLAS_VAULT'
    or vim.fn.expand '~/Documents/Notes/Atlas'
  if vim.fn.isdirectory(candidate .. '/.obsidian') == 1 then
    return candidate
  end
  return nil
end

--- Vault-relative path of the daily-note template, per Obsidian's config.
---
--- `template` is relative to the VAULT ROOT and already includes the
--- templates folder ("99 - Meta/00 - Templates/..."). Joining it onto the
--- templates folder produced a doubled path, the read failed, and the key
--- silently fell back to a bare frontmatter block.
function M.template_path(vault)
  local rel = '99 - Meta/00 - Templates/(TEMPLATE) Daily.md'
  local cfg = vault and (vault .. '/.obsidian/daily-notes.json')
  if cfg and vim.fn.filereadable(cfg) == 1 then
    local ok, decoded =
      pcall(vim.json.decode, table.concat(vim.fn.readfile(cfg), '\n'))
    if ok and type(decoded) == 'table' then
      if type(decoded.template) == 'string' and decoded.template ~= '' then
        rel = decoded.template
          .. (decoded.template:match '%.md$' and '' or '.md')
      end
    end
  end
  return vault and (vault .. '/' .. rel) or nil
end

return M
