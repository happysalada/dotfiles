source ~/.asdf/asdf.fish

# aliases
source ~/.dotfiles/.aliases

fzf_key_bindings

source ~/.dotfiles/.extra.fish
source ~/.dotfiles/.exports.fish
source ~/.aliases

starship init fish | source
zoxide init fish | source