# ZSH ZLE Widgets Reference

Complete reference of ZLE (Zsh Line Editor) widgets that can be bound to keys.

**Total Available:** 386 widgets  
**Usage:** `bindkey '<key-sequence>' <widget-name>`

---

## Table of Contents

1. [Movement](#movement)
2. [Editing](#editing)
3. [History](#history)
4. [Completion](#completion)
5. [Search](#search)
6. [Copy/Paste (Kill Ring)](#copypaste-kill-ring)
7. [Undo/Redo](#undoredo)
8. [Word Operations](#word-operations)
9. [Line Operations](#line-operations)
10. [Special Functions](#special-functions)
11. [Custom Widgets](#custom-widgets)

---

## Movement

### Character Movement
```zsh
.forward-char               # Move forward one character
.backward-char              # Move backward one character
bindkey '^F' forward-char   # Example: Ctrl+F
bindkey '^B' backward-char  # Example: Ctrl+B
```

### Word Movement
```zsh
.forward-word               # Move forward one word
.backward-word              # Move backward one word
.emacs-forward-word         # Emacs-style word movement (stops at punctuation)
.emacs-backward-word        # Emacs-style backward word movement
.vi-forward-word            # Vi-style word movement
.vi-backward-word           # Vi-style backward word movement

# Example bindings:
bindkey '^[f' forward-word        # Alt+f
bindkey '^[b' backward-word       # Alt+b
```

### Line Movement
```zsh
.beginning-of-line          # Move to start of line
.end-of-line                # Move to end of line
.beginning-of-line-hist     # Beginning of line, considering history
.end-of-line-hist           # End of line, considering history

# Example bindings:
bindkey '^A' beginning-of-line    # Ctrl+A
bindkey '^E' end-of-line          # Ctrl+E
```

### Buffer Movement
```zsh
.beginning-of-buffer-or-history  # Go to first line in buffer or history
.end-of-buffer-or-history        # Go to last line in buffer or history
```

### Line Navigation
```zsh
.up-line                    # Move up one line in multi-line buffer
.down-line                  # Move down one line in multi-line buffer
.up-line-or-history         # Up or previous history
.down-line-or-history       # Down or next history
.up-line-or-search          # Up or search in history
.down-line-or-search        # Down or search in history
```

---

## Editing

### Deletion
```zsh
.delete-char                # Delete character under cursor
.backward-delete-char       # Delete character before cursor (backspace)
.delete-char-or-list        # Delete char or show completion list
.delete-char-or-eof         # Delete char or exit on empty line

# Example bindings:
bindkey '^D' delete-char-or-eof
bindkey '^H' backward-delete-char
```

### Word Deletion
```zsh
.delete-word                # Delete word forward
.backward-delete-word       # Delete word backward
.kill-word                  # Kill word forward (save to kill ring)
.backward-kill-word         # Kill word backward (save to kill ring)

# Example bindings:
bindkey '^[d' delete-word         # Alt+d
bindkey '^W' backward-kill-word   # Ctrl+W
```

### Line Deletion
```zsh
.kill-line                  # Kill from cursor to end of line
.backward-kill-line         # Kill from cursor to beginning of line
.kill-whole-line            # Kill entire line
.kill-buffer                # Kill entire buffer

# Example bindings:
bindkey '^K' kill-line            # Ctrl+K
bindkey '^U' backward-kill-line   # Ctrl+U (or kill-whole-line)
```

### Character Operations
```zsh
.transpose-chars            # Swap character under cursor with previous
.transpose-words            # Swap current word with previous word

# Example binding:
bindkey '^T' transpose-chars      # Ctrl+T
```

### Case Operations
```zsh
.up-case-word               # Uppercase word
.down-case-word             # Lowercase word
.capitalize-word            # Capitalize word

# Example bindings:
bindkey '^[u' up-case-word        # Alt+u
bindkey '^[l' down-case-word      # Alt+l
bindkey '^[c' capitalize-word     # Alt+c
```

---

## History

### History Navigation
```zsh
.up-history                 # Previous command in history
.down-history               # Next command in history
.beginning-of-history       # Go to first history entry
.end-of-history             # Go to last history entry

# Example bindings:
bindkey '^P' up-history           # Ctrl+P
bindkey '^N' down-history         # Ctrl+N
```

### History Search
```zsh
.history-incremental-search-backward   # Search backward in history
.history-incremental-search-forward    # Search forward in history
.history-search-backward               # Search backward (non-incremental)
.history-search-forward                # Search forward (non-incremental)

# Example bindings:
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward
```

### History Line Operations
```zsh
.accept-line-and-down-history    # Accept and move to next history
.accept-and-hold                 # Accept but keep in editor
.accept-and-infer-next-history   # Accept and guess next command
.push-line                       # Push current line to buffer stack
.push-line-or-edit               # Push line or edit multi-line
.get-line                        # Retrieve pushed line

# Example bindings:
bindkey '^Q' push-line-or-edit
bindkey '^[g' get-line
```

---

## Completion

### Basic Completion
```zsh
.complete-word              # Perform completion
.expand-or-complete         # Expand or complete
.expand-or-complete-prefix  # Complete up to cursor
.menu-complete              # Menu completion (cycle through)
.reverse-menu-complete      # Reverse menu completion
.list-choices               # List completion choices
.delete-char-or-list        # Delete char or list completions

# Example bindings:
bindkey '^I' expand-or-complete       # Tab
bindkey '^[[Z' reverse-menu-complete  # Shift+Tab
bindkey '^D' delete-char-or-list
```

### Advanced Completion
```zsh
.accept-and-menu-complete   # Accept and continue menu
.menu-expand-or-complete    # Menu expansion
._complete_help             # Show completion help
._complete_tag              # Complete using tags
._correct_word              # Spelling correction
._expand_alias              # Expand aliases
._expand_word               # Expand word

# Example usage:
bindkey '^X?' _complete_help
```

---

## Search

### Incremental Search
```zsh
.history-incremental-search-backward
.history-incremental-search-forward
.history-incremental-pattern-search-backward
.history-incremental-pattern-search-forward

# Example bindings:
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward
```

### Pattern Search
```zsh
.history-pattern-search-backward
.history-pattern-search-forward
.history-beginning-search-backward    # Search with current prefix
.history-beginning-search-forward     # Search forward with prefix
```

---

## Copy/Paste (Kill Ring)

### Kill/Copy Operations
```zsh
.kill-line                  # Kill to end of line (save to kill ring)
.backward-kill-line         # Kill to beginning of line
.kill-whole-line            # Kill entire line
.kill-word                  # Kill word forward
.backward-kill-word         # Kill word backward
.copy-region-as-kill        # Copy region to kill ring
.copy-prev-word             # Copy previous word
.copy-prev-shell-word       # Copy previous shell word

# Example bindings:
bindkey '^K' kill-line
bindkey '^U' kill-whole-line
bindkey '^W' backward-kill-word
```

### Yank Operations
```zsh
.yank                       # Paste (yank) last killed text
.yank-pop                   # Replace yanked text with previous kill

# Example bindings:
bindkey '^Y' yank                     # Ctrl+Y
bindkey '^[y' yank-pop                # Alt+y
```

### Region Operations
```zsh
.set-mark-command           # Set mark for region
.exchange-point-and-mark    # Swap cursor and mark
.kill-region                # Kill region between mark and cursor
.copy-region-as-kill        # Copy region without killing

# Example bindings:
bindkey '^@' set-mark-command         # Ctrl+Space
bindkey '^X^X' exchange-point-and-mark
```

---

## Undo/Redo

```zsh
.undo                       # Undo last change
.redo                       # Redo undone change

# Example bindings:
bindkey '^_' undo                     # Ctrl+_ (Ctrl+/)
bindkey '^[_' redo                    # Alt+_
```

---

## Word Operations

### Word Manipulation
```zsh
.forward-word               # Move forward one word
.backward-word              # Move backward one word
.kill-word                  # Kill word forward
.backward-kill-word         # Kill word backward
.transpose-words            # Swap words
.up-case-word               # Uppercase word
.down-case-word             # Lowercase word
.capitalize-word            # Capitalize word

# Example bindings:
bindkey '^[f' forward-word
bindkey '^[b' backward-word
bindkey '^[d' kill-word
bindkey '^[t' transpose-words
```

---

## Line Operations

### Line Acceptance
```zsh
.accept-line                # Accept current line (execute)
.accept-line-and-down-history
.accept-and-hold            # Accept but keep editing
.accept-and-infer-next-history

# Example binding:
bindkey '^M' accept-line              # Enter
bindkey '^J' accept-line              # Ctrl+J
```

### Line Editing
```zsh
.push-line                  # Push line to stack
.push-line-or-edit          # Push or edit
.get-line                   # Retrieve pushed line
.push-input                 # Push input to history
.clear-screen               # Clear screen
.redisplay                  # Redraw line
.reset-prompt               # Reset prompt

# Example bindings:
bindkey '^L' clear-screen
bindkey '^[^L' redisplay
```

---

## Special Functions

### Command Execution
```zsh
.execute-named-cmd          # Execute named command (M-x style)
.execute-last-named-cmd     # Re-execute last named command
.send-break                 # Abort current operation
.run-help                   # Show help for current command
.which-command              # Show what command does

# Example bindings:
bindkey '^[x' execute-named-cmd       # Alt+x (like Emacs M-x)
bindkey '^[h' run-help                # Alt+h
```

### Expansion
```zsh
.expand-word                # Expand word (glob, etc)
.expand-cmd-path            # Expand command path
.expand-history             # Expand history (!!)
._expand_alias              # Expand aliases

# Example bindings:
bindkey '^[e' expand-word
bindkey '^X*' expand-word
```

### Miscellaneous
```zsh
.describe-key-briefly       # Show what key does
.where-is                   # Find key binding for widget
.self-insert                # Insert typed character
.quoted-insert              # Insert next character literally
.digit-argument             # Numeric argument
.neg-argument               # Negative argument
.universal-argument         # Universal argument (like Emacs C-u)

# Example bindings:
bindkey '^V' quoted-insert            # Ctrl+V
bindkey '^[1' digit-argument
bindkey '^U' universal-argument
```

### Editor
```zsh
.edit-command-line          # Edit line in $EDITOR
.visual-mode                # Enter visual selection mode
.visual-line-mode           # Visual line selection

# Example binding:
bindkey '^X^E' edit-command-line      # Ctrl+X Ctrl+E
```

---

## Custom Widgets

You can create your own widgets using ZLE:

```zsh
# Define a custom widget function
my-widget() {
    # $BUFFER contains the current line
    # $CURSOR is the cursor position
    # $LBUFFER is left of cursor
    # $RBUFFER is right of cursor
    
    LBUFFER="echo $LBUFFER"
    zle reset-prompt
}

# Register it as a widget
zle -N my-widget

# Bind it to a key
bindkey '^[e' my-widget
```

### Useful Custom Widget Examples

```zsh
# Insert sudo at beginning
sudo-command-line() {
    [[ -z $BUFFER ]] && zle up-history
    if [[ $BUFFER == sudo\ * ]]; then
        LBUFFER="${LBUFFER#sudo }"
    else
        LBUFFER="sudo $LBUFFER"
    fi
}
zle -N sudo-command-line
bindkey '^[s' sudo-command-line

# CD to git root
cd-git-root() {
    local root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        LBUFFER="cd '$root'"
        zle accept-line
    fi
}
zle -N cd-git-root
bindkey '^[r' cd-git-root

# Copy current command to clipboard
copy-command() {
    echo -n "$BUFFER" | xclip -selection clipboard
    echo "Copied!"
    zle reset-prompt
}
zle -N copy-command
bindkey '^[c' copy-command
```

---

## Key Sequence Notation

```zsh
^X      = Ctrl+X
^[x     = Alt+x (or Esc then x)
^^      = Ctrl+^ (Ctrl+Shift+6)
^?      = Backspace (sometimes)
^[[A    = Up arrow
^[[B    = Down arrow
^[[C    = Right arrow
^[[D    = Left arrow
^[[1;5C = Ctrl+Right arrow
^[[1;5D = Ctrl+Left arrow
^[[3~   = Delete key
^[[Z    = Shift+Tab
```

---

## Finding Widget Names

```zsh
# List all available widgets
zle -la

# Show current keybindings
bindkey

# Find what a key does
bindkey '^R'

# Show what key sequence was pressed
cat -v  # Then press keys (Ctrl+C to exit)

# Describe a key
bindkey -d '^X'  # (if describe-key-briefly is bound)
```

---

## Common Binding Patterns

### Emacs-Style
```zsh
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line
bindkey '^K' kill-line
bindkey '^U' kill-whole-line
bindkey '^W' backward-kill-word
bindkey '^Y' yank
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward
bindkey '^[f' forward-word
bindkey '^[b' backward-word
bindkey '^[d' kill-word
bindkey '^[<' beginning-of-buffer-or-history
bindkey '^[>' end-of-buffer-or-history
```

### Navigation Enhancement
```zsh
bindkey '^[[1;5C' forward-word        # Ctrl+Right
bindkey '^[[1;5D' backward-word       # Ctrl+Left
bindkey '^[[H' beginning-of-line      # Home
bindkey '^[[F' end-of-line            # End
```

### History Enhancement
```zsh
bindkey '^P' up-history
bindkey '^N' down-history
bindkey '^[[A' up-line-or-history     # Up arrow
bindkey '^[[B' down-line-or-history   # Down arrow
```

---

## Advanced: Widget Options

Some widgets support options:

```zsh
# Numeric arguments
# Press Alt+5 then a command to repeat 5 times
bindkey '^[1' digit-argument
bindkey '^[2' digit-argument
# etc...

# Universal argument (like Emacs C-u)
bindkey '^U' universal-argument
```

---

## References

- Official ZSH Documentation: `man zshzle`
- List all widgets: `zle -la`
- List current bindings: `bindkey`
- ZSH Line Editor Guide: http://zsh.sourceforge.net/Doc/Release/Zsh-Line-Editor.html

---

**Last Updated:** 2025-11-17  
**Your Current Configuration:** `~/.config/zsh/20-keybindings.zsh`
