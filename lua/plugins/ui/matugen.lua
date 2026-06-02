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
        neo_tree         = true,
        treesitter       = true,
        cmp              = true,
        gitsigns         = true,
        which_key        = true,
        telescope        = { enabled = true },
        mini             = { enabled = true },
        notify           = true,
        noice            = true,
        dashboard        = true,
        indent_blankline = { enabled = true },
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

            -- Popup: solid so it's visible, but uses your palette
            Pmenu      = { bg = c.surface0, fg = c.text },
            PmenuSel   = { bg = c.surface1, fg = c.blue, bold = true },
            PmenuSbar  = { bg = c.surface1 },
            PmenuThumb = { bg = c.blue },

            -- CMP
            CmpItemAbbr           = { fg = c.text },
            CmpItemAbbrMatch      = { fg = c.blue, bold = true },
            CmpItemAbbrMatchFuzzy = { fg = c.blue },
            CmpItemMenu           = { fg = c.overlay1 },
            CmpDoc                = { bg = c.surface0 },
            CmpDocBorder          = { fg = c.surface1 },
            CmpItemKindFunction   = { fg = c.blue },
            CmpItemKindMethod     = { fg = c.blue },
            CmpItemKindVariable   = { fg = c.red },
            CmpItemKindConstant   = { fg = c.yellow },
            CmpItemKindClass      = { fg = c.yellow },
            CmpItemKindKeyword    = { fg = c.mauve },
            CmpItemKindSnippet    = { fg = c.green },
            CmpItemKindText       = { fg = c.subtext0 },
            CmpItemKindProperty   = { fg = c.subtext0 },
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
