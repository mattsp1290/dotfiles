-- LSP Diagnostics Configuration
-- DEV-003: Editor Configuration - Diagnostics Display

-- Configure diagnostic signs
local signs = {
  { name = "DiagnosticSignError", text = "" },
  { name = "DiagnosticSignWarn", text = "" },
  { name = "DiagnosticSignHint", text = "" },
  { name = "DiagnosticSignInfo", text = "" },
}

for _, sign in ipairs(signs) do
  vim.fn.sign_define(sign.name, { texthl = sign.name, text = sign.text, numhl = "" })
end

-- Configure diagnostics
vim.diagnostic.config({
  virtual_text = {
    enabled = true,
    source = "if_many",
    prefix = "●",
    format = function(diagnostic)
      local message = diagnostic.message
      if diagnostic.source then
        message = string.format("%s [%s]", message, diagnostic.source)
      end
      return message
    end,
  },
  signs = {
    active = signs,
  },
  update_in_insert = false,
  underline = true,
  severity_sort = true,
  float = {
    focusable = false,
    style = "minimal",
    border = "rounded",
    source = "always",
    header = "",
    prefix = "",
    format = function(diagnostic)
      local code = diagnostic.code or diagnostic.user_data and diagnostic.user_data.lsp.code
      if code then
        return string.format("%s [%s]", diagnostic.message, code)
      end
      return diagnostic.message
    end,
  },
})

-- Automatically show diagnostics on cursor hold
local diagnostic_hover_augroup = vim.api.nvim_create_augroup("DiagnosticHover", { clear = true })
vim.api.nvim_create_autocmd("CursorHold", {
  group = diagnostic_hover_augroup,
  pattern = "*",
  callback = function()
    vim.diagnostic.open_float({
      scope = "cursor",
      focusable = false,
      close_events = {
        "CursorMoved",
        "CursorMovedI",
        "BufHidden",
        "InsertCharPre",
        "WinLeave",
      },
    })
  end,
})

-- Highlight line numbers in sign column for diagnostics
local hl_group = vim.api.nvim_create_augroup("DiagnosticLineNrHighlight", { clear = true })
vim.api.nvim_create_autocmd("DiagnosticChanged", {
  group = hl_group,
  callback = function()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        local diagnostics = vim.diagnostic.get(bufnr)
        for _, diagnostic in ipairs(diagnostics) do
          local lnum = diagnostic.lnum
          local severity = diagnostic.severity
          
          local hl_group_name
          if severity == vim.diagnostic.severity.ERROR then
            hl_group_name = "DiagnosticLineNrError"
          elseif severity == vim.diagnostic.severity.WARN then
            hl_group_name = "DiagnosticLineNrWarn"
          elseif severity == vim.diagnostic.severity.INFO then
            hl_group_name = "DiagnosticLineNrInfo"
          elseif severity == vim.diagnostic.severity.HINT then
            hl_group_name = "DiagnosticLineNrHint"
          end
          
          if hl_group_name then
            vim.api.nvim_buf_set_extmark(bufnr, vim.api.nvim_create_namespace("diagnostic_line_nr"), lnum, 0, {
              line_hl_group = hl_group_name,
              priority = 100,
            })
          end
        end
      end
    end
  end,
})

-- Custom diagnostic functions
local M = {}

-- Toggle virtual text diagnostics
M.toggle_virtual_text = function()
  local current_setting = vim.diagnostic.config().virtual_text
  vim.diagnostic.config({
    virtual_text = not current_setting.enabled and {
      enabled = true,
      source = "if_many",
      prefix = "●",
    } or { enabled = false },
  })
  
  local status = vim.diagnostic.config().virtual_text.enabled and "enabled" or "disabled"
  vim.notify("Diagnostic virtual text " .. status, vim.log.levels.INFO)
end

-- Go to next diagnostic with specific severity
M.goto_next = function(severity)
  vim.diagnostic.goto_next({
    severity = severity,
    float = true,
  })
end

-- Go to previous diagnostic with specific severity
M.goto_prev = function(severity)
  vim.diagnostic.goto_prev({
    severity = severity,
    float = true,
  })
end

-- Show diagnostics in location list
M.set_loclist = function()
  vim.diagnostic.setloclist()
end

-- Show diagnostics in quickfix list
M.set_qflist = function()
  vim.diagnostic.setqflist()
end

-- Count diagnostics by severity
M.count_diagnostics = function()
  local diagnostics = vim.diagnostic.get(0)
  local count = { errors = 0, warnings = 0, info = 0, hints = 0 }
  
  for _, diagnostic in ipairs(diagnostics) do
    if diagnostic.severity == vim.diagnostic.severity.ERROR then
      count.errors = count.errors + 1
    elseif diagnostic.severity == vim.diagnostic.severity.WARN then
      count.warnings = count.warnings + 1
    elseif diagnostic.severity == vim.diagnostic.severity.INFO then
      count.info = count.info + 1
    elseif diagnostic.severity == vim.diagnostic.severity.HINT then
      count.hints = count.hints + 1
    end
  end
  
  return count
end

-- Custom keymaps for diagnostic navigation
vim.keymap.set("n", "<leader>dt", M.toggle_virtual_text, { desc = "Toggle diagnostic virtual text" })
vim.keymap.set("n", "[e", function() M.goto_prev(vim.diagnostic.severity.ERROR) end, { desc = "Previous error" })
vim.keymap.set("n", "]e", function() M.goto_next(vim.diagnostic.severity.ERROR) end, { desc = "Next error" })
vim.keymap.set("n", "[w", function() M.goto_prev(vim.diagnostic.severity.WARN) end, { desc = "Previous warning" })
vim.keymap.set("n", "]w", function() M.goto_next(vim.diagnostic.severity.WARN) end, { desc = "Next warning" })

return M 