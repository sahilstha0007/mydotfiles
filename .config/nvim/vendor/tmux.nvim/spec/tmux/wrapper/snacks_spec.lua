---@diagnostic disable: duplicate-set-field
describe("snacks wrapper", function()
    local snacks
    local snacks_mock

    setup(function()
        require("spec.tmux.mocks.log_mock").setup()
        snacks_mock = require("spec.tmux.mocks.snacks_mock")
        snacks_mock.setup()
        snacks = require("tmux.wrapper.snacks")
    end)

    before_each(function()
        _G.Snacks = nil
    end)

    describe("using_snacks", function()
        it("returns false when Snacks global is absent", function()
            assert.is_false(snacks.using_snacks())
        end)

        it("returns true when Snacks global is present", function()
            _G.Snacks = {}
            assert.is_true(snacks.using_snacks())
        end)
    end)

    describe("focused_picker", function()
        it("returns nil when snacks is not loaded", function()
            assert.is_nil(snacks.focused_picker())
        end)

        it("returns nil when no picker is focused", function()
            snacks_mock.set_focused_picker({
                is_focused = function()
                    return false
                end,
            })
            -- override get to return two unfocused pickers
            _G.Snacks.picker.get = function()
                return {
                    {
                        is_focused = function()
                            return false
                        end,
                    },
                    {
                        is_focused = function()
                            return false
                        end,
                    },
                }
            end
            assert.is_nil(snacks.focused_picker())
        end)

        it("returns the focused picker", function()
            local focused = {
                is_focused = function()
                    return true
                end,
            }
            snacks_mock.set_focused_picker(focused)
            assert.are.equal(focused, snacks.focused_picker())
        end)

        it("returns the first focused picker when multiple report focused", function()
            local first = {
                is_focused = function()
                    return true
                end,
            }
            local second = {
                is_focused = function()
                    return true
                end,
            }
            _G.Snacks = {
                picker = {
                    get = function()
                        return { first, second }
                    end,
                },
            }
            assert.are.equal(first, snacks.focused_picker())
        end)
    end)

    describe("is_float", function()
        it("returns true for nil picker", function()
            assert.is_true(snacks.is_float(nil))
        end)

        it("returns true when picker has no layout", function()
            assert.is_true(snacks.is_float({}))
        end)

        it("returns true when picker layout has no split key", function()
            assert.is_true(snacks.is_float({ layout = {} }))
        end)

        it("returns false when picker layout.split is set (tiled window)", function()
            assert.is_false(snacks.is_float({ layout = { split = "right" } }))
        end)

        it("returns false when picker layout.split is true", function()
            assert.is_false(snacks.is_float({ layout = { split = true } }))
        end)
    end)

    describe("position", function()
        it("returns nil for nil picker", function()
            assert.is_nil(snacks.position(nil))
        end)

        it("returns nil when picker has no layout", function()
            assert.is_nil(snacks.position({}))
        end)

        it("returns nil when picker layout has no root", function()
            assert.is_nil(snacks.position({ layout = {} }))
        end)

        it("returns nil when picker layout.root has no opts", function()
            assert.is_nil(snacks.position({ layout = { root = {} } }))
        end)

        it("returns nil when position is nil in opts", function()
            assert.is_nil(snacks.position({ layout = { root = { opts = {} } } }))
        end)

        it("maps 'left' to 'h'", function()
            local picker = { layout = { root = { opts = { position = "left" } } } }
            assert.are.same("h", snacks.position(picker))
        end)

        it("maps 'right' to 'l'", function()
            local picker = { layout = { root = { opts = { position = "right" } } } }
            assert.are.same("l", snacks.position(picker))
        end)

        it("maps 'top' to 'k'", function()
            local picker = { layout = { root = { opts = { position = "top" } } } }
            assert.are.same("k", snacks.position(picker))
        end)

        it("maps 'bottom' to 'j'", function()
            local picker = { layout = { root = { opts = { position = "bottom" } } } }
            assert.are.same("j", snacks.position(picker))
        end)

        it("passes through unknown position strings unchanged", function()
            local picker = { layout = { root = { opts = { position = "center" } } } }
            assert.are.same("center", snacks.position(picker))
        end)
    end)
end)
