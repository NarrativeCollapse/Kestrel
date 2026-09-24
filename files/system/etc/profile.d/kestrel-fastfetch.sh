# shellcheck shell=sh
# Kestrel's fastfetch banner (config adapted from Bazzite).
if command -v fastfetch >/dev/null 2>&1; then
    alias fastfetch='fastfetch -c /usr/share/kestrel/fastfetch.jsonc'
    alias neofetch='fastfetch -c /usr/share/kestrel/fastfetch.jsonc'
fi
