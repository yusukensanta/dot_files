setopt EXTENDED_HISTORY          # Write the history file in the ":start:elapsed;command" format
setopt HIST_EXPIRE_DUPS_FIRST    # Expire duplicate entries first when trimming history
setopt HIST_IGNORE_DUPS          # Don't record an entry that was just recorded again
setopt HIST_IGNORE_ALL_DUPS      # Delete old recorded entry if new entry is a duplicate
setopt HIST_FIND_NO_DUPS         # Do not display a line previously found
setopt HIST_IGNORE_SPACE         # Don't record an entry starting with a space
setopt HIST_SAVE_NO_DUPS         # Don't write duplicate entries in the history file
setopt HIST_REDUCE_BLANKS        # Remove superfluous blanks before recording entry
setopt HIST_VERIFY               # Don't execute immediately upon history expansion
setopt EXTENDED_HISTORY
setopt HIST_VERIFY
setopt SHARE_HISTORY             # Share history between all sessions
HISTTIMEFORMAT="%F %T "

# Shell behavior
setopt AUTO_CD                   # Change directory without typing cd
setopt AUTO_PUSHD                # Push directories onto stack automatically
setopt PUSHD_IGNORE_DUPS         # Don't push duplicate directories
setopt GLOB_DOTS                 # Include dotfiles in glob patterns
setopt EXTENDED_GLOB             # Use extended globbing syntax
setopt NO_BEEP                   # No beeping
setopt INTERACTIVE_COMMENTS      # Allow comments in interactive shells
setopt PUSHD_SILENT
setopt PUSHD_TO_HOME
DIRSTACKSIZE=20
