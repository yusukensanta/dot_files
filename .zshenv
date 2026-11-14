# Contents of the dot_files-managed block in ~/.zshenv (sync_to_host.sh
# merges this into the host's file between marker lines and leaves every
# other line alone — rustup, employer setup, etc. may live there too).
#
# zsh reads ~/.zshenv for every shell, interactive or not, before any other
# startup file after /etc/zshenv: keep it tiny and free of side effects.

# Debian/Ubuntu's /etc/zsh/zshrc runs a full `compinit` (including
# compaudit's security scan) before ~/.zshrc is even read. 03-completion.zsh
# runs its own cached compinit, so the global one is wasted work — measured
# 88ms -> 17ms average startup on WSL Ubuntu 24.04. Only Debian's file reads
# this variable, so it is a no-op elsewhere (e.g. macOS).
skip_global_compinit=1

# Start-of-startup timestamp for the "ZSH loaded in Nms" message at the end
# of .zshrc. Taken here (not in .zshrc) so the figure also covers the system
# startup files that run before .zshrc — the very cost that message would
# otherwise hide.
if [[ -o interactive ]]; then
    zmodload zsh/datetime
    typeset -gF _dotfiles_t0=$EPOCHREALTIME
fi
