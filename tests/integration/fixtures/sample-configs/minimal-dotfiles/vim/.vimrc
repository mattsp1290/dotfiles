" Minimal Vim Configuration for Integration Testing
" This file is used to test dotfiles installation and management

" Basic settings
set nocompatible
syntax on
set number
set relativenumber
set cursorline
set showmatch
set hlsearch
set incsearch
set ignorecase
set smartcase

" Indentation
set expandtab
set tabstop=4
set shiftwidth=4
set autoindent
set smartindent

" Interface
set ruler
set laststatus=2
set wildmenu
set wildmode=longest:full,full

" File handling
set hidden
set backup
set backupdir=~/.vim/backup//
set directory=~/.vim/swap//
set undofile
set undodir=~/.vim/undo//

" Create backup directories if they don't exist
if !isdirectory(expand('~/.vim/backup'))
    call mkdir(expand('~/.vim/backup'), 'p')
endif
if !isdirectory(expand('~/.vim/swap'))
    call mkdir(expand('~/.vim/swap'), 'p')
endif
if !isdirectory(expand('~/.vim/undo'))
    call mkdir(expand('~/.vim/undo'), 'p')
endif

" Color scheme
if has('termguicolors')
    set termguicolors
endif

" Load test color scheme if available
if filereadable(expand('~/.vim/colors/test.vim'))
    colorscheme test
else
    colorscheme default
endif

" Key mappings
let mapleader = " "

" Quick save and quit
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>x :wq<CR>

" Clear search highlighting
nnoremap <leader>/ :nohlsearch<CR>

" Buffer navigation
nnoremap <leader>bn :bnext<CR>
nnoremap <leader>bp :bprevious<CR>
nnoremap <leader>bd :bdelete<CR>

" Test marker for integration tests
" INTEGRATION_TEST_MARKER: This line is used by tests to verify vim config loading 