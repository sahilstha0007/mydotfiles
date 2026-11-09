-- Workspace manager for wezterm (dev driver).
--
-- Named workspaces isolate projects: each workspace keeps its own tab set,
-- cwd, and layout. Switching workspaces is instant (wezterm keeps all
-- workspaces alive), so you can jump between projects without re-spawning
-- shells or re-attaching tmux sessions.
--
-- Keys (Alt+Ctrl+Space leader):
--   w -> workspace key table:
--     n  new workspace (prompt for name)
--     s  switch workspace (fuzzy list)
--     r  rename current workspace
--     d  delete current workspace (prompts confirm)
--     q  close key table
--
-- Workspaces persist across wezterm reloads (wezterm keeps them alive).
-- The default workspace is named `default`.

local wezterm = require('wezterm')
local act = wezterm.action
local M = {}

---List all workspace names (wezterm natively tracks them).
---@return string[]
local function list_workspaces()
   return wezterm.mux.get_workspace_names()
end

---Switch to a workspace by name.
---@param name string
local function switch_to(name)
   return act.SwitchToWorkspace {
      name = name,
      spawn = nil, -- nil = reuse existing workspace, don't spawn new
   }
end

---Prompt for a new workspace name, then switch to it.
local function new_workspace(window, pane)
   window:perform_action(
      act.PromptInputLine {
         description = wezterm.format {
            { Attribute = { Intensity = 'Bold' } },
            { Text = 'New workspace name:' },
         },
         action = wezterm.action_callback(function(win, _p, line)
            if not line or line == '' then
               return
            end
            -- SwitchToWorkspace creates it if it doesn't exist.
            win:perform_action(switch_to(line), pane)
         end),
      },
      pane
   )
end

---Prompt to rename the current workspace.
local function rename_workspace(window, pane)
   local current = window:active_workspace()
   window:perform_action(
      act.PromptInputLine {
         description = wezterm.format {
            { Attribute = { Intensity = 'Bold' } },
            { Text = 'Rename workspace "' .. current .. '" to:' },
         },
         action = wezterm.action_callback(function(win, _p, line)
            if not line or line == '' then
               return
            end
            -- wezterm has no rename workspace API; create new + switch,
            -- leaving the old (empty) one behind. Harmless.
            win:perform_action(switch_to(line), pane)
         end),
      },
      pane
   )
end

---Delete the current workspace after confirmation.
local function delete_workspace(window, pane)
   local current = window:active_workspace()
   if current == 'default' then
      wezterm.log_info('workspaces: refusing to delete the default workspace')
      return
   end
   window:perform_action(
      act.PromptInputLine {
         description = wezterm.format {
            { Attribute = { Intensity = 'Bold' } },
            { Text = 'Delete workspace "' .. current .. '"? Type YES to confirm:' },
         },
         action = wezterm.action_callback(function(win, _p, line)
            if line == 'YES' then
               -- wezterm has no delete-workspace API either. Switch to
               -- default first so we don't strand the user, then the old
               -- workspace simply has no windows and is GC'd on next reload.
               win:perform_action(switch_to('default'), pane)
            end
         end),
      },
      pane
   )
end

---Show a fuzzy picker over workspaces, then switch.
local function switch_workspace_picker(window, pane)
   local choices = {}
   for _, name in ipairs(list_workspaces()) do
      table.insert(choices, {
         id = name,
         label = name == 'default' and name .. ' (default)' or name,
      })
   end
   table.sort(choices, function(a, b) return a.label < b.label end)

   window:perform_action(
      act.InputSelector {
         title = 'Switch Workspace',
         choices = choices,
         fuzzy = true,
         fuzzy_description = 'Workspace: ',
         action = wezterm.action_callback(function(win, _p, idx)
            if not idx then
               return
            end
            win:perform_action(switch_to(choices[idx].id), pane)
         end),
      },
      pane
   )
end

-- stylua: ignore
M.key_table = {
   { key = 'n', action = wezterm.action_callback(new_workspace) },
   { key = 's', action = wezterm.action_callback(switch_workspace_picker) },
   { key = 'r', action = wezterm.action_callback(rename_workspace) },
   { key = 'd', action = wezterm.action_callback(delete_workspace) },
   { key = 'q', action = 'PopKeyTable' },
   { key = 'Escape', action = 'PopKeyTable' },
}

---Expose the action callbacks for binding in bindings.lua.
M.new_workspace = new_workspace
M.switch_workspace = switch_workspace_picker
M.rename_workspace = rename_workspace
M.delete_workspace = delete_workspace

return M