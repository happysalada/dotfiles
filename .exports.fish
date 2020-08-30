# vscode as default
set -x EDITOR 'code'

# Don’t clear the screen after quitting a manual page
set -x MANPAGER "less -X"

# Prefer US English and use UTF-8
set -x LC_ALL "en_US.UTF-8"
set -x LANG en_US.UTF-8

# Erlang and Elixir shell history:
set -x ERL_AFLAGS "-kernel shell_history enabled"

set -x PKG_CONFIG_PATH $PKG_CONFIG_PATH /usr/local/opt/openssl/lib/pkgconfig

set PATH $PATH ~/.dotfiles/bin
set PATH $PATH /usr/local/bin
set PATH $PATH /usr/local/sbin
set PATH $PATH (yarn global bin)

# to be able to use clang
set -g fish_user_paths "/usr/local/opt/llvm/bin" $fish_user_paths
