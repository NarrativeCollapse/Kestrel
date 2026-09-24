# Kestrel terminal bling for zsh; sourced from /etc/zshrc. Same as kestrel-bling.sh for bash.
# Opt out:  mkdir -p ~/.config/kestrel && touch ~/.config/kestrel/no-bling

[[ -o interactive ]] || return 0
[[ -e "${XDG_CONFIG_HOME:-$HOME/.config}/kestrel/no-bling" ]] && return 0

# Homebrew (zsh doesn't read /etc/profile.d in non-login shells). System tools stay first in PATH.
if [[ -z "${HOMEBREW_PREFIX:-}" && -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh | grep -Ev '\bPATH=')"
    export HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
    export PATH="${PATH}:${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin"
fi

if (( $+commands[eza] )); then
    alias ll='eza -l --icons=auto --group-directories-first'
    alias l.='eza -d .*'
    alias ls='eza'
    alias l1='eza -1'
fi
if (( $+commands[ug] )); then
    alias grep='ug' egrep='ug -E' fgrep='ug -F'
fi
(( $+commands[starship] )) && eval "$(starship init zsh)"
(( $+commands[atuin] )) && eval "$(atuin init zsh --disable-up-arrow)"
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
if (( $+commands[fastfetch] )); then
    alias fastfetch='fastfetch -c /usr/share/kestrel/fastfetch.jsonc'
    alias neofetch='fastfetch -c /usr/share/kestrel/fastfetch.jsonc'
fi
:
