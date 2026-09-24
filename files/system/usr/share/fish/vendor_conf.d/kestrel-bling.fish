# Kestrel terminal bling for fish (Homebrew env comes from ublue-brew.fish).
# Opt out:  mkdir -p ~/.config/kestrel; and touch ~/.config/kestrel/no-bling
status is-interactive; or exit
set -q XDG_CONFIG_HOME; and set -l cfg $XDG_CONFIG_HOME; or set -l cfg $HOME/.config
test -e $cfg/kestrel/no-bling; and exit

if type -q eza
    alias ll 'eza -l --icons=auto --group-directories-first'
    alias l. 'eza -d .*'
    alias ls eza
    alias l1 'eza -1'
end
if type -q ug
    alias grep ug
    alias egrep 'ug -E'
    alias fgrep 'ug -F'
end
type -q starship; and starship init fish | source
type -q atuin; and atuin init fish --disable-up-arrow | source
type -q zoxide; and zoxide init fish | source
if type -q fastfetch
    alias fastfetch 'fastfetch -c /usr/share/kestrel/fastfetch.jsonc'
    alias neofetch 'fastfetch -c /usr/share/kestrel/fastfetch.jsonc'
end
