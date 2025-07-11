-- Formatting and Linting Configuration
-- DEV-003: Editor Configuration - Code Formatting and Linting

return {
  {
    "nvimtools/none-ls.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "jay-babu/mason-null-ls.nvim",
    },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local null_ls = require("null-ls")
      local formatting = null_ls.builtins.formatting
      local diagnostics = null_ls.builtins.diagnostics
      local code_actions = null_ls.builtins.code_actions

      null_ls.setup({
        debug = false,
        sources = {
          -- Lua
          formatting.stylua.with({
            extra_args = { "--config-path", vim.fn.expand("~/.stylua.toml") },
          }),

          -- Python
          formatting.black.with({
            extra_args = { "--fast" },
          }),
          formatting.isort,
          diagnostics.flake8.with({
            extra_args = { "--max-line-length=88", "--extend-ignore=E203" },
          }),

          -- JavaScript/TypeScript
          formatting.prettier.with({
            extra_args = { "--single-quote", "--jsx-single-quote" },
            filetypes = {
              "javascript",
              "javascriptreact",
              "typescript",
              "typescriptreact",
              "vue",
              "css",
              "scss",
              "less",
              "html",
              "json",
              "jsonc",
              "yaml",
              "markdown",
              "markdown.mdx",
              "graphql",
              "handlebars",
            },
          }),
          diagnostics.eslint_d.with({
            condition = function(utils)
              return utils.root_has_file({
                ".eslintrc.js",
                ".eslintrc.cjs",
                ".eslintrc.yaml",
                ".eslintrc.yml",
                ".eslintrc.json",
                "eslint.config.js",
              })
            end,
          }),

          -- Go
          formatting.gofumpt,
          formatting.goimports,
          diagnostics.golangci_lint,

          -- Rust
          formatting.rustfmt,

          -- Shell
          formatting.shfmt.with({
            extra_args = { "-i", "2", "-ci" },
          }),
          diagnostics.shellcheck.with({
            diagnostics_format = "#{m} [#{c}]",
          }),

          -- JSON
          formatting.jq,

          -- YAML
          diagnostics.yamllint,

          -- Markdown
          diagnostics.markdownlint,

          -- Git
          code_actions.gitrebase,
          code_actions.gitsigns,

          -- Spell checking
          diagnostics.codespell.with({
            args = { "--builtin", "clear,rare,code", "-" },
          }),
        },
        on_attach = function(client, bufnr)
          -- Format on save
          if client.supports_method("textDocument/formatting") then
            local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
            vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
            vim.api.nvim_create_autocmd("BufWritePre", {
              group = augroup,
              buffer = bufnr,
              callback = function()
                vim.lsp.buf.format({
                  filter = function(client)
                    return client.name == "null-ls"
                  end,
                  bufnr = bufnr,
                })
              end,
            })
          end
        end,
      })
    end,
  },

  -- Schema store for JSON/YAML
  {
    "b0o/schemastore.nvim",
    lazy = true,
    version = false,
  },
} 