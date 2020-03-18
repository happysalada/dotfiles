# vscode as default
set EDITOR 'code'

# your project folder that we can `c [tab]` to
set PROJECTS ~/Documents/Projects

# Don’t clear the screen after quitting a manual page
set MANPAGER "less -X"

# Prefer US English and use UTF-8
set LC_ALL "en_US.UTF-8"
set LANG en_US.UTF-8

# Erlang and Elixir shell history:
set ERL_AFLAGS "-kernel shell_history enabled"

set PKG_CONFIG_PATH $PKG_CONFIG_PATH /usr/local/opt/openssl/lib/pkgconfig

set PATH $PATH /usr/sbin
set PATH $PATH /usr/local/bin
set PATH $PATH /bin
set PATH $PATH /usr/local/sbin
set PATH $PATH ~/.dotfiles/bin