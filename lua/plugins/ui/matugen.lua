-- ML4W matugen color palette (from colors-matugen.conf)
local bg       = "#0f1416"  -- your exact terminal background
local bg2      = "#1d343a"  -- selection bg / slightly lighter
local fg       = "#dee3e5"  -- foreground
local cyan     = "#84d2e6"  -- color4 / url_color (main accent)
local cyan2    = "#9ec3c4"  -- color14
local red      = "#ffb4ab"  -- color1
local green    = "#9ec49f"  -- color10
local yellow   = "#c4c19e"  -- color11
local magenta  = "#c49ec4"  -- color13
local muted    = "#4c4c4c"  -- color0
local white    = "#f0f0f0"  -- color7
local overlay  = "#aca98a"  -- color3 (warm muted)

return {
  {
    -- Use a base theme then override everything with matugen colors
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      flavour = "mocha",
      transparent_background = true, -- let kitty's 0.7 opacity show through
      color_overrides = {
        mocha = {
          base    = bg,
          mantle  = bg,
          crust   = bg,
          surface0 = bg2,
          surface1 = "#243e45",
          surface2 = "#2e4e56",
          overlay0 = muted,
          overlay1 = overlay,
          overlay2 = "#9ca8a8",
          text     = fg,
          subtext0 = cyan2,
          subtext1 = white,
          blue     = cyan,
          lavender = cyan2,
          sapphire = cyan2,
          sky      = cyan,
          teal     = cyan2,
          green    = green,
          yellow   = yellow,
          peach    = yellow,
          red      = red,
          maroon   = red,
          mauve    = magenta,
          pink     = magenta,
          flamingo = red,
          rosewater = white,
        },
      },
      integrations = {
        neo_tree           = true,
        treesitter         = true,
        blink_cmp          = true, -- completion (was `cmp` — dead, nvim-cmp isn't used)
        gitsigns           = true,
        which_key          = true,
        telescope          = { enabled = true },
        mini               = { enabled = true },
        snacks             = true, -- picker + dashboard
        lsp_trouble        = true, -- trouble.nvim
        treesitter_context = true, -- pinned function/class context
        ufo                = true, -- folding
        flash              = true, -- flash jump labels
      },
      highlight_overrides = {
        mocha = function(c)
          return {
            -- Explorer blends with terminal
            NeoTreeNormal        = { bg = "NONE", fg = c.text },
            NeoTreeNormalNC      = { bg = "NONE" },
            NeoTreeEndOfBuffer   = { bg = "NONE" },
            NeoTreeWinSeparator  = { fg = c.surface1, bg = "NONE" },
            NeoTreeRootName      = { fg = c.blue, bold = true },
            NeoTreeDirectoryName = { fg = c.blue },
            NeoTreeDirectoryIcon = { fg = c.blue },
            NeoTreeFileName      = { fg = c.text },
            NeoTreeFileIcon      = { fg = c.subtext0 },
            NeoTreeGitAdded      = { fg = c.green },
            NeoTreeGitModified   = { fg = c.yellow },
            NeoTreeGitUntracked  = { fg = c.mauve },
            NeoTreeIndentMarker  = { fg = c.overlay0 },

            -- Popup: frosted — winblend/pumblend (options.lua) blend these
            -- toward the wallpaper, so the tint + blend reads as glass.
            Pmenu      = { bg = c.surface0, fg = c.text },
            PmenuSel   = { bg = c.surface1, fg = c.blue, bold = true },
            PmenuSbar  = { bg = c.surface1 },
            PmenuThumb = { bg = c.blue },

            -- blink.cmp (same palette intent as the old nvim-cmp Cmp* block,
            -- which blink.cmp ignores)
            BlinkCmpLabel         = { fg = c.text },
            BlinkCmpLabelMatch    = { fg = c.blue, bold = true },
            BlinkCmpLabelDetail   = { fg = c.overlay1 },
            BlinkCmpMenuBorder    = { fg = c.surface1 },
            BlinkCmpMenuSelection = { bg = c.surface1, fg = c.blue, bold = true },
            BlinkCmpDoc           = { bg = c.surface0 },
            BlinkCmpDocBorder     = { fg = c.surface1 },
            BlinkCmpGhostText     = { fg = c.overlay0 },
            BlinkCmpKindFunction  = { fg = c.blue },
            BlinkCmpKindMethod    = { fg = c.blue },
            BlinkCmpKindVariable  = { fg = c.red },
            BlinkCmpKindConstant  = { fg = c.yellow },
            BlinkCmpKindClass     = { fg = c.yellow },
            BlinkCmpKindKeyword   = { fg = c.mauve },
            BlinkCmpKindSnippet   = { fg = c.green },
            BlinkCmpKindText      = { fg = c.subtext0 },
            BlinkCmpKindProperty  = { fg = c.subtext0 },

            -- contrast polish for the dim palette
            Search      = { bg = c.blue, fg = c.base }, -- cyan search highlight
            Visual      = { bg = c.surface1 },            -- clearer selection
            MatchParen  = { bg = c.surface1, fg = c.blue, bold = true },
            WinSeparator = { fg = c.surface1 },           -- visible split borders

            -- Floating windows (hover, diagnostics popup, dressing): frosted
            -- glass — tinted body + a slightly lighter border so the rounded
            -- edges read against the transparent editor. winblend=25 (from
            -- options.lua) does the see-through; these are the tint layers.
            FloatBorder = { fg = c.surface2 },
            NormalFloat = { bg = c.surface0, fg = c.text },

          }
        end,
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "catppuccin-mocha" },
  },
}
