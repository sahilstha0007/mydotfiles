-- OpenCode in-editor bridge (opencode.nvim). Pinned to the v1 line on purpose:
-- `version = '*'` means *highest tag*, and the plugin's `main` tracks OpenCode
-- v2, whose API breaks every v1 call this config makes (event payloads, auth).
-- Naming the tag removes the ambiguity rather than relying on lazy-lock alone.
-- The matching opencode CLI is 1.18.32 (newest v1); the PLUGIN version is its
-- own v1.0.2 — they are different version lines, don't conflate them.
-- What this adds over the terminal TUI in agent-picker: ask/select with
-- @-context injection (snacks.input), every proposed edit opens as a
-- :diffpatch review (da accept · dr reject · dp/do per hunk · ]c/[c walk),
-- real-time buffer reloads while the agent works, a lualine status, and the
-- TUI auto-revealing when the agent starts executing.
return {
  'nickjvandyke/opencode.nvim',
  version = 'v1.0.2',
  keys = {
    {
      '<leader>ao',
      function()
        require('plugins.editor.opencode-harness').ask()
      end,
      desc = 'Ask OpenCode (with context)',
    },
    {
      '<leader>ap',
      function()
        require('agent-panel').toggle()
      end,
      desc = 'Agent Panel toggle (live change tree)',
    },
    {
      '<leader>aP',
      function()
        require('agent-panel').detach()
      end,
      desc = 'Agent Panel (detach — recover if the panel is stuck)',
    },
    {
      '<leader>as',
      function()
        require('opencode').select()
      end,
      desc = 'OpenCode menu (prompts, edits, commands)',
    },
  },
  config = function()
    require('agent-panel').setup()
    -- `serve` is the headless server. Bare `opencode --port` launches the
    -- interactive TUI instead (opencode ignores an unknown port on the TUI
    -- path), so a `serve` subcommand is required for a background server.
    --
    -- `--port 0` is the documented default (OS-assigned ephemeral port), so it
    -- changes nothing about which port we get. It is here purely so the
    -- plugin's own discovery can find what we start: it scans with
    -- `pgrep -f "opencode.*--port"` (server/discovery/process/unix.lua:5).
    -- Drop the flag and the pgrep finds nothing, discovery rejects, and every
    -- ask dies with "No OpenCode servers found with overlapping CWD".
    -- ponytail: if a future plugin release stops matching on this literal,
    -- switch to opts.server.url instead of chasing the string.
    local command = { 'opencode', 'serve', '--port', '0' }
    local terminal_open = false
    local server_term = nil

    local function normalize(path)
      path = vim.uv.fs_realpath(path) or vim.fs.normalize(path)
      return path ~= '/' and path:gsub('/+$', '') or path
    end

    local function overlaps(a, b)
      a, b = normalize(a), normalize(b)
      local function contains(parent, child)
        local prefix = parent == '/' and '/' or parent .. '/'
        return child == parent or child:sub(1, #prefix) == prefix
      end
      return contains(a, b) or contains(b, a)
    end

    -- Does a headless `opencode serve` already run for this cwd?
    --
    -- We must read argv, not a process-name string: `opencode` on this box is
    -- a pnpm shell wrapper, so the real process is the `opencode.exe` bun
    -- binary with `serve` as argv[1]. A `pgrep -f "opencode --port"` also
    -- matches any shell whose command line merely *mentions* those words,
    -- which would wrongly suppress the start. So: match on the executable
    -- (via /proc/<pid>/exe, which is immune to argv[0] tricks) being the
    -- real opencode binary, plus the `serve` subcommand, plus a cwd overlap.
    local function server_overlaps(cwd)
      for _, dir in ipairs(vim.fn.glob('/proc/[0-9]*', false, true)) do
        local pid = dir:match('/proc/(%d+)$')
        local exe = pid and vim.uv.fs_readlink(dir .. '/exe')
        if exe and exe:match('[/\\]opencode[^/\\]*$') then
          local cmdline = dir .. '/cmdline'
          local file = io.open(cmdline, 'rb')
          local raw = file and file:read('*a')
          if file then
            file:close()
          end
          local argv = raw and vim.split(raw, '\0', { plain = true, trimempty = true }) or {}
          if vim.tbl_contains(argv, 'serve') then
            local process_cwd = vim.uv.fs_readlink(dir .. '/cwd')
            if process_cwd and overlaps(process_cwd, cwd) then
              return true
            end
          end
        end
      end
      return false
    end

    local function agents(context)
      local cwd = context.server.cwd
      local path = vim.fs.joinpath(cwd, 'AGENTS.md')
      local stat = vim.uv.fs_stat(path)
      if not stat or stat.type ~= 'file' then
        return nil
      end
      return context.format({ path = path, rel = cwd })
    end

    local builtins = require('opencode.context.builtins')
    -- Additions ONLY. Do not list the plugin's own builtins here.
    --
    -- `require('opencode.config')` merges with
    --   vim.tbl_deep_extend("force", deepcopy(defaults), vim.g.opencode_opts)
    -- which deep-merges the top level but REPLACES a nested table wholesale.
    -- Supplying `contexts = { @buffer = ..., @diagnostics = ... }` therefore
    -- deletes every context the plugin ships with. Verified at runtime before
    -- this fix: the live table was exactly
    --   { "@buffer", "@agents", "@quickfix", "@diagnostics" }
    -- with @this, @buffers, @visible and @marks silently gone. @this is the
    -- selection/cursor range, i.e. "explain what I just highlighted" asked the
    -- agent about a whole file and got a confident wrong answer.
    --
    -- So: name only what we add. The plugin keeps the rest.
    local contexts = {
      -- Project-local agent instructions, if the project has an AGENTS.md.
      ['@agents'] = agents,
    }

    vim.g.opencode_opts = {
      contexts = contexts,
      server = {
        start = function()
          local cwd = vim.fn.getcwd()
          if terminal_open then
            return
          end
          -- Single-instance by default, but no longer unconditionally. The
          -- guard was written for a Bun segfault (loop 2); on 1.18.32 three
          -- same-cwd servers run side by side, each on its own port, with no
          -- crash. More importantly, the PLUGIN already has an agent manager:
          -- discovery/init.lua picks automatically at 0 servers (start one)
          -- and 1 (use it), and opens its cwd-scored server picker at 2+.
          -- Refusing here made that picker unreachable, so `g:allow_multi`
          -- hands the decision back to the plugin. Default stays single, so
          -- the segfault protection is one `:let` away rather than deleted.
          if server_overlaps(cwd) and not vim.g.opencode_multi_server then
            -- Returning nil here looks like success to the plugin, which then
            -- polls for 5s and reports a generic "no servers found". Say why.
            vim.notify(
              'opencode: server already running for this cwd (set g:opencode_multi_server to run several)',
              vim.log.levels.INFO
            )
            return
          end

          terminal_open = true
          -- `serve` runs headless: keep the pane out of the way and let the
          -- plugin's own discovery (pgrep + lsof) find the listening port.
          local ok, terminal = pcall(require('snacks.terminal').open, command, {
            cwd = cwd,
            interactive = false,
            win = { position = 'right', enter = false },
          })
          if not ok then
            terminal_open = false
            error(terminal)
          end
          server_term = terminal

          vim.api.nvim_create_autocmd('TermClose', {
            buffer = terminal and terminal.buf,
            once = true,
            callback = function()
              terminal_open = false
              server_term = nil
            end,
          })
          return terminal
        end,
      },
    }

    -- Merge our additions INTO the already-resolved defaults, never over them.
    --
    -- The plugin resolves `M.opts` once at require time with
    --   tbl_deep_extend("force", deepcopy(defaults), vim.g.opencode_opts)
    -- so `vim.g.opencode_opts.contexts` above is already merged by now.
    -- This line used to ASSIGN, which threw away every context the plugin ships
    -- (@this, @buffers, @visible, @marks) and left only what we named. Assigning
    -- is the same bug as passing the full table through vim.g -- the deep
    -- extend only ever runs once, at first require.
    local resolved = require('opencode.config').opts.contexts or {}
    for name, build in pairs(contexts) do
      resolved[name] = build
    end

    -- Reveal the server terminal when a run starts. It used to hold the
    -- interactive TUI; with `serve` it holds server stdout/stderr, so this is
    -- now how a server-side failure becomes visible. Drop this autocmd if the
    -- split gets in the way of diff review -- progress is on the agent panel
    -- (<leader>ap) regardless.
    --
    -- Use the terminal captured at start. snacks keys a terminal by a hash of
    -- {cmd, cwd, env, count}, so looking it up again by `command` misses
    -- whenever cwd moved or `3<leader>ao` bumped the count -- and the lookup
    -- returning nil is what made a failed start invisible.
    vim.api.nvim_create_autocmd('User', {
      pattern = 'OpencodeEvent:session.execution.started',
      callback = function()
        if server_term then
          server_term:show()
        end
      end,
    })
  end,
}
