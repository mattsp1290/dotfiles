-- LSP Server Configurations
-- DEV-003: Editor Configuration - Language Server Setup

local lsp_config = require("lspconfig")
local lsp_utils = require("lsp")

-- Enhanced capabilities with nvim-cmp
local capabilities = vim.lsp.protocol.make_client_capabilities()
local has_cmp, cmp_lsp = pcall(require, "cmp_nvim_lsp")
if has_cmp then
  capabilities = cmp_lsp.default_capabilities(capabilities)
end

-- Common LSP settings
local common_settings = {
  on_attach = lsp_utils.on_attach,
  capabilities = capabilities,
  flags = {
    debounce_text_changes = 150,
  },
}

-- Lua Language Server
lsp_config.lua_ls.setup(vim.tbl_deep_extend("force", common_settings, {
  settings = {
    Lua = {
      runtime = {
        version = "LuaJIT",
      },
      diagnostics = {
        globals = { "vim" },
      },
      workspace = {
        library = vim.api.nvim_get_runtime_file("", true),
        checkThirdParty = false,
      },
      telemetry = {
        enable = false,
      },
      hint = {
        enable = true,
      },
      completion = {
        callSnippet = "Replace",
      },
    },
  },
}))

-- Python Language Server
lsp_config.pyright.setup(vim.tbl_deep_extend("force", common_settings, {
  settings = {
    python = {
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "workspace",
        typeCheckingMode = "basic",
      },
    },
  },
}))

-- TypeScript/JavaScript Language Server
lsp_config.tsserver.setup(vim.tbl_deep_extend("force", common_settings, {
  settings = {
    typescript = {
      inlayHints = {
        includeInlayParameterNameHints = "all",
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayVariableTypeHints = true,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
      },
    },
    javascript = {
      inlayHints = {
        includeInlayParameterNameHints = "all",
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayVariableTypeHints = true,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
      },
    },
  },
}))

-- Go Language Server
lsp_config.gopls.setup(vim.tbl_deep_extend("force", common_settings, {
  settings = {
    gopls = {
      analyses = {
        unusedparams = true,
      },
      staticcheck = true,
      gofumpt = true,
      hints = {
        assignVariableTypes = true,
        compositeLiteralFields = true,
        compositeLiteralTypes = true,
        constantValues = true,
        functionTypeParameters = true,
        parameterNames = true,
        rangeVariableTypes = true,
      },
    },
  },
}))

-- Rust Language Server
lsp_config.rust_analyzer.setup(vim.tbl_deep_extend("force", common_settings, {
  settings = {
    ["rust-analyzer"] = {
      cargo = {
        allFeatures = true,
        loadOutDirsFromCheck = true,
        runBuildScripts = true,
      },
      checkOnSave = {
        allFeatures = true,
        command = "clippy",
        extraArgs = { "--no-deps" },
      },
      procMacro = {
        enable = true,
        ignored = {
          ["async-trait"] = { "async_trait" },
          ["napi-derive"] = { "napi" },
          ["async-recursion"] = { "async_recursion" },
        },
      },
      inlayHints = {
        bindingModeHints = {
          enable = false,
        },
        chainingHints = {
          enable = true,
        },
        closingBraceHints = {
          enable = true,
          minLines = 25,
        },
        closureReturnTypeHints = {
          enable = "never",
        },
        lifetimeElisionHints = {
          enable = "never",
          useParameterNames = false,
        },
        maxLength = 25,
        parameterHints = {
          enable = true,
        },
        reborrowHints = {
          enable = "never",
        },
        renderColons = true,
        typeHints = {
          enable = true,
          hideClosureInitialization = false,
          hideNamedConstructor = false,
        },
      },
    },
  },
}))

-- Bash Language Server
lsp_config.bashls.setup(common_settings)

-- JSON Language Server
lsp_config.jsonls.setup(vim.tbl_deep_extend("force", common_settings, {
  settings = {
    json = {
      schemas = require("schemastore").json.schemas(),
      validate = { enable = true },
    },
  },
}))

-- YAML Language Server
lsp_config.yamlls.setup(vim.tbl_deep_extend("force", common_settings, {
  settings = {
    yaml = {
      schemaStore = {
        enable = false,
        url = "",
      },
      schemas = require("schemastore").yaml.schemas(),
      keyOrdering = false,
    },
  },
}))

-- HTML Language Server
lsp_config.html.setup(vim.tbl_deep_extend("force", common_settings, {
  filetypes = { "html", "templ" },
}))

-- CSS Language Server
lsp_config.cssls.setup(common_settings)

-- Tailwind CSS Language Server
lsp_config.tailwindcss.setup(vim.tbl_deep_extend("force", common_settings, {
  filetypes = {
    "html",
    "css",
    "scss",
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "vue",
    "svelte",
  },
}))

-- Docker Language Server
lsp_config.dockerls.setup(common_settings)

-- Vim Language Server
lsp_config.vimls.setup(common_settings)

-- Additional language servers can be added here
-- Each server should follow the pattern above with appropriate settings

-- Global LSP settings
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
  border = "rounded",
})

vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
  border = "rounded",
})

-- Auto-start LSP servers based on file type
local group = vim.api.nvim_create_augroup("LSPStart", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "*",
  callback = function()
    local filetype = vim.bo.filetype
    local clients = vim.lsp.get_active_clients({ bufnr = 0 })
    
    if #clients == 0 and filetype ~= "" then
      vim.schedule(function()
        vim.cmd("LspStart")
      end)
    end
  end,
}) 