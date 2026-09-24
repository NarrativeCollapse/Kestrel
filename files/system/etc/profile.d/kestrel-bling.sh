# shellcheck shell=bash
# Kestrel terminal bling: starship prompt, eza/ugrep aliases, atuin history, zoxide.
# Adapted from Bazzite's bling.sh (https://github.com/ublue-os/bazzite, Apache-2.0).
# Tools come from Homebrew (/usr/share/kestrel/Brewfile); anything missing is skipped.
# Opt out:  mkdir -p ~/.config/kestrel && touch ~/.config/kestrel/no-bling

[ -n "${BASH_VERSION:-}" ] || return 0
case $- in *i*) ;; *) return 0 ;; esac
[ "${KESTREL_BLING_SOURCED:-0}" = 1 ] && return 0
[ -e "${XDG_CONFIG_HOME:-$HOME/.config}/kestrel/no-bling" ] && return 0
KESTREL_BLING_SOURCED=1

# ls -> eza
if command -v eza >/dev/null 2>&1; then
    alias ll='eza -l --icons=auto --group-directories-first'
    alias l.='eza -d .*'
    alias ls='eza'
    alias l1='eza -1'
fi

# grep -> ugrep
if command -v ug >/dev/null 2>&1; then
    alias grep='ug'
    alias egrep='ug -E'
    alias fgrep='ug -F'
    alias xzgrep='ug -z'
    alias xzegrep='ug -zE'
    alias xzfgrep='ug -zF'
fi

# bash-preexec first: atuin needs it, and starship uses it when present.
if [ -n "${HOMEBREW_PREFIX:-}" ] && [ -f "${HOMEBREW_PREFIX}/etc/profile.d/bash-preexec.sh" ]; then
    # shellcheck disable=SC1091
    . "${HOMEBREW_PREFIX}/etc/profile.d/bash-preexec.sh"
fi
command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
# Ctrl+R searches history; Up arrow keeps its normal behaviour.
command -v atuin >/dev/null 2>&1 && eval "$(atuin init bash --disable-up-arrow)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"
:
