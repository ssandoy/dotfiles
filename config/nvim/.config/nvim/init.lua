vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require("config.lazy")

-- Basic UI
vim.opt.number = true                 -- show line numbers
vim.opt.relativenumber = true         -- relative line numbers
vim.cmd('syntax on')                  -- syntax highlighting
vim.opt.termguicolors = true          -- true color support
vim.opt.mouse = 'a'                   -- allow mouse scrolling/clicking
vim.opt.cursorline = true             -- highlight current line
vim.opt.tabstop = 4                   -- number of spaces tabs count for
vim.opt.shiftwidth = 4                -- number of spaces to use for each step of (auto)indent
vim.opt.expandtab = true              -- use spaces instead of tabs
vim.opt.clipboard = 'unnamedplus'     -- use system clipboard

-- Optional: better searching
vim.opt.ignorecase = true             -- case-insensitive search
vim.opt.smartcase = true              -- but case-sensitive if uppercase letters are used
vim.opt.incsearch = true              -- show matches as you type

-- Optional: keep 8 lines visible above/below cursor
vim.opt.scrolloff = 8

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  callback = function(args)
    local buftype = vim.bo[args.buf].buftype
    if buftype == "" and not vim.bo[args.buf].modifiable then
      vim.bo[args.buf].modifiable = true
    end
  end,
})

vim.api.nvim_create_autocmd({ "FocusLost", "BufLeave" }, {
  callback = function(args)
    local buf = args.buf
    if vim.bo[buf].buftype ~= "" or vim.bo[buf].readonly or not vim.bo[buf].modifiable or not vim.bo[buf].modified then
      return
    end

    if vim.api.nvim_buf_get_name(buf) == "" then
      return
    end

    vim.api.nvim_buf_call(buf, function()
      vim.cmd("silent! write")
    end)
  end,
})
