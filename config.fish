begin
    set --local AUTOJUMP_PATH $HOME/.autojump/share/autojump/autojump.fish
    if test -e $AUTOJUMP_PATH
        source $AUTOJUMP_PATH
    end
end

source ~/.asdf/asdf.fish

# aliases
source ~/.dotfiles/.aliases

fzf_key_bindings

starship init fish | source
zoxide init fish | source