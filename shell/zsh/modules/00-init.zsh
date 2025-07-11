# Zsh Initialization Module
# Basic Zsh options and behavior configuration

# History options
setopt APPEND_HISTORY          # Append to history file, don't overwrite
setopt SHARE_HISTORY           # Share history between sessions
setopt HIST_IGNORE_DUPS        # Don't record duplicate entries
setopt HIST_IGNORE_ALL_DUPS    # Remove older duplicate entries
setopt HIST_IGNORE_SPACE       # Don't record entries starting with space
setopt HIST_FIND_NO_DUPS       # Don't display duplicates when searching
setopt HIST_REDUCE_BLANKS      # Remove superfluous blanks
setopt HIST_VERIFY             # Show command with history expansion before running
setopt HIST_EXPIRE_DUPS_FIRST  # Expire duplicates first when trimming history

# Directory options
setopt AUTO_CD                 # Change directory without typing cd
setopt AUTO_PUSHD              # Push directories onto stack automatically
setopt PUSHD_IGNORE_DUPS       # Don't push duplicate directories
setopt PUSHD_SILENT            # Don't print directory stack after pushd/popd

# Completion options
setopt AUTO_LIST               # List choices on ambiguous completion
setopt AUTO_MENU               # Use menu completion after second tab
setopt LIST_PACKED             # Use variable column widths for completion
setopt COMPLETE_IN_WORD        # Complete from both ends of word
setopt ALWAYS_TO_END           # Move cursor to end of word after completion

# Correction options
setopt CORRECT                 # Correct commands
# setopt CORRECT_ALL           # Correct all arguments (can be annoying)

# Globbing options
setopt EXTENDED_GLOB           # Enable extended globbing
setopt GLOB_DOTS               # Include dotfiles in globbing
setopt NUMERIC_GLOB_SORT       # Sort numerically when possible

# Job control options
setopt AUTO_RESUME             # Resume jobs with their name
setopt LONG_LIST_JOBS          # List jobs in long format
setopt NOTIFY                  # Report status of background jobs immediately

# Input/Output options
setopt INTERACTIVE_COMMENTS    # Allow comments in interactive shells
setopt RC_QUOTES               # Allow 'Henry''s Garage' instead of 'Henry'\''s Garage'
setopt COMBINING_CHARS         # Combine zero-length punctuation characters

# Disable options that can be problematic
unsetopt BEEP                  # Disable beeping
unsetopt FLOW_CONTROL          # Disable flow control (Ctrl-S/Ctrl-Q)
unsetopt MENU_COMPLETE         # Don't autoselect first completion entry
unsetopt NOMATCH               # Don't error on no glob matches

# Key bindings mode
bindkey -e                     # Use emacs key bindings 