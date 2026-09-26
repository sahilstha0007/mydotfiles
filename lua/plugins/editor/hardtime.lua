-- hardtime: good-habits trainer — blocks arrow keys and nags when you lean
-- on hjkl/visual mode unnecessarily. DISABLED by default (enabled = false):
-- it punishes habits a beginner hasn't built yet. Turn it on with
-- <leader>uh once the native motions feel natural; same key turns it off.
return {
  {
    'm4xshen/hardtime.nvim',
    dependencies = { 'MunifTanjim/nui.nvim' },
    opts = {
      enabled = false,
      restricted_keys = {
        ['h'] = false,
        ['j'] = false,
        ['k'] = false,
        ['l'] = false,
      },
    },
    keys = {
      {
        '<leader>uh',
        function()
          -- Load the plugin (if lazy hasn't yet), wait for its deferred
          -- setup, THEN toggle. Calling `:Hardtime` directly races the
          -- lazy-load: the command doesn't exist until setup() ran its
          -- 500 ms deferred timer, so the first press E492'd.
          local lazy = require('lazy.core.config').plugins['hardtime.nvim']
          if not lazy.loaded then
            require('lazy').load { plugins = { 'hardtime.nvim' } }
          end
          local ht = require('hardtime')
          vim.defer_fn(function()
            ht.toggle()
            local state = ht.is_plugin_enabled and 'ON' or 'OFF'
            vim.notify('hardtime: ' .. state, vim.log.levels.INFO)
          end, 600)
        end,
        desc = 'Toggle hardtime (good-habits trainer)',
      },
    },
  },
}
