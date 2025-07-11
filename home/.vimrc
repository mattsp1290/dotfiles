" Vim Configuration
" DEV-003: Editor Configuration - Vim Compatibility

" Ensure we're using Vim-improved, not plain Vi
set nocompatible

" Plugin management with vim-plug
" Automatically install vim-plug if it doesn't exist
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" Plugin declarations
call plug#begin('~/.vim/plugged')

" Essential plugins
Plug 'tpope/vim-sensible'           " Sensible defaults
Plug 'tpope/vim-fugitive'           " Git integration
Plug 'tpope/vim-surround'           " Surround text objects
Plug 'tpope/vim-commentary'         " Easy commenting
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'             " Fuzzy finder
Plug 'airblade/vim-gitgutter'       " Git diff in gutter
Plug 'preservim/nerdtree'           " File explorer
Plug 'vim-airline/vim-airline'      " Status line
Plug 'vim-airline/vim-airline-themes'

" Syntax and language support
Plug 'sheerun/vim-polyglot'         " Language pack
Plug 'dense-analysis/ale'           " Linting and formatting

" Color schemes
Plug 'morhetz/gruvbox'
Plug 'joshdick/onedark.vim'
Plug 'dracula/vim', { 'as': 'dracula' }

call plug#end()

" Basic Settings
" ==============

" Leader key
let mapleader = " "
let maplocalleader = " "

" Basic editor settings
set number                  " Show line numbers
set relativenumber          " Show relative line numbers
set cursorline              " Highlight current line
set showcmd                 " Show command in bottom bar
set showmatch               " Highlight matching brackets

" Indentation
set tabstop=2               " Tab width
set shiftwidth=2            " Shift width for indentation
set expandtab               " Use spaces instead of tabs
set autoindent              " Auto indent new lines
set smartindent             " Smart indentation

" Search settings
set ignorecase              " Ignore case in search
set smartcase               " Override ignorecase if search contains uppercase
set incsearch               " Incremental search
set hlsearch                " Highlight search results

" UI settings
set laststatus=2            " Always show status line
set ruler                   " Show cursor position
set wildmenu                " Enhanced command line completion
set wildmode=longest,list   " Command line completion mode
set scrolloff=8             " Keep lines visible above/below cursor
set sidescrolloff=8         " Keep columns visible left/right of cursor

" File handling
set hidden                  " Allow hidden buffers
set autoread                " Auto reload files changed outside Vim
set backup                  " Enable backup files
set backupdir=~/.vim/backup " Backup directory
set directory=~/.vim/swap   " Swap file directory
set undofile                " Persistent undo
set undodir=~/.vim/undo     " Undo directory

" Create directories if they don't exist
if !isdirectory($HOME."/.vim/backup")
    call mkdir($HOME."/.vim/backup", "p", 0700)
endif
if !isdirectory($HOME."/.vim/swap")
    call mkdir($HOME."/.vim/swap", "p", 0700)
endif
if !isdirectory($HOME."/.vim/undo")
    call mkdir($HOME."/.vim/undo", "p", 0700)
endif

" Performance
set lazyredraw              " Don't redraw during macros
set ttyfast                 " Fast terminal connection

" Key Mappings
" ============

" General mappings
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>x :x<CR>

" Better escape
inoremap jk <ESC>
inoremap kj <ESC>

" Window navigation
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Buffer navigation
nnoremap <S-h> :bprev<CR>
nnoremap <S-l> :bnext<CR>

" Clear search highlights
nnoremap <leader>h :nohlsearch<CR>

" Better indenting in visual mode
vnoremap < <gv
vnoremap > >gv

" Move text up and down
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

" Keep cursor centered during navigation
nnoremap <C-d> <C-d>zz
nnoremap <C-u> <C-u>zz
nnoremap n nzzzv
nnoremap N Nzzzv

" FZF mappings
nnoremap <leader>ff :Files<CR>
nnoremap <leader>fb :Buffers<CR>
nnoremap <leader>fr :History<CR>
nnoremap <leader>fg :Rg<CR>

" NERDTree mappings
nnoremap <leader>e :NERDTreeToggle<CR>
nnoremap <leader>fe :NERDTreeFind<CR>

" Git mappings
nnoremap <leader>gs :Git<CR>
nnoremap <leader>ga :Git add %<CR>
nnoremap <leader>gc :Git commit<CR>
nnoremap <leader>gd :Gdiff<CR>
nnoremap <leader>gl :Git log<CR>
nnoremap <leader>gp :Git push<CR>
nnoremap <leader>gP :Git pull<CR>

" Plugin Configuration
" ===================

" Gruvbox color scheme
if has('termguicolors')
    set termguicolors
endif
set background=dark
silent! colorscheme gruvbox

" Airline configuration
let g:airline_theme = 'gruvbox'
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#buffer_nr_show = 1

" NERDTree configuration
let NERDTreeShowHidden = 1
let NERDTreeQuitOnOpen = 1
let NERDTreeAutoDeleteBuffer = 1
let NERDTreeMinimalUI = 1
let NERDTreeDirArrows = 1

" GitGutter configuration
let g:gitgutter_enabled = 1
let g:gitgutter_map_keys = 0
let g:gitgutter_highlight_lines = 0
let g:gitgutter_sign_priority = 6

" GitGutter mappings
nmap ]c <Plug>(GitGutterNextHunk)
nmap [c <Plug>(GitGutterPrevHunk)
nmap <leader>hs <Plug>(GitGutterStageHunk)
nmap <leader>hr <Plug>(GitGutterUndoHunk)
nmap <leader>hp <Plug>(GitGutterPreviewHunk)

" ALE configuration
let g:ale_enabled = 1
let g:ale_fix_on_save = 1
let g:ale_lint_on_text_changed = 'never'
let g:ale_lint_on_insert_leave = 0
let g:ale_lint_on_enter = 0

" ALE fixers
let g:ale_fixers = {
\   '*': ['remove_trailing_lines', 'trim_whitespace'],
\   'javascript': ['prettier', 'eslint'],
\   'typescript': ['prettier', 'eslint'],
\   'python': ['black', 'isort'],
\   'go': ['gofmt'],
\   'rust': ['rustfmt'],
\   'sh': ['shfmt'],
\}

" ALE linters
let g:ale_linters = {
\   'python': ['flake8'],
\   'javascript': ['eslint'],
\   'typescript': ['eslint'],
\   'go': ['golangci-lint'],
\   'sh': ['shellcheck'],
\}

" FZF configuration
let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.6 } }
let g:fzf_preview_window = ['right:50%', 'ctrl-/']

" Auto Commands
" =============

augroup vimrc_autocmds
    autocmd!
    
    " Highlight on yank (Vim 8.0.1394+)
    if exists('##TextYankPost')
        autocmd TextYankPost * silent! lua vim.highlight.on_yank({higroup="Visual", timeout=200})
    endif
    
    " Remove trailing whitespace on save
    autocmd BufWritePre * :%s/\s\+$//e
    
    " Return to last cursor position
    autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
    
    " Set filetype for specific files
    autocmd BufRead,BufNewFile *.md set filetype=markdown
    autocmd BufRead,BufNewFile *.env set filetype=sh
    autocmd BufRead,BufNewFile Dockerfile* set filetype=dockerfile
    
    " Language-specific settings
    autocmd FileType python setlocal tabstop=4 shiftwidth=4
    autocmd FileType go setlocal tabstop=4 shiftwidth=4 noexpandtab
    autocmd FileType make setlocal noexpandtab
    
    " Text files settings
    autocmd FileType markdown,text setlocal wrap linebreak spell
    
    " Auto close NERDTree if it's the only window
    autocmd BufEnter * if winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif
augroup END

" Functions
" =========

" Toggle line numbers
function! ToggleNumber()
    if &number
        set nonumber
        set norelativenumber
    else
        set number
        set relativenumber
    endif
endfunction

nnoremap <leader>tn :call ToggleNumber()<CR>

" Create parent directories when saving
function! MkdirOnSave()
    if !isdirectory(expand('%:h'))
        call mkdir(expand('%:h'), 'p')
    endif
endfunction

autocmd BufWritePre * call MkdirOnSave()

" Status line (fallback if airline is not available)
if !exists('g:loaded_airline')
    set statusline=%f\ %m%r%h%w\ [%Y]\ [%{&ff}]\ %=%l,%c\ %p%%
endif

" Compatibility Settings
" =====================

" Ensure compatibility with older Vim versions
if v:version < 704
    echo "Warning: This configuration requires Vim 7.4 or higher"
endif

" Enable mouse if available
if has('mouse')
    set mouse=a
endif

" Enable clipboard integration if available
if has('clipboard')
    set clipboard=unnamedplus
endif

" Load local configuration if it exists
if filereadable(expand('~/.vimrc.local'))
    source ~/.vimrc.local
endif 