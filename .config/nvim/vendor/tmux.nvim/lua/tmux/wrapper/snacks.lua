local M = {}

local snacks_to_nvim_directions = { left = "h", right = "l", top = "k", bottom = "j" }

-- Addressing https://github.com/aserowy/tmux.nvim/issues/133
-- https://github.com/folke/snacks.nvim/discussions/1802
-- snacks.nvim has a custom nvim-independent window engine, which
-- does not communicate its floating status to neovim.

function M._self()
    return Snacks -- luacheck: ignore 113
end

function M.using_snacks()
    return not not M._self()
end

function M.focused_picker()
    if not M.using_snacks() then
        return nil
    end
    local focused_snacks_window = vim.iter(M._self().picker.get()):find(function(picker)
        return picker:is_focused()
    end)
    return focused_snacks_window
end

function M.is_float(snacks_picker)
    -- snacks do have window api with `is_floating()` method, but
    -- it returns "true" even for tiled windows.
    if snacks_picker and snacks_picker.layout and snacks_picker.layout.split then
        return false
    end
    return true
end

function M.position(snacks_picker)
    if snacks_picker and snacks_picker.layout and snacks_picker.layout.root and snacks_picker.layout.root.opts then
        local pos = snacks_picker.layout.root.opts.position
        return snacks_to_nvim_directions[pos] or pos
    end
    return nil
end

return M
