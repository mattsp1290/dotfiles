" Sample vim configuration for testing
set nocompatible
filetype off

" Basic settings
set number
set relativenumber
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent
set smartindent

" Search settings
set incsearch
set hlsearch
set ignorecase
set smartcase

" UI settings
set showcmd
set showmatch
set laststatus=2
set wildmenu
set cursorline

" Key mappings
let mapleader = ","
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>h :nohl<CR>

" Plugin management (placeholder)
if has('plugin_manager')
    call plug#begin('~/.vim/plugged')
    Plug 'tpope/vim-sensible'
    Plug 'tpope/vim-surround'
    call plug#end()
endif

" Color scheme
if has('syntax')
    syntax enable
    if has('termguicolors')
        set termguicolors
    endif
    colorscheme default
endif

" File type specific settings
autocmd FileType python setlocal tabstop=4 shiftwidth=4 expandtab
autocmd FileType javascript setlocal tabstop=2 shiftwidth=2 expandtab
autocmd FileType yaml setlocal tabstop=2 shiftwidth=2 expandtab

" Status line
set statusline=%f\ %m%r%h%w\ [%Y]\ [%{&ff}]\ %=%l,%c\ %p%% 