-- Agent + session picker — the "which mode, which conversation" layer.
--
-- What the user asked for vs. what already existed:
--   * toggling a harness, opening a session, tracking edited files
--     -> ALREADY SHIPPED (opencode-agent.lua, agent-panel.lua: <leader>ao/ap/aP)
--   * "auto mode that just does everything" / "build mode where I prompt once
--     and review the whole directory"
--     -> the server already has these. GET /agent returns 7; the ones worth
--        driving are `build` (executes tools) and `plan` (researches, proposes
--        before touching anything). Nothing in nvim surfaced that choice.
--
-- So this adds no machinery: it calls the plugin's own Server API.
--
-- MEASURED, not assumed (opencode 1.18.32, this session):
--   * GET /agent -> each object is {name, description, mode, native, options,
--     permission, hidden?, prompt?}. `mode` is "primary"|"subagent".
--   * THREE agents carry `hidden` (compaction, summary, title) — they are
--     internal bookkeeping, not modes a person picks. We filter them.
--   * There is NO "current agent" field on the server, and no endpoint to set
--     one. GET /session entries carry `agent` ("build"), so the current agent
--     is observable only per-session.
--   * `tui_execute_command` POSTs to /tui/publish as
--     {type="tui.command.execute", properties={command=...}} — a fire-and-forget
--     event bus. `agent.plan` and `agent.cycle` both return `true`, so the 200
--     does NOT prove the name is valid. Only `agent.cycle` is documented in
--     server/init.lua:25-40.
--
-- Consequence, stated plainly: a NAMED agent switch is not available. This
-- sends the one command the server documents and tells the truth about it.

local M = {}

---Get the server, run `fn`, and never leave a rejection unhandled.
---
---`opencode.promise.ui.select` REJECTS on cancel (promise/ui.lua:9-19), so a
---cancel is a normal outcome here, not an error. We swallow it silently
---rather than letting the plugin's notify-on-error turn every Esc into a red
---message.
---@param fn fun(server: opencode.server.Server)
local function with_server(fn)
  require('opencode.server.discovery')
    .get()
    :next(fn)
    :catch(function(err)
      -- A bare reject() carries no reason; that is the cancel path.
      if err == nil then
        return
      end
      vim.notify('agent modes: ' .. tostring(err), vim.log.levels.ERROR)
    end)
end

---Primary agents a person would actually choose, internal ones removed.
---@param agents opencode.server.Agent[]
---@return opencode.server.Agent[]
function M._pickable(agents)
  local out = vim.tbl_filter(function(a)
    return a.mode == 'primary' and not a.hidden
  end, agents or {})
  table.sort(out, function(x, y)
    return x.name < y.name
  end)
  return out
end

---Switch agent via the server's documented command.
---
---`agent.cycle` moves to the next agent in the server's own order; it is not
---"switch to the one I picked". The notify says so instead of lying.
local function run_agent_cycle()
  require('opencode').command('agent.cycle')
  vim.notify('opencode: agent cycled (build <-> plan)', vim.log.levels.INFO)
end

---<leader>ag — pick a mode, then open the ask prompt.
function M.pick_mode()
  with_server(function(server)
    return server:get_agents():next(function(agents)
      local list = M._pickable(agents)
      if #list == 0 then
        vim.notify('opencode: no selectable agents', vim.log.levels.WARN)
        return
      end

      -- Current agent is observable only per-session, so ask for the most
      -- recent one rather than pretending the server tracks it globally.
      return server:get_sessions():next(function(sessions)
        local current
        if sessions and #sessions > 0 then
          table.sort(sessions, function(a, b)
            return a.time.updated > b.time.updated
          end)
          current = sessions[1].agent
        end

        local items = {}
        for _, a in ipairs(list) do
          table.insert(items, {
            name = a.name,
            text = a.description or '',
            mark = current == a.name and '● ' or '  ',
          })
        end

        return require('opencode.promise.ui')
          .select(items, {
            prompt = ('Agent (● = current, from last session) — pick then <Space>as to ask: '),
            format_item = function(i)
              return i.mark .. i.name .. '  ' .. i.text
            end,
          })
          :next(function(choice)
            run_agent_cycle()
          end)
      end)
    end)
  end)
end

---<leader>aS — resume an earlier session.
---
---Deliberately NOT reusing opencode.ui.select_session even though it is almost
---the same code: it offers no "what was the agent on this one" column, which is
---the thing that makes a session list navigable. ponytail: this duplicates
---~10 lines of sort+format on purpose; collapse it if a third session list
---ever appears.
function M.pick_session()
  with_server(function(server)
    return require('opencode.ui.select_session')
      .select_session(server)
      :next(function(session)
        return server:select_session(session.id):next(function()
          vim.notify('opencode: resumed "' .. session.title .. '"', vim.log.levels.INFO)
          require('agent-panel').refresh()
        end)
      end)
  end)
end

function M.setup()
  vim.keymap.set('n', '<leader>ag', M.pick_mode, { desc = 'Agent mode: build / plan' })
  vim.keymap.set('n', '<leader>aS', M.pick_session, { desc = 'Agent: resume an earlier session' })
end

return M
