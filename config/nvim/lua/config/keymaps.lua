-- Key Mappings
-- DEV-003: Editor Configuration - Key Bindings

local keymap = vim.keymap
local opts = { noremap = true, silent = true }

-- Helper function for descriptions
local function desc(description)
  return { noremap = true, silent = true, desc = description }
end

-- General mappings
keymap.set("n", "<leader>w", "<cmd>w<CR>", desc("Save file"))
keymap.set("n", "<leader>W", "<cmd>wa<CR>", desc("Save all files"))
keymap.set("n", "<leader>q", "<cmd>q<CR>", desc("Quit"))
keymap.set("n", "<leader>Q", "<cmd>qa<CR>", desc("Quit all"))
keymap.set("n", "<leader>x", "<cmd>x<CR>", desc("Save and quit"))

-- Better escape
keymap.set("i", "jk", "<ESC>", desc("Exit insert mode"))
keymap.set("i", "kj", "<ESC>", desc("Exit insert mode"))

-- Window navigation
keymap.set("n", "<C-h>", "<C-w>h", desc("Move to left window"))
keymap.set("n", "<C-j>", "<C-w>j", desc("Move to bottom window"))
keymap.set("n", "<C-k>", "<C-w>k", desc("Move to top window"))
keymap.set("n", "<C-l>", "<C-w>l", desc("Move to right window"))

-- Window resizing
keymap.set("n", "<C-Up>", "<cmd>resize +2<CR>", desc("Increase window height"))
keymap.set("n", "<C-Down>", "<cmd>resize -2<CR>", desc("Decrease window height"))
keymap.set("n", "<C-Left>", "<cmd>vertical resize -2<CR>", desc("Decrease window width"))
keymap.set("n", "<C-Right>", "<cmd>vertical resize +2<CR>", desc("Increase window width"))

-- Window splits
keymap.set("n", "<leader>sv", "<cmd>vsplit<CR>", desc("Split window vertically"))
keymap.set("n", "<leader>sh", "<cmd>split<CR>", desc("Split window horizontally"))
keymap.set("n", "<leader>sx", "<cmd>close<CR>", desc("Close current split"))
keymap.set("n", "<leader>so", "<cmd>only<CR>", desc("Close all other splits"))

-- Buffer navigation
keymap.set("n", "<S-h>", "<cmd>bprevious<CR>", desc("Previous buffer"))
keymap.set("n", "<S-l>", "<cmd>bnext<CR>", desc("Next buffer"))
keymap.set("n", "<leader>bd", "<cmd>bdelete<CR>", desc("Delete buffer"))
keymap.set("n", "<leader>bD", "<cmd>bdelete!<CR>", desc("Force delete buffer"))
keymap.set("n", "<leader>bo", "<cmd>%bdelete|edit#<CR>", desc("Delete all other buffers"))

-- Tab navigation
keymap.set("n", "<leader>tn", "<cmd>tabnew<CR>", desc("New tab"))
keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", desc("Close tab"))
keymap.set("n", "<leader>to", "<cmd>tabonly<CR>", desc("Close all other tabs"))
keymap.set("n", "<A-1>", "1gt", desc("Go to tab 1"))
keymap.set("n", "<A-2>", "2gt", desc("Go to tab 2"))
keymap.set("n", "<A-3>", "3gt", desc("Go to tab 3"))
keymap.set("n", "<A-4>", "4gt", desc("Go to tab 4"))
keymap.set("n", "<A-5>", "5gt", desc("Go to tab 5"))

-- Clear search highlights
keymap.set("n", "<leader>h", "<cmd>nohlsearch<CR>", desc("Clear search highlights"))
keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR><Esc>", desc("Clear search highlights"))

-- Better indenting
keymap.set("v", "<", "<gv", desc("Indent left"))
keymap.set("v", ">", ">gv", desc("Indent right"))

-- Move text up and down
keymap.set("v", "J", ":m '>+1<CR>gv=gv", desc("Move text down"))
keymap.set("v", "K", ":m '<-2<CR>gv=gv", desc("Move text up"))
keymap.set("x", "J", ":m '>+1<CR>gv=gv", desc("Move text down"))
keymap.set("x", "K", ":m '<-2<CR>gv=gv", desc("Move text up"))

-- Keep cursor centered during navigation
keymap.set("n", "<C-d>", "<C-d>zz", desc("Half page down"))
keymap.set("n", "<C-u>", "<C-u>zz", desc("Half page up"))
keymap.set("n", "n", "nzzzv", desc("Next search result"))
keymap.set("n", "N", "Nzzzv", desc("Previous search result"))

-- Better paste behavior
keymap.set("x", "<leader>p", '"_dP', desc("Paste without yanking"))
keymap.set("n", "<leader>p", '"+p', desc("Paste from system clipboard"))
keymap.set("n", "<leader>P", '"+P', desc("Paste from system clipboard before"))

-- Better yank behavior
keymap.set("n", "<leader>y", '"+y', desc("Yank to system clipboard"))
keymap.set("v", "<leader>y", '"+y', desc("Yank to system clipboard"))
keymap.set("n", "<leader>Y", '"+Y', desc("Yank line to system clipboard"))

-- Delete without yanking
keymap.set("n", "<leader>d", '"_d', desc("Delete without yanking"))
keymap.set("v", "<leader>d", '"_d', desc("Delete without yanking"))

-- Substitute word under cursor
keymap.set("n", "<leader>s", ":%s/\\<<C-r><C-w>\\>/<C-r><C-w>/gI<Left><Left><Left>", desc("Substitute word under cursor"))

-- Make file executable
keymap.set("n", "<leader>cx", "<cmd>!chmod +x %<CR>", desc("Make file executable"))

-- Source current file
keymap.set("n", "<leader>so", "<cmd>so<CR>", desc("Source current file"))

-- Quick fix navigation
keymap.set("n", "<leader>qn", "<cmd>cnext<CR>", desc("Next quickfix item"))
keymap.set("n", "<leader>qp", "<cmd>cprev<CR>", desc("Previous quickfix item"))
keymap.set("n", "<leader>qo", "<cmd>copen<CR>", desc("Open quickfix list"))
keymap.set("n", "<leader>qc", "<cmd>cclose<CR>", desc("Close quickfix list"))

-- Location list navigation
keymap.set("n", "<leader>ln", "<cmd>lnext<CR>", desc("Next location item"))
keymap.set("n", "<leader>lp", "<cmd>lprev<CR>", desc("Previous location item"))
keymap.set("n", "<leader>lo", "<cmd>lopen<CR>", desc("Open location list"))
keymap.set("n", "<leader>lc", "<cmd>lclose<CR>", desc("Close location list"))

-- Terminal mappings
keymap.set("n", "<leader>tt", "<cmd>terminal<CR>", desc("Open terminal"))
keymap.set("t", "<Esc>", "<C-\\><C-n>", desc("Exit terminal mode"))
keymap.set("t", "<C-h>", "<C-\\><C-n><C-w>h", desc("Terminal: move to left window"))
keymap.set("t", "<C-j>", "<C-\\><C-n><C-w>j", desc("Terminal: move to bottom window"))
keymap.set("t", "<C-k>", "<C-\\><C-n><C-w>k", desc("Terminal: move to top window"))
keymap.set("t", "<C-l>", "<C-\\><C-n><C-w>l", desc("Terminal: move to right window"))

-- Text objects
keymap.set("v", "il", "g_", desc("Select to end of line"))
keymap.set("o", "il", "g_", desc("Select to end of line"))
keymap.set("v", "al", "0$", desc("Select entire line"))
keymap.set("o", "al", "0$", desc("Select entire line"))

-- Command line mappings
keymap.set("c", "<C-a>", "<Home>", desc("Move to beginning of line"))
keymap.set("c", "<C-e>", "<End>", desc("Move to end of line"))
keymap.set("c", "<C-d>", "<Del>", desc("Delete character"))
keymap.set("c", "<C-h>", "<BS>", desc("Delete previous character"))

-- Insert mode navigation
keymap.set("i", "<C-h>", "<Left>", desc("Move left"))
keymap.set("i", "<C-j>", "<Down>", desc("Move down"))
keymap.set("i", "<C-k>", "<Up>", desc("Move up"))
keymap.set("i", "<C-l>", "<Right>", desc("Move right"))

-- Folding
keymap.set("n", "<leader>fo", "zo", desc("Open fold"))
keymap.set("n", "<leader>fc", "zc", desc("Close fold"))
keymap.set("n", "<leader>fa", "za", desc("Toggle fold"))
keymap.set("n", "<leader>fO", "zO", desc("Open all folds"))
keymap.set("n", "<leader>fC", "zM", desc("Close all folds"))
keymap.set("n", "<leader>fR", "zR", desc("Open all folds recursively"))

-- Spell checking
keymap.set("n", "<leader>cs", "<cmd>setlocal spell!<CR>", desc("Toggle spell check"))
keymap.set("n", "<leader>cn", "]s", desc("Next misspelled word"))
keymap.set("n", "<leader>cp", "[s", desc("Previous misspelled word"))
keymap.set("n", "<leader>ca", "zg", desc("Add word to dictionary"))
keymap.set("n", "<leader>cr", "z=", desc("Suggest corrections"))

-- Toggle options
keymap.set("n", "<leader>tw", "<cmd>set wrap!<CR>", desc("Toggle line wrap"))
keymap.set("n", "<leader>tn", "<cmd>set number!<CR>", desc("Toggle line numbers"))
keymap.set("n", "<leader>tr", "<cmd>set relativenumber!<CR>", desc("Toggle relative numbers"))
keymap.set("n", "<leader>th", "<cmd>set hlsearch!<CR>", desc("Toggle search highlight"))
keymap.set("n", "<leader>tc", "<cmd>set cursorline!<CR>", desc("Toggle cursor line"))

-- Diagnostic navigation (will be overridden by LSP if available)
keymap.set("n", "[d", vim.diagnostic.goto_prev, desc("Previous diagnostic"))
keymap.set("n", "]d", vim.diagnostic.goto_next, desc("Next diagnostic"))
keymap.set("n", "<leader>e", vim.diagnostic.open_float, desc("Show diagnostic"))
keymap.set("n", "<leader>dl", vim.diagnostic.setloclist, desc("Diagnostic location list")) 