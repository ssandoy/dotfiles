return {
  {
    "mason-org/mason.nvim",
    cmd = {
      "Mason",
      "MasonInstall",
      "MasonUninstall",
      "MasonUpdate",
      "MasonLog",
    },
    keys = {
      { "<leader>pm", "<cmd>Mason<cr>", desc = "Package manager (Mason)" },
    },
    opts = {},
  },

  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = {
      { "mason-org/mason.nvim", opts = {} },
      "neovim/nvim-lspconfig",
    },
    opts = {
      ensure_installed = {
        "ts_ls",
        "kotlin_language_server",
      },
      automatic_enable = false,
    },
  },

  {
    "neovim/nvim-lspconfig",
    lazy = false,
    dependencies = {
      { "ms-jpq/coq_nvim", branch = "coq" },
      { "ms-jpq/coq.artifacts", branch = "artifacts" },
    },
    init = function()
      vim.g.coq_settings = {
        auto_start = "shut-up",
      }
    end,
    config = function()
      local coq = require("coq")

      vim.diagnostic.config({
        severity_sort = true,
        virtual_text = true,
        float = {
          border = "rounded",
        },
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local bufnr = args.buf
          local map = function(lhs, rhs, desc)
            vim.keymap.set("n", lhs, rhs, {
              buffer = bufnr,
              silent = true,
              desc = desc,
            })
          end

          map("gd", vim.lsp.buf.definition, "Go to definition")
          map("gD", vim.lsp.buf.declaration, "Go to declaration")
          map("gt", vim.lsp.buf.type_definition, "Go to type definition")
          map("gr", vim.lsp.buf.references, "List references")
          map("gi", vim.lsp.buf.implementation, "Go to implementation")
          map("K", vim.lsp.buf.hover, "Hover")
          map("<leader>jd", vim.lsp.buf.definition, "Jump to definition")
          map("<leader>jD", vim.lsp.buf.declaration, "Jump to declaration")
          map("<leader>jr", vim.lsp.buf.references, "Jump to references")
          map("<leader>jb", "<C-o>", "Jump back")
          map("<leader>jf", "<C-i>", "Jump forward")
          map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("<leader>lf", vim.diagnostic.open_float, "Line diagnostics")
          map("<leader>ln", vim.diagnostic.goto_next, "Next diagnostic")
          map("<leader>lp", vim.diagnostic.goto_prev, "Previous diagnostic")
        end,
      })

      vim.lsp.config("ts_ls", coq.lsp_ensure_capabilities({}))
      vim.lsp.config("kotlin_language_server", coq.lsp_ensure_capabilities({
        root_markers = {
          "settings.gradle.kts",
          "settings.gradle",
          "build.gradle.kts",
          "build.gradle",
          "pom.xml",
          ".git",
        },
        workspace_required = true,
        handlers = {
          ["window/showMessage"] = function(err, result, ctx, config)
            if result and result.type and result.type > 1 then
              return
            end
            return vim.lsp.handlers["window/showMessage"](err, result, ctx, config)
          end,
          ["window/logMessage"] = function(err, result, ctx, config)
            if result and result.type and result.type > 1 then
              return
            end
            return vim.lsp.handlers["window/logMessage"](err, result, ctx, config)
          end,
        },
      }))

      vim.lsp.enable("ts_ls")
      vim.lsp.enable("kotlin_language_server")
    end,
  },
}
