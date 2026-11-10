std = 'luajit'

-- Neovim specs run inside `nvim --headless` where `_G.vim` is built-in.
files['nvim/**'] = {
   globals = { 'vim' },
}
