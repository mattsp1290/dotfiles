" Test Color Scheme for Integration Testing
" Simple color scheme used to test vim configuration loading

set background=dark
highlight clear

if exists("syntax_on")
  syntax reset
endif

let g:colors_name = "test"

" Basic highlighting
highlight Normal       ctermfg=white    ctermbg=black
highlight Comment      ctermfg=blue     cterm=italic
highlight Constant     ctermfg=red      cterm=none
highlight String       ctermfg=green    cterm=none
highlight Identifier   ctermfg=cyan     cterm=none
highlight Statement    ctermfg=yellow   cterm=bold
highlight PreProc      ctermfg=magenta  cterm=none
highlight Type         ctermfg=green    cterm=bold
highlight Special      ctermfg=red      cterm=none
highlight Error        ctermfg=white    ctermbg=red
highlight Todo         ctermfg=black    ctermbg=yellow

" UI elements
highlight StatusLine   ctermfg=black    ctermbg=white
highlight StatusLineNC ctermfg=gray     ctermbg=black
highlight VertSplit    ctermfg=gray     ctermbg=black
highlight LineNr       ctermfg=gray     ctermbg=none
highlight CursorLine   cterm=underline  ctermbg=none
highlight Visual       ctermfg=black    ctermbg=gray

" Search highlighting
highlight Search       ctermfg=black    ctermbg=yellow
highlight IncSearch    ctermfg=black    ctermbg=green

" Integration test marker
" INTEGRATION_TEST_MARKER: Test color scheme loaded 