-- Mason Configuration
-- DEV-003: Editor Configuration - Language Server Management

return {
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
    build = ":MasonUpdate",
    opts = {
      ensure_installed = {
        -- Language servers
        "lua-language-server",
        "pyright",
        "typescript-language-server",
        "gopls",
        "rust-analyzer",
        "bash-language-server",
        "json-lsp",
        "yaml-language-server",
        "dockerfile-language-server",
        "html-lsp",
        "css-lsp",
        "tailwindcss-language-server",
        "vim-language-server",
        
        -- Formatters
        "stylua",
        "prettier",
        "black",
        "isort",
        "gofumpt",
        "rustfmt",
        "shfmt",
        
        -- Linters
        "shellcheck",
        "flake8",
        "eslint_d",
        "golangci-lint",
        "markdownlint",
        "yamllint",
      },
      ui = {
        border = "rounded",
        width = 0.8,
        height = 0.8,
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
        keymaps = {
          toggle_package_expand = "<CR>",
          install_package = "i",
          update_package = "u",
          check_package_version = "c",
          update_all_packages = "U",
          check_outdated_packages = "C",
          uninstall_package = "X",
          cancel_installation = "<C-c>",
          apply_language_filter = "<C-f>",
        },
      },
      log_level = vim.log.levels.INFO,
      max_concurrent_installers = 4,
      registries = {
        "github:mason-org/mason-registry",
      },
      providers = {
        "mason.providers.registry-api",
        "mason.providers.client",
      },
    },
    config = function(_, opts)
      require("mason").setup(opts)
      local mr = require("mason-registry")
      
      -- Auto-install ensure_installed packages
      mr:on("package:install:success", function()
        vim.defer_fn(function()
          require("lazy.core.handler.event").trigger({
            event = "FileType",
            buf = vim.api.nvim_get_current_buf(),
          })
        end, 100)
      end)
      
      local function ensure_installed()
        for _, tool in ipairs(opts.ensure_installed) do
          local p = mr.get_package(tool)
          if not p:is_installed() then
            p:install()
          end
        end
      end
      
      if mr.refresh then
        mr.refresh(ensure_installed)
      else
        ensure_installed()
      end
    end,
  },

  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "lua_ls",
        "pyright",
        "tsserver",
        "gopls",
        "rust_analyzer",
        "bashls",
        "jsonls",
        "yamlls",
        "dockerls",
        "html",
        "cssls",
        "tailwindcss",
        "vimls",
      },
      automatic_installation = true,
      handlers = nil,
    },
    config = function(_, opts)
      require("mason-lspconfig").setup(opts)
    end,
  },

  {
    "jay-babu/mason-null-ls.nvim",
    dependencies = {
      "williamboman/mason.nvim",
      "nvimtools/none-ls.nvim",
    },
    opts = {
      ensure_installed = {
        "stylua",
        "prettier",
        "black",
        "isort",
        "shfmt",
        "shellcheck",
        "flake8",
        "eslint_d",
        "markdownlint",
      },
      automatic_installation = true,
      handlers = {},
    },
    config = function(_, opts)
      require("mason-null-ls").setup(opts)
    end,
  },
} 