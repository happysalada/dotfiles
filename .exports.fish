# vscode as default
set -x EDITOR 'code'

# your project folder that we can `c [tab]` to
set -x PROJECTS ~/Documents/Projects

# Don’t clear the screen after quitting a manual page
set -x MANPAGER "less -X"

# Prefer US English and use UTF-8
set -x LC_ALL "en_US.UTF-8"
set -x LANG en_US.UTF-8

# Erlang and Elixir shell history:
set -x ERL_AFLAGS "-kernel shell_history enabled"

set -x PKG_CONFIG_PATH $PKG_CONFIG_PATH:/usr/local/opt/openssl/lib/pkgconfig
set -x PKG_CONFIG_PATH $PKG_CONFIG_PATH:/usr/local/opt/openssl/lib/pkgconfig