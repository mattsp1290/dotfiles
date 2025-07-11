-- Core Neovim Options
-- DEV-003: Editor Configuration - Core Settings

-- Leader keys (must be set before lazy loading)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- General settings
local opt = vim.opt

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Indentation
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.autoindent = true
opt.smartindent = true

-- Text display
opt.wrap = false
opt.linebreak = true
opt.breakindent = true
opt.showbreak = "↪ "

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true

-- UI
opt.termguicolors = true
opt.signcolumn = "yes"
opt.colorcolumn = "80,120"
opt.cursorline = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.pumheight = 10
opt.cmdheight = 1
opt.showmode = false

-- Timing
opt.updatetime = 250
opt.timeoutlen = 300

-- Clipboard
opt.clipboard = "unnamedplus"

-- Splits
opt.splitbelow = true
opt.splitright = true

-- Files
opt.backup = false
opt.writebackup = false
opt.swapfile = false
opt.undofile = true
opt.undolevels = 10000

-- Completion
opt.completeopt = "menu,menuone,noselect"
opt.shortmess:append("c")

-- Mouse
opt.mouse = "a"

-- Folding (using treesitter)
opt.foldmethod = "expr"
opt.foldexpr = "nvim_treesitter#foldexpr()"
opt.foldenable = false
opt.foldlevel = 99

-- List chars
opt.list = true
opt.listchars = {
  tab = "→ ",
  eol = "↴",
  trail = "•",
  extends = "❯",
  precedes = "❮",
  nbsp = "␣",
}

-- Performance
opt.lazyredraw = true
opt.synmaxcol = 240
opt.redrawtime = 1500

-- Spelling (disabled by default, enable per filetype)
opt.spell = false
opt.spelllang = { "en_us" }

-- Window title
opt.title = true
opt.titlestring = "%<%F%=%l/%L - nvim"

-- Session
opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal"

-- Wild menu
opt.wildmode = "longest:full,full"
opt.wildignore:append({
  "*.o", "*.obj", "*.dylib", "*.bin", "*.dll", "*.exe",
  "*/.git/*", "*/.svn/*", "*/__pycache__/*", "*/build/*",
  "*/node_modules/*", "*/.DS_Store", "*/dist/*",
})

-- Disable builtin plugins we don't need
local disabled_built_ins = {
  "netrw",
  "netrwPlugin",
  "netrwSettings",
  "netrwFileHandlers",
  "gzip",
  "zip",
  "zipPlugin",
  "tar",
  "tarPlugin",
  "getscript",
  "getscriptPlugin",
  "vimball",
  "vimballPlugin",
  "2html_plugin",
  "logipat",
  "rrhelper",
  "spellfile_plugin",
  "matchit",
}

for _, plugin in pairs(disabled_built_ins) do
  vim.g["loaded_" .. plugin] = 1
end 