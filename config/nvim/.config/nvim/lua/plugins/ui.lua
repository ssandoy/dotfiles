-- lua/plugins/ui.lua
return {
  -- Theme
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("catppuccin-macchiato")
    end,
  },

  -- Statusline
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({})
    end,
  },

  -- File tree
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = {
      "NvimTreeToggle",
      "NvimTreeOpen",
      "NvimTreeClose",
      "NvimTreeFindFile",
    },
    keys = {
      { "<M-1>", "<cmd>NvimTreeToggle<cr>", desc = "File tree" },
      { "<leader>e", "<cmd>NvimTreeToggle<cr>", desc = "File tree" },
    },
    opts = {
      update_focused_file = {
        enable = true,
      },
      view = {
        width = 30,
      },
      renderer = {
        group_empty = true,
      },
    },
  },

  -- Indentation guides
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = {},
  },

  -- Git signs in the signcolumn
  {
    "lewis6991/gitsigns.nvim",
    opts = {},
  },

  -- Git diff and history views
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Git diff view" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "Git file history" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Git repo history" },
      { "<leader>gq", "<cmd>DiffviewClose<cr>", desc = "Close diff view" },
    },
    opts = function()
      local actions = require("diffview.actions")

      return {
        keymaps = {
          view = {
            { "n", "<leader>go", actions.goto_file_edit, { desc = "Open file for editing" } },
          },
          file_panel = {
            { "n", "<leader>go", actions.goto_file_edit, { desc = "Open file for editing" } },
          },
        },
      }
    end,
  },
}
