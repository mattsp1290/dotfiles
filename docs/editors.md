# Editor Configuration Guide

A comprehensive guide to the integrated editor configuration system that provides consistent development environments across Neovim, VS Code, and terminal-based workflows with unified theming, shared settings, and seamless tool integration.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Neovim Configuration](#neovim-configuration)
- [VS Code Configuration](#vs-code-configuration)
- [Terminal Integration](#terminal-integration)
- [Theme System](#theme-system)
- [Language Support](#language-support)
- [Customization](#customization)
- [Performance Optimization](#performance-optimization)
- [Troubleshooting](#troubleshooting)
- [Migration Guide](#migration-guide)
- [Advanced Usage](#advanced-usage)
- [Reference](#reference)

## Overview

The editor configuration system provides a unified development environment across multiple editors with consistent theming, shared keybindings, and seamless integration with the broader dotfiles ecosystem. Whether you prefer terminal-based editing with Neovim or GUI-based development with VS Code, the system ensures a cohesive experience.

### Key Features

- **🎨 Unified Theming**: Catppuccin Mocha color scheme across all editors and terminals
- **⚡ High Performance**: Optimized configurations for fast startup and responsive editing
- **🔧 Modular Design**: Component-based configuration for easy customization
- **🌍 Cross-Platform**: Consistent experience on macOS, Linux, and Windows (WSL)
- **🔗 Tool Integration**: Deep integration with Git, LSP, formatters, and debuggers
- **📦 Plugin Management**: Automated plugin installation and updates

### Supported Editors

| Editor | Support Level | Features |
|--------|---------------|----------|
| **Neovim** | Full | Complete Lua configuration, LSP, treesitter, plugins |
| **VS Code** | Full | Settings sync, extensions, keybindings, themes |
| **Vim** | Compatible | Basic configuration fallback |
| **Terminal Editors** | Integrated | Nano, micro with consistent theming |

## Architecture

### Configuration Structure

```
config/
├── nvim/                      # Neovim configuration
│   ├── init.lua              # Main Neovim entry point
│   └── lua/                  # Lua configuration modules
│       ├── core/             # Core Neovim settings
│       ├── plugins/          # Plugin configurations
│       ├── themes/           # Theme definitions
│       └── utils/            # Utility functions
├── Code/                     # VS Code configuration
│   └── User/                 # VS Code user settings
│       ├── settings.json     # Main settings
│       ├── keybindings.json  # Custom keybindings
│       └── snippets/         # Code snippets
└── terminals/                # Terminal editor configs
    ├── alacritty.yml         # Alacritty terminal config
    └── kitty.conf            # Kitty terminal config

home/
├── .vimrc                    # Vim fallback configuration
└── .editorconfig            # Universal editor configuration

themes/
└── editors/                  # Shared theme definitions
    ├── catppuccin-mocha.lua  # Neovim theme
    ├── catppuccin-mocha.json # VS Code theme
    └── base16-colors.yml     # Universal color definitions
```

### Integration Points

- **Shell Integration**: Editor commands and aliases in shell configuration
- **Git Integration**: Merge tools, diff tools, and commit message editing
- **Terminal Integration**: Consistent theming across editors and terminals
- **Language Tools**: LSP servers, formatters, linters shared across editors

## Quick Start

### Installation

```bash
# Via bootstrap (recommended)
./scripts/bootstrap.sh

# Editor configuration only
./scripts/setup-editors.sh

# Terminal configuration (required for consistent theming)
./scripts/setup-terminals.sh
```

### Initial Setup

```bash
# Install editor dependencies
./scripts/install-editor-deps.sh

# Configure language servers
./scripts/setup-lsp.sh

# Verify installation
nvim --version
code --version
```

### Immediate Benefits

After installation, you'll have:

- ✅ **Consistent Theming**: Catppuccin Mocha across all editors and terminals
- ✅ **Language Support**: LSP servers for 15+ programming languages
- ✅ **Smart Completion**: Intelligent autocompletion and suggestions
- ✅ **Git Integration**: Built-in Git workflow tools and visual diff
- ✅ **Performance Optimization**: Fast startup and responsive editing
- ✅ **Unified Keybindings**: Consistent shortcuts across environments

### Quick Verification

```bash
# Test Neovim
nvim +checkhealth +quit

# Test VS Code
code --list-extensions

# Test terminal integration
echo $EDITOR                  # Should show preferred editor
```

## Neovim Configuration

### Core Configuration Structure

#### init.lua - Main Entry Point
```lua
-- init.lua: Bootstrap Neovim configuration
require('core.options')       -- Basic Neovim options
require('core.keymaps')       -- Key mappings
require('core.autocmds')      -- Auto commands
require('plugins.init')       -- Plugin initialization
require('themes.catppuccin')  -- Theme configuration
```

#### Core Options (lua/core/options.lua)
```lua
-- Essential Neovim settings
vim.opt.number = true                    -- Line numbers
vim.opt.relativenumber = true           -- Relative line numbers
vim.opt.expandtab = true                 -- Use spaces instead of tabs
vim.opt.shiftwidth = 2                   -- Indent width
vim.opt.tabstop = 2                      -- Tab width
vim.opt.smartindent = true               -- Smart indentation
vim.opt.wrap = false                     -- No line wrapping
vim.opt.cursorline = true                -- Highlight current line
vim.opt.termguicolors = true             -- Enable 24-bit color
vim.opt.clipboard = 'unnamedplus'        -- System clipboard integration

-- Search settings
vim.opt.ignorecase = true                -- Case-insensitive search
vim.opt.smartcase = true                 -- Case-sensitive if capitals used
vim.opt.hlsearch = false                 -- No search highlighting
vim.opt.incsearch = true                 -- Incremental search

-- Performance settings
vim.opt.updatetime = 50                  -- Fast updates
vim.opt.timeoutlen = 300                 -- Key sequence timeout
vim.opt.undofile = true                  -- Persistent undo
vim.opt.backup = false                   -- No backup files
vim.opt.swapfile = false                 -- No swap files
```

#### Key Mappings (lua/core/keymaps.lua)
```lua
-- Leader key configuration
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Essential keymaps
local keymap = vim.keymap.set

-- File operations
keymap('n', '<leader>w', ':w<CR>', { desc = 'Save file' })
keymap('n', '<leader>q', ':q<CR>', { desc = 'Quit' })
keymap('n', '<leader>x', ':x<CR>', { desc = 'Save and quit' })

-- Navigation
keymap('n', '<C-h>', '<C-w>h', { desc = 'Move to left window' })
keymap('n', '<C-j>', '<C-w>j', { desc = 'Move to bottom window' })
keymap('n', '<C-k>', '<C-w>k', { desc = 'Move to top window' })
keymap('n', '<C-l>', '<C-w>l', { desc = 'Move to right window' })

-- Buffer navigation
keymap('n', '<leader>bn', ':bnext<CR>', { desc = 'Next buffer' })
keymap('n', '<leader>bp', ':bprevious<CR>', { desc = 'Previous buffer' })
keymap('n', '<leader>bd', ':bdelete<CR>', { desc = 'Delete buffer' })

-- Code editing
keymap('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Move selection down' })
keymap('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Move selection up' })
keymap('n', 'J', 'mzJ`z', { desc = 'Join lines' })

-- Search and replace
keymap('n', '<leader>s', [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], 
       { desc = 'Replace word under cursor' })
```

### Plugin System

#### Plugin Manager (lua/plugins/init.lua)
```lua
-- Bootstrap lazy.nvim plugin manager
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable',
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Plugin specifications
require('lazy').setup({
  -- Core plugins
  { 'catppuccin/nvim', name = 'catppuccin' },
  { 'nvim-treesitter/nvim-treesitter', build = ':TSUpdate' },
  { 'neovim/nvim-lspconfig' },
  { 'hrsh7th/nvim-cmp' },                 -- Completion engine
  { 'L3MON4D3/LuaSnip' },                 -- Snippet engine
  
  -- File navigation
  { 'nvim-telescope/telescope.nvim' },     -- Fuzzy finder
  { 'nvim-tree/nvim-tree.lua' },          -- File explorer
  
  -- Git integration
  { 'lewis6991/gitsigns.nvim' },          -- Git signs
  { 'tpope/vim-fugitive' },               -- Git commands
  
  -- Development tools
  { 'numToStr/Comment.nvim' },            -- Smart commenting
  { 'windwp/nvim-autopairs' },            -- Auto pair brackets
  { 'kylechui/nvim-surround' },           -- Surround text objects
})
```

#### LSP Configuration (lua/plugins/lsp.lua)
```lua
-- Language Server Protocol setup
local lspconfig = require('lspconfig')
local cmp = require('cmp')

-- LSP servers configuration
local servers = {
  -- Programming languages
  lua_ls = {                             -- Lua
    settings = {
      Lua = {
        diagnostics = { globals = { 'vim' } },
        workspace = { library = vim.api.nvim_get_runtime_file('', true) },
      },
    },
  },
  tsserver = {},                         -- TypeScript/JavaScript
  pyright = {},                          -- Python
  rust_analyzer = {},                    -- Rust
  gopls = {},                            -- Go
  clangd = {},                           -- C/C++
  
  -- Web development
  html = {},                             -- HTML
  cssls = {},                            -- CSS
  emmet_ls = {},                         -- Emmet
  
  -- DevOps and configuration
  yamlls = {},                           -- YAML
  dockerls = {},                         -- Docker
  terraformls = {},                      -- Terraform
}

-- Setup LSP servers
for server, config in pairs(servers) do
  lspconfig[server].setup(config)
end

-- Completion setup
cmp.setup({
  snippet = {
    expand = function(args)
      require('luasnip').lsp_expand(args.body)
    end,
  },
  mapping = {
    ['<C-n>'] = cmp.mapping.select_next_item(),
    ['<C-p>'] = cmp.mapping.select_prev_item(),
    ['<C-d>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<CR>'] = cmp.mapping.confirm({ select = true }),
  },
  sources = {
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
    { name = 'buffer' },
    { name = 'path' },
  },
})
```

### Advanced Neovim Features

#### Treesitter Configuration
```lua
-- Enhanced syntax highlighting and text objects
require('nvim-treesitter.configs').setup({
  ensure_installed = {
    'lua', 'python', 'javascript', 'typescript', 'rust', 'go',
    'html', 'css', 'yaml', 'json', 'markdown', 'bash'
  },
  highlight = { enable = true },
  indent = { enable = true },
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = '<CR>',
      node_incremental = '<CR>',
      scope_incremental = '<S-CR>',
      node_decremental = '<BS>',
    },
  },
})
```

#### File Navigation with Telescope
```lua
-- Fuzzy finder configuration
local telescope = require('telescope')

telescope.setup({
  defaults = {
    prompt_prefix = ' ',
    selection_caret = ' ',
    path_display = { 'truncate' },
    file_ignore_patterns = {
      'node_modules', '.git', 'target', 'dist', 'build'
    },
  },
})

-- Telescope keymaps
local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Find files' })
vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Live grep' })
vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Find buffers' })
vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Help tags' })
```

## VS Code Configuration

### Settings Configuration

#### Main Settings (settings.json)
```json
{
  // Theme and appearance
  "workbench.colorTheme": "Catppuccin Mocha",
  "workbench.iconTheme": "catppuccin-mocha",
  "editor.fontFamily": "JetBrains Mono, Fira Code, SF Mono, Menlo",
  "editor.fontSize": 13,
  "editor.fontLigatures": true,
  "editor.lineHeight": 1.5,
  
  // Editor behavior
  "editor.tabSize": 2,
  "editor.insertSpaces": true,
  "editor.detectIndentation": true,
  "editor.formatOnSave": true,
  "editor.formatOnPaste": true,
  "editor.codeActionsOnSave": {
    "source.fixAll": true,
    "source.organizeImports": true
  },
  
  // Performance and behavior
  "editor.semanticHighlighting.enabled": true,
  "editor.bracketPairColorization.enabled": true,
  "editor.guides.bracketPairs": true,
  "editor.minimap.enabled": false,
  "editor.scrollBeyondLastLine": false,
  "editor.renderWhitespace": "boundary",
  
  // File handling
  "files.autoSave": "afterDelay",
  "files.autoSaveDelay": 1000,
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,
  "files.exclude": {
    "**/.git": true,
    "**/.DS_Store": true,
    "**/node_modules": true,
    "**/target": true
  },
  
  // Terminal integration
  "terminal.integrated.fontFamily": "JetBrains Mono",
  "terminal.integrated.fontSize": 13,
  "terminal.integrated.shell.osx": "/opt/homebrew/bin/zsh",
  "terminal.integrated.defaultProfile.osx": "zsh",
  
  // Language-specific settings
  "[javascript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[python]": {
    "editor.defaultFormatter": "ms-python.black-formatter"
  },
  "[rust]": {
    "editor.defaultFormatter": "rust-lang.rust-analyzer"
  },
  "[go]": {
    "editor.defaultFormatter": "golang.go"
  }
}
```

#### Custom Keybindings (keybindings.json)
```json
[
  // File operations
  {
    "key": "cmd+shift+o",
    "command": "workbench.action.quickOpen"
  },
  
  // Navigation
  {
    "key": "cmd+shift+e",
    "command": "workbench.view.explorer"
  },
  {
    "key": "cmd+shift+f",
    "command": "workbench.view.search"
  },
  {
    "key": "cmd+shift+g",
    "command": "workbench.view.scm"
  },
  
  // Editor management
  {
    "key": "cmd+w",
    "command": "workbench.action.closeActiveEditor"
  },
  {
    "key": "cmd+shift+w",
    "command": "workbench.action.closeAllEditors"
  },
  
  // Terminal
  {
    "key": "cmd+shift+`",
    "command": "workbench.action.terminal.new"
  },
  
  // Custom commands matching Neovim
  {
    "key": "space w",
    "command": "workbench.action.files.save",
    "when": "vim.mode == 'Normal'"
  },
  {
    "key": "space q",
    "command": "workbench.action.closeActiveEditor",
    "when": "vim.mode == 'Normal'"
  }
]
```

### Essential Extensions

#### Core Extensions List
```json
{
  "recommendations": [
    // Theme and appearance
    "catppuccin.catppuccin-vsc",
    "catppuccin.catppuccin-vsc-icons",
    
    // Editor enhancements
    "vscodevim.vim",
    "ms-vscode.vscode-json",
    "editorconfig.editorconfig",
    "christian-kohler.path-intellisense",
    
    // Language support
    "ms-python.python",
    "ms-python.black-formatter",
    "rust-lang.rust-analyzer",
    "golang.go",
    "ms-vscode.vscode-typescript-next",
    "bradlc.vscode-tailwindcss",
    
    // Git and version control
    "eamodio.gitlens",
    "github.vscode-pull-request-github",
    "github.copilot",
    
    // Development tools
    "ms-vscode.live-server",
    "formulahendry.auto-rename-tag",
    "esbenp.prettier-vscode",
    "ms-vscode.vscode-eslint",
    
    // DevOps and infrastructure
    "ms-vscode-remote.remote-ssh",
    "ms-vscode-remote.remote-containers",
    "hashicorp.terraform",
    "ms-kubernetes-tools.vscode-kubernetes-tools"
  ]
}
```

#### Extension Configuration Examples
```json
// GitLens settings
"gitlens.views.repositories.files.layout": "tree",
"gitlens.currentLine.enabled": false,
"gitlens.hovers.currentLine.over": "line",

// Vim extension settings
"vim.easymotion": true,
"vim.incsearch": true,
"vim.useSystemClipboard": true,
"vim.useCtrlKeys": true,
"vim.hlsearch": true,

// Prettier settings
"prettier.singleQuote": true,
"prettier.trailingComma": "es5",
"prettier.tabWidth": 2,
"prettier.semi": false
```

## Terminal Integration

### Consistent Terminal Configuration

The terminal configuration ensures consistent theming and functionality across all terminal emulators:

#### Alacritty Configuration
```yaml
# config/alacritty/alacritty.yml
font:
  normal:
    family: JetBrains Mono
  size: 13.0

colors:
  # Catppuccin Mocha
  primary:
    background: '#1e1e2e'
    foreground: '#cdd6f4'
  
  cursor:
    text: '#1e1e2e'
    cursor: '#f5e0dc'
  
  selection:
    text: '#1e1e2e'
    background: '#f5e0dc'

window:
  padding:
    x: 10
    y: 10
  decorations: buttonless

scrolling:
  history: 10000
```

#### Kitty Configuration
```ini
# config/kitty/kitty.conf
font_family      JetBrains Mono Regular
bold_font        JetBrains Mono Bold
italic_font      JetBrains Mono Italic
font_size        13.0

# Catppuccin Mocha colors
background            #1e1e2e
foreground            #cdd6f4
selection_background  #f5e0dc
selection_foreground  #1e1e2e

cursor                #f5e0dc
cursor_text_color     #1e1e2e

# Performance
repaint_delay    10
input_delay      3
sync_to_monitor  yes
```

### Editor-Terminal Integration

#### Shell Integration
```bash
# Enhanced editor aliases in shell configuration
alias v='nvim'
alias vim='nvim'
alias code='code'
alias edit='$EDITOR'

# Editor-specific functions
neovim-config() {
    nvim ~/.config/nvim/init.lua
}

vscode-config() {
    code ~/.config/Code/User/settings.json
}

# Git integration with editors
export GIT_EDITOR='nvim'
export VISUAL='nvim'
export EDITOR='nvim'
```

## Theme System

### Unified Color Scheme

The Catppuccin Mocha theme provides consistent colors across all editors and terminals:

#### Base Color Palette
```yaml
# themes/editors/base16-colors.yml
base00: "#1e1e2e"  # Base background
base01: "#181825"  # Lighter background
base02: "#313244"  # Selection background
base03: "#45475a"  # Comments, invisibles
base04: "#585b70"  # Dark foreground
base05: "#cdd6f4"  # Default foreground
base06: "#f5e0dc"  # Light foreground
base07: "#b4befe"  # Light background

# Accent colors
base08: "#f38ba8"  # Red
base09: "#fab387"  # Orange
base0A: "#f9e2af"  # Yellow
base0B: "#a6e3a1"  # Green
base0C: "#94e2d5"  # Cyan
base0D: "#89b4fa"  # Blue
base0E: "#cba6f7"  # Purple
base0F: "#f2cdcd"  # Brown
```

#### Neovim Theme (lua/themes/catppuccin.lua)
```lua
require('catppuccin').setup({
  flavour = 'mocha',
  background = {
    light = 'latte',
    dark = 'mocha',
  },
  transparent_background = false,
  show_end_of_buffer = false,
  term_colors = true,
  dim_inactive = {
    enabled = false,
    shade = 'dark',
    percentage = 0.15,
  },
  integrations = {
    cmp = true,
    gitsigns = true,
    nvimtree = true,
    telescope = true,
    treesitter = true,
    which_key = true,
  },
})

vim.cmd.colorscheme('catppuccin')
```

#### VS Code Theme Configuration
```json
{
  "workbench.colorTheme": "Catppuccin Mocha",
  "workbench.iconTheme": "catppuccin-mocha",
  "workbench.colorCustomizations": {
    "editor.background": "#1e1e2e",
    "editor.foreground": "#cdd6f4",
    "editorCursor.foreground": "#f5e0dc",
    "editor.selectionBackground": "#f5e0dc33"
  }
}
```

## Language Support

### Language Server Protocol (LSP)

#### Automatic LSP Server Installation
```bash
#!/bin/bash
# scripts/setup-lsp.sh

# Node.js based servers
npm install -g typescript-language-server
npm install -g vscode-langservers-extracted  # HTML, CSS, JSON
npm install -g yaml-language-server
npm install -g dockerfile-language-server-nodejs

# Python
pip install python-lsp-server
pip install black isort flake8

# Rust (via rustup)
rustup component add rust-analyzer

# Go
go install golang.org/x/tools/gopls@latest

# Lua
brew install lua-language-server  # macOS
# apt install lua-language-server  # Linux
```

#### Language-Specific Configurations

##### Python Development
```lua
-- Neovim Python setup
lspconfig.pyright.setup({
  settings = {
    python = {
      analysis = {
        typeCheckingMode = 'basic',
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
      },
    },
  },
})

-- Python formatting
vim.cmd([[
  autocmd FileType python setlocal tabstop=4 shiftwidth=4 expandtab
  autocmd BufWritePre *.py lua vim.lsp.buf.format()
]])
```

```json
// VS Code Python settings
{
  "python.defaultInterpreterPath": "~/.pyenv/shims/python",
  "python.formatting.provider": "black",
  "python.linting.enabled": true,
  "python.linting.flake8Enabled": true,
  "python.analysis.typeCheckingMode": "basic"
}
```

##### JavaScript/TypeScript Development
```lua
-- Neovim TypeScript setup
lspconfig.tsserver.setup({
  on_attach = function(client, bufnr)
    -- Disable tsserver formatting (use prettier instead)
    client.server_capabilities.documentFormattingProvider = false
  end,
})

-- ESLint integration
lspconfig.eslint.setup({
  on_attach = function(client, bufnr)
    vim.api.nvim_create_autocmd('BufWritePre', {
      buffer = bufnr,
      command = 'EslintFixAll',
    })
  end,
})
```

```json
// VS Code TypeScript settings
{
  "typescript.preferences.importModuleSpecifier": "relative",
  "typescript.suggest.autoImports": true,
  "javascript.format.enable": false,
  "typescript.format.enable": false,
  "[typescript]": {
    "editor.codeActionsOnSave": {
      "source.fixAll.eslint": true
    }
  }
}
```

##### Rust Development
```lua
-- Neovim Rust setup
lspconfig.rust_analyzer.setup({
  settings = {
    ['rust-analyzer'] = {
      cargo = {
        allFeatures = true,
      },
      checkOnSave = {
        command = 'clippy',
      },
    },
  },
})
```

```json
// VS Code Rust settings
{
  "rust-analyzer.cargo.allFeatures": true,
  "rust-analyzer.checkOnSave.command": "clippy",
  "rust-analyzer.inlayHints.chainingHints": true,
  "rust-analyzer.inlayHints.parameterHints": true
}
```

## Customization

### Personal Configuration Overrides

#### Neovim Local Configuration
```lua
-- ~/.config/nvim/lua/local/init.lua
-- Personal overrides (git-ignored)

-- Custom keymaps
vim.keymap.set('n', '<leader>tt', ':terminal<CR>', { desc = 'Open terminal' })

-- Project-specific settings
vim.api.nvim_create_autocmd('VimEnter', {
  callback = function()
    if vim.fn.isdirectory('.git') == 1 then
      -- Git project specific settings
      vim.opt.colorcolumn = '80'
    end
  end,
})

-- Custom commands
vim.api.nvim_create_user_command('ProjectGrep', function(opts)
  require('telescope.builtin').live_grep({
    search_dirs = { vim.fn.getcwd() },
    additional_args = function()
      return { '--hidden', '--glob', '!.git/*' }
    end,
  })
end, {})
```

#### VS Code Workspace Settings
```json
// .vscode/settings.json (per-project)
{
  "editor.rulers": [80, 120],
  "files.watcherExclude": {
    "**/target/**": true,
    "**/node_modules/**": true
  },
  "search.exclude": {
    "**/target": true,
    "**/node_modules": true,
    "**/*.lock": true
  }
}
```

### Theme Customization

#### Custom Catppuccin Variant
```lua
-- Custom theme modifications
require('catppuccin').setup({
  custom_highlights = function(colors)
    return {
      Comment = { fg = colors.overlay1, style = { 'italic' } },
      LineNr = { fg = colors.overlay0 },
      CursorLineNr = { fg = colors.lavender, style = { 'bold' } },
      GitSignsAdd = { fg = colors.green },
      GitSignsChange = { fg = colors.yellow },
      GitSignsDelete = { fg = colors.red },
    }
  end,
})
```

## Performance Optimization

### Neovim Performance

#### Startup Optimization
```lua
-- Lazy loading configuration
vim.opt.updatetime = 50
vim.opt.timeoutlen = 300

-- Disable unnecessary features
vim.g.loaded_gzip = 1
vim.g.loaded_tar = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_zip = 1
vim.g.loaded_zipPlugin = 1
vim.g.loaded_getscript = 1
vim.g.loaded_getscriptPlugin = 1
vim.g.loaded_vimball = 1
vim.g.loaded_vimballPlugin = 1
vim.g.loaded_matchit = 1
vim.g.loaded_matchparen = 1
vim.g.loaded_2html_plugin = 1
vim.g.loaded_logiPat = 1
vim.g.loaded_rrhelper = 1
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrwSettings = 1
vim.g.loaded_netrwFileHandlers = 1
```

#### Plugin Lazy Loading
```lua
-- Lazy loading examples
{
  'nvim-telescope/telescope.nvim',
  cmd = 'Telescope',
  keys = {
    { '<leader>ff', '<cmd>Telescope find_files<cr>' },
    { '<leader>fg', '<cmd>Telescope live_grep<cr>' },
  },
}

{
  'nvim-tree/nvim-tree.lua',
  cmd = { 'NvimTreeToggle', 'NvimTreeFocus' },
  keys = {
    { '<leader>e', '<cmd>NvimTreeToggle<cr>' },
  },
}
```

### VS Code Performance

#### Settings for Large Projects
```json
{
  "files.watcherExclude": {
    "**/.git/objects/**": true,
    "**/.git/subtree-cache/**": true,
    "**/node_modules/*/**": true,
    "**/target/**": true
  },
  "search.followSymlinks": false,
  "search.useRipgrep": true,
  "editor.semanticTokenColorCustomizations": {
    "enabled": true
  }
}
```

### Performance Monitoring

#### Neovim Profiling
```lua
-- Profile Neovim startup
-- Run: nvim --startuptime startup.log

-- Runtime profiling
vim.cmd('profile start profile.log')
vim.cmd('profile func *')
vim.cmd('profile file *')
-- ... do work
vim.cmd('profile pause')
```

#### VS Code Performance Tools
```bash
# VS Code performance analysis
code --disable-extensions              # Test without extensions
code --verbose                        # Verbose logging
code --log trace                      # Detailed logging
```

## Troubleshooting

### Common Issues

#### Neovim Issues

##### LSP Not Working
```bash
# Check LSP status
:LspInfo

# Check if server is installed
which pyright
which typescript-language-server

# Restart LSP
:LspRestart

# Debug LSP logs
:lua vim.lsp.set_log_level('debug')
tail -f ~/.local/state/nvim/lsp.log
```

##### Plugin Issues
```bash
# Update plugins
:Lazy update

# Clean and reinstall
:Lazy clean
:Lazy install

# Check plugin health
:checkhealth lazy
```

##### Theme Issues
```bash
# Check terminal color support
echo $TERM
echo $COLORTERM

# Test 24-bit color
curl -s https://raw.githubusercontent.com/JohnMorales/dotfiles/master/colors/24-bit-color.sh | bash

# Reset colorscheme
:colorscheme default
```

#### VS Code Issues

##### Extension Problems
```bash
# List installed extensions
code --list-extensions

# Disable all extensions
code --disable-extensions

# Reset extension host
# Command Palette → "Developer: Restart Extension Host"
```

##### Settings Sync Issues
```bash
# Check settings sync status
# Command Palette → "Settings Sync: Show Settings"

# Force sync
# Command Palette → "Settings Sync: Download Settings"
```

##### Performance Issues
```bash
# Check extension performance
# Command Palette → "Developer: Show Running Extensions"

# Disable problematic extensions
code --disable-extension <extension-id>
```

### Diagnostic Commands

#### System Diagnostics
```bash
# Check editor installations
which nvim code vim
nvim --version
code --version

# Check LSP servers
which pyright tsserver rust-analyzer gopls

# Check font installation
fc-list | grep -i "jetbrains\|fira"

# Check terminal capabilities
echo $TERM $COLORTERM
tput colors
```

#### Configuration Validation
```bash
# Test Neovim configuration
nvim --clean -c "source ~/.config/nvim/init.lua" -c "quit"

# Validate JSON settings
python -m json.tool ~/.config/Code/User/settings.json

# Check file permissions
ls -la ~/.config/nvim/
ls -la ~/.config/Code/User/
```

## Migration Guide

### From Vim to Neovim

#### Configuration Migration
```bash
# Backup existing Vim configuration
cp ~/.vimrc ~/.vimrc.backup

# Convert basic Vim settings to Lua
# .vimrc → ~/.config/nvim/lua/core/options.lua
```

#### Plugin Migration
```vim
" Old Vim plugin management (Vundle/Pathogen)
" Convert to lazy.nvim specification:

" Before (Vundle)
Plugin 'tpope/vim-fugitive'
Plugin 'scrooloose/nerdtree'

" After (lazy.nvim)
{ 'tpope/vim-fugitive' },
{ 'nvim-tree/nvim-tree.lua' },  -- Modern alternative
```

### From Other Editors

#### Sublime Text Migration
```json
// Import Sublime Text keybindings to VS Code
{
  "key": "cmd+d",
  "command": "editor.action.addSelectionToNextFindMatch"
},
{
  "key": "cmd+shift+l",
  "command": "editor.action.selectHighlights"
}
```

#### Atom Migration
```json
// Common Atom packages → VS Code extensions
// atom-beautify → Prettier
// minimap → editor.minimap.enabled
// file-icons → file-icon-theme
```

## Advanced Usage

### Multi-Editor Workflows

#### Shared Configuration
```bash
# Shared editor configuration
cat > ~/.editorconfig << 'EOF'
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 2

[*.{py,pyi}]
indent_size = 4

[*.go]
indent_style = tab
indent_size = 4

[*.md]
trim_trailing_whitespace = false
EOF
```

#### Project-Specific Setup
```lua
-- Neovim project detection
local function setup_project()
  local root_dir = vim.fn.getcwd()
  
  -- Detect project type
  if vim.fn.filereadable(root_dir .. '/package.json') == 1 then
    -- Node.js project
    vim.opt.tabstop = 2
    vim.opt.shiftwidth = 2
  elseif vim.fn.filereadable(root_dir .. '/Cargo.toml') == 1 then
    -- Rust project
    vim.opt.tabstop = 4
    vim.opt.shiftwidth = 4
  end
end

vim.api.nvim_create_autocmd('VimEnter', {
  callback = setup_project,
})
```

### Remote Development

#### VS Code Remote SSH
```json
// Remote SSH settings
{
  "remote.SSH.remotePlatform": {
    "myserver": "linux"
  },
  "remote.SSH.configFile": "~/.ssh/config",
  "remote.extensionKind": {
    "ms-python.python": ["workspace"]
  }
}
```

#### Neovim Remote Editing
```bash
# Use Neovim for remote editing
alias rvi='ssh -t server "nvim"'

# Remote development with tmux
ssh -t server "tmux new-session -d -s dev && tmux attach -t dev"
```

## Reference

### Configuration Files

| File | Purpose | Editor |
|------|---------|---------|
| `~/.config/nvim/init.lua` | Main Neovim configuration | Neovim |
| `~/.config/Code/User/settings.json` | VS Code settings | VS Code |
| `~/.config/Code/User/keybindings.json` | VS Code keybindings | VS Code |
| `~/.vimrc` | Vim fallback configuration | Vim |
| `~/.editorconfig` | Universal editor settings | All |

### Key Mappings

#### Neovim (Normal Mode)
| Key | Action | Description |
|-----|--------|-------------|
| `<leader>w` | `:w<CR>` | Save file |
| `<leader>q` | `:q<CR>` | Quit |
| `<leader>ff` | Telescope find files | Find files |
| `<leader>fg` | Telescope live grep | Search in files |
| `<leader>e` | NvimTree toggle | File explorer |

#### VS Code
| Key | Action | Description |
|-----|--------|-------------|
| `Cmd+Shift+P` | Command Palette | Open command palette |
| `Cmd+P` | Quick Open | Quick file open |
| `Cmd+Shift+E` | Explorer | File explorer |
| `Cmd+Shift+F` | Search | Global search |
| `Cmd+`` | Terminal | Integrated terminal |

### Language Server Servers

| Language | Server | Installation |
|----------|--------|--------------|
| **Python** | pyright | `npm install -g pyright` |
| **JavaScript/TypeScript** | tsserver | `npm install -g typescript-language-server` |
| **Rust** | rust-analyzer | `rustup component add rust-analyzer` |
| **Go** | gopls | `go install golang.org/x/tools/gopls@latest` |
| **Lua** | lua-language-server | `brew install lua-language-server` |
| **HTML/CSS** | vscode-langservers-extracted | `npm install -g vscode-langservers-extracted` |

### Performance Targets

| Metric | Target | Editor |
|--------|--------|---------|
| Startup time | <100ms | Neovim |
| Startup time | <1s | VS Code |
| LSP response | <50ms | Both |
| File search | <200ms | Both |
| Theme switch | <100ms | Both |

This editor configuration system provides a powerful, consistent, and highly customizable development environment that adapts to your workflow while maintaining performance and usability across different editing contexts. 