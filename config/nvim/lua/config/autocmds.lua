-- Auto Commands
-- DEV-003: Editor Configuration - Auto Commands

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Highlight on yank
autocmd("TextYankPost", {
  group = augroup("highlight_yank", { clear = true }),
  desc = "Highlight when yanking text",
  callback = function()
    vim.highlight.on_yank({ higroup = "Visual", timeout = 200 })
  end,
})

-- Remove trailing whitespace on save
autocmd("BufWritePre", {
  group = augroup("trim_whitespace", { clear = true }),
  desc = "Remove trailing whitespace on save",
  callback = function()
    local save_cursor = vim.fn.getpos(".")
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.setpos(".", save_cursor)
  end,
})

-- Auto create directories when saving
autocmd("BufWritePre", {
  group = augroup("auto_create_dirs", { clear = true }),
  desc = "Auto create parent directories when saving",
  callback = function()
    local dir = vim.fn.expand("%:p:h")
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, "p")
    end
  end,
})

-- Restore cursor position
autocmd("BufReadPost", {
  group = augroup("restore_cursor", { clear = true }),
  desc = "Restore cursor position when opening file",
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Close some filetypes with <q>
autocmd("FileType", {
  group = augroup("close_with_q", { clear = true }),
  pattern = {
    "qf",
    "help",
    "man",
    "notify",
    "lspinfo",
    "spectre_panel",
    "startuptime",
    "tsplayground",
    "PlenaryTestPopup",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = event.buf, silent = true })
  end,
})

-- Check for file changes and reload
autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  group = augroup("checktime", { clear = true }),
  desc = "Check for file changes",
  command = "checktime",
})

-- Resize splits if window got resized
autocmd("VimResized", {
  group = augroup("resize_splits", { clear = true }),
  desc = "Resize splits if window got resized",
  callback = function()
    vim.cmd("tabdo wincmd =")
  end,
})

-- Spell checking for text files
autocmd("FileType", {
  group = augroup("spell_check", { clear = true }),
  pattern = { "gitcommit", "markdown", "text", "tex" },
  callback = function()
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en_us"
  end,
})

-- Set wrap and spell for text files
autocmd("FileType", {
  group = augroup("text_files", { clear = true }),
  pattern = { "markdown", "text", "tex", "gitcommit" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
  end,
})

-- Fix conceallevel for json files
autocmd("FileType", {
  group = augroup("json_conceal", { clear = true }),
  pattern = { "json", "jsonc", "json5" },
  callback = function()
    vim.opt_local.conceallevel = 0
  end,
})

-- Terminal settings
autocmd("TermOpen", {
  group = augroup("terminal_setup", { clear = true }),
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.scrolloff = 0
    vim.cmd("startinsert")
  end,
})

-- Auto insert mode for terminal
autocmd("BufEnter", {
  group = augroup("terminal_enter", { clear = true }),
  pattern = "term://*",
  command = "startinsert",
})

-- Set filetype for specific files
autocmd({ "BufRead", "BufNewFile" }, {
  group = augroup("set_filetypes", { clear = true }),
  pattern = {
    ["*.conf"] = "conf",
    ["*.env"] = "sh",
    ["Dockerfile*"] = "dockerfile",
    ["*.dockerignore"] = "conf",
    [".gitignore"] = "conf",
    [".gitattributes"] = "conf",
    ["*.zsh"] = "zsh",
    ["*.fish"] = "fish",
  },
  callback = function(args)
    for pattern, filetype in pairs({
      ["%.conf$"] = "conf",
      ["%.env$"] = "sh",
      ["Dockerfile.*"] = "dockerfile",
      ["%.dockerignore$"] = "conf",
      ["%.gitignore$"] = "conf",
      ["%.gitattributes$"] = "conf",
      ["%.zsh$"] = "zsh",
      ["%.fish$"] = "fish",
    }) do
      if string.match(args.file, pattern) then
        vim.bo[args.buf].filetype = filetype
        break
      end
    end
  end,
})

-- Language-specific settings
autocmd("FileType", {
  group = augroup("language_settings", { clear = true }),
  pattern = "python",
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.expandtab = true
  end,
})

autocmd("FileType", {
  group = augroup("go_settings", { clear = true }),
  pattern = "go",
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.expandtab = false
  end,
})

autocmd("FileType", {
  group = augroup("make_settings", { clear = true }),
  pattern = "make",
  callback = function()
    vim.opt_local.expandtab = false
  end,
})

-- Auto-format certain files on save
autocmd("BufWritePre", {
  group = augroup("auto_format", { clear = true }),
  pattern = { "*.lua", "*.py", "*.js", "*.ts", "*.jsx", "*.tsx", "*.rs" },
  callback = function()
    -- Only format if formatter is available
    if vim.lsp.buf.format then
      vim.lsp.buf.format({ async = false })
    end
  end,
})

-- Show diagnostics on cursor hold
autocmd("CursorHold", {
  group = augroup("show_diagnostics", { clear = true }),
  desc = "Show diagnostics on cursor hold",
  callback = function()
    vim.diagnostic.open_float(nil, { focusable = false })
  end,
})

-- Update the status line
autocmd({ "WinEnter", "BufEnter", "InsertLeave" }, {
  group = augroup("update_statusline", { clear = true }),
  desc = "Update status line",
  callback = function()
    vim.cmd("redrawstatus")
  end,
})

-- Large file detection and optimization
autocmd("BufReadPre", {
  group = augroup("large_file", { clear = true }),
  callback = function(args)
    local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(args.buf))
    if ok and stats and stats.size > 1024 * 1024 then -- 1MB
      vim.b[args.buf].large_file = true
      vim.opt_local.syntax = ""
      vim.opt_local.foldmethod = "manual"
      vim.opt_local.undolevels = -1
      vim.opt_local.undoreload = 0
      vim.opt_local.list = false
    end
  end,
})

-- Plugin lazy loading helpers
autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    -- Load additional plugins that should be loaded after UI
  end,
}) 