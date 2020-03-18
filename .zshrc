# uncomment to profile prompt startup with zprof
# zmodload zsh/zprof

# history
SAVEHIST=100000

# Automatically list directory contents on `cd`.
auto-ls () {
  emulate -L zsh;
  # explicit sexy ls'ing as aliases arent honored in here.
  exa --reverse --sort=size --all --header --long
}
chpwd_functions=( auto-ls $chpwd_functions )

# history mgmt
# http://www.refining-linux.org/archives/49/ZSH-Gem-15-Shared-history/
setopt inc_append_history
setopt share_history
# ignore commands prefixed with a space. Will still persist for one command
setopt HIST_IGNORE_SPACE

zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# uncomment to finish profiling
# zprof

#fzf related
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
fzf-history-widget-accept() {
  fzf-history-widget
  zle accept-line
}

zle     -N     fzf-history-widget-accept
bindkey '^X^R' fzf-history-widget-accept

# Load our dotfiles like ~/.bash_prompt, etc…
#   ~/.extra can be used for settings you don’t want to commit,
#   Use it to configure your PATH, thus it being first in line.
for file in ~/.{extra,exports,aliases,functions}; do
    [ -r "$file" ] && source "$file"
done
unset file
