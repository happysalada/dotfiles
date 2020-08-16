source ~/.asdf/asdf.fish
source ~/.dotfiles/.exports.fish
source ~/.dotfiles/.aliases

fzf_key_bindings

abbr -a m make
abbr -a br broot

starship init fish | source
zoxide init fish | source