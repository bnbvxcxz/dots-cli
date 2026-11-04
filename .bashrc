eval "$(oh-my-posh init bash --config $HOME/.config/ohmyposh/zen.toml)"

# kitty ssh fix
[ "$TERM" = "xterm-kitty" ] && alias ssh="kitty +kitten ssh"


# run package manager binaries
export PATH="/usr/lib/ccache/bin/:$PATH"
export PATH=$PATH:~/.cargo/bin/
export PATH=$PATH:~/.local/bin/
