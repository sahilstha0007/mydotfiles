---@diagnostic disable: duplicate-set-field
describe("nvim wrapper", function()
    local nvim
    local snacks_mock

    setup(function()
        require("spec.tmux.mocks.log_mock").setup()
        snacks_mock = require("spec.tmux.mocks.snacks_mock")

        -- Minimal vim stubs required by nvim.lua and snacks.lua
        _G.vim = {
            api = {
                nvim_call_function = function(_, _)
                    return 1
                end,
                nvim_win_get_config = function(_)
                    return { relative = "" }
                end,
                nvim_command = function(_) end,
            },
        }
        snacks_mock.setup()

        nvim = require("tmux.wrapper.nvim")
    end)

    before_each(function()
        _G.Snacks = nil
        -- Reset winnr to a default: current window = 1, no neighbour in any direction
        nvim.winnr = function(direction)
            if direction == nil then
                return 1
            end
            return 1 -- same window → at border
        end
        vim.api.nvim_win_get_config = function(_)
            return { relative = "" }
        end
    end)

    describe("is_nvim_border without snacks", function()
        it("returns true when winnr equals winnr(1<dir>) (at border)", function()
            -- Default before_each: both return 1
            assert.is_true(nvim.is_nvim_border("h"))
        end)

        it("returns false when there is a window in that direction", function()
            nvim.winnr = function(direction)
                if direction == nil then
                    return 1
                end
                return 2 -- neighbour exists
            end
            assert.is_false(nvim.is_nvim_border("l"))
        end)
    end)

    describe("is_nvim_border with focused snacks picker", function()
        it("returns true when picker is at the queried border (left → h)", function()
            snacks_mock.set_focused_picker(snacks_mock.make_picker("left", nil))
            assert.is_true(nvim.is_nvim_border("h"))
        end)

        it("returns false when picker is at a different border", function()
            snacks_mock.set_focused_picker(snacks_mock.make_picker("left", nil))
            assert.is_false(nvim.is_nvim_border("l"))
            assert.is_false(nvim.is_nvim_border("k"))
            assert.is_false(nvim.is_nvim_border("j"))
        end)

        it("returns true when picker is at right border (right → l)", function()
            snacks_mock.set_focused_picker(snacks_mock.make_picker("right", nil))
            assert.is_true(nvim.is_nvim_border("l"))
        end)

        it("returns true when picker is at top border (top → k)", function()
            snacks_mock.set_focused_picker(snacks_mock.make_picker("top", nil))
            assert.is_true(nvim.is_nvim_border("k"))
        end)

        it("returns true when picker is at bottom border (bottom → j)", function()
            snacks_mock.set_focused_picker(snacks_mock.make_picker("bottom", nil))
            assert.is_true(nvim.is_nvim_border("j"))
        end)

        it("does not fall back to winnr when snacks picker is active", function()
            -- winnr would report no border, but snacks says we ARE at the left border
            nvim.winnr = function(direction)
                if direction == nil then
                    return 1
                end
                return 2 -- would say NOT at border
            end
            snacks_mock.set_focused_picker(snacks_mock.make_picker("left", nil))
            assert.is_true(nvim.is_nvim_border("h"))
        end)
    end)

    describe("is_nvim_float without snacks", function()
        it("returns false for a normal (non-floating) window", function()
            vim.api.nvim_win_get_config = function(_)
                return { relative = "" }
            end
            assert.is_false(nvim.is_nvim_float())
        end)

        it("returns true for a floating window", function()
            vim.api.nvim_win_get_config = function(_)
                return { relative = "editor" }
            end
            assert.is_true(nvim.is_nvim_float())
        end)
    end)

    describe("is_nvim_float with focused snacks picker", function()
        it("returns true for a floating snacks picker (no layout.split)", function()
            snacks_mock.set_focused_picker(snacks_mock.make_picker(nil, nil))
            assert.is_true(nvim.is_nvim_float())
        end)

        it("returns false for a tiled snacks picker (layout.split set)", function()
            snacks_mock.set_focused_picker(snacks_mock.make_picker(nil, "right"))
            assert.is_false(nvim.is_nvim_float())
        end)

        it("does not consult nvim_win_get_config when snacks picker is active", function()
            -- nvim would say floating, but snacks says tiled
            vim.api.nvim_win_get_config = function(_)
                return { relative = "editor" }
            end
            snacks_mock.set_focused_picker(snacks_mock.make_picker(nil, "left"))
            assert.is_false(nvim.is_nvim_float())
        end)
    end)
end)
