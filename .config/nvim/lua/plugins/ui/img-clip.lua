-- img-clip.nvim: paste images from the clipboard straight into a file as
-- markdown/HTML — embeds the image into a path next to the note and inserts
-- the reference. This is the missing half of the kitty graphics story: kitty
-- can *display* images (kitten icat), and this lets you *paste* them into the
-- Obsidian-markdown notes you edit here. Lazy-loads on markdown so it costs
-- nothing until you're in a note.
--
-- Paste key: <leader>ip (normal mode, avoiding collision with Octo <leader>p* prefix).
return {
  {
    'HakonHarnes/img-clip.nvim',
    ft = { 'markdown' },
    opts = {
      default = {
        -- embed images relative to the current file, in an assets/ subfolder
        dir_path = 'assets',
        use_absolute_path = false,
        relative_to_current_file = true,
        prompt_for_file_name = false,
        file_name = '%Y-%m-%d-%H-%M-%S',
      },
    },
    keys = {
      {
        '<leader>ip',
        '<cmd>PasteImage<cr>',
        desc = 'Paste image from clipboard',
        ft = 'markdown',
      },
    },
  },
}
