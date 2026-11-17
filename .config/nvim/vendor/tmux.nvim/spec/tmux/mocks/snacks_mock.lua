local M = {}

-- Merges a minimal vim.iter stub into _G.vim (creating _G.vim if absent).
-- Required because snacks.focused_picker() calls vim.iter().
function M.setup()
    _G.vim = _G.vim or {}
    _G.vim.iter = function(t)
        local iter = {}
        function iter.find(_, predicate)
            for _, v in ipairs(t) do
                if predicate(v) then
                    return v
                end
            end
            return nil
        end
        return iter
    end
end

-- Build a minimal Snacks picker stub.
-- position: "left"|"right"|"top"|"bottom"|nil  (nil = no position)
-- is_split: truthy value or nil                 (nil = floating)
function M.make_picker(position, is_split)
    local layout_tbl = {}
    if position then
        layout_tbl.root = { opts = { position = position } }
    end
    if is_split then
        layout_tbl.split = is_split
    end
    return {
        is_focused = function()
            return true
        end,
        layout = layout_tbl,
    }
end

-- Set _G.Snacks with a single focused picker.
function M.set_focused_picker(picker)
    _G.Snacks = {
        picker = {
            get = function()
                return { picker }
            end,
        },
    }
end

return M
