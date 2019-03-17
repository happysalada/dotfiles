# uncomment to profile prompt startup with zprof
# zmodload zsh/zprof

# history
SAVEHIST=100000

source ~/code/z/z.sh

# antigen time!
source ~/code/antigen/antigen.zsh

source ~/code/zsh-autosuggestions/zsh-autosuggestions.zsh

######################################################################
### install some antigen bundles

antigen use oh-my-zsh

antigen bundles <<EOBUNDLES
  # Guess what to install when running an unknown command.
  command-not-found

  # Helper for extracting different types of archives.
  extract

  # Tracks your most used directories, based on 'frecency'.
  robbyrussell/oh-my-zsh plugins/z

  # nicoulaj's moar completion files for zsh -- not sure why disabled.
  zsh-users/zsh-completions src

  # Syntax highlighting on the readline
  zsh-users/zsh-syntax-highlighting

  # history search
  zsh-users/zsh-history-substring-search ./zsh-history-substring-search.zsh

  # colors for all files!
  trapd00r/zsh-syntax-highlighting-filetypes

  # dont set a theme, because pure does it all
  mafredri/zsh-async
  sindresorhus/pure
EOBUNDLES

# Tell antigen that you're done.
antigen apply

###
#################################################################################################
export PURE_GIT_UNTRACKED_DIRTY=0

# Automatically list directory contents on `cd`.
auto-ls () {
  emulate -L zsh;
  # explicit sexy ls'ing as aliases arent honored in here.
  exa --reverse --sort=size --all --header --long
  # hash gls >/dev/null 2>&1 && CLICOLOR_FORCE=1 gls -aFh --color --group-directories-first || ls
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

. $HOME/.asdf/asdf.sh
. $HOME/.asdf/completions/asdf.bash

# Load our dotfiles like ~/.bash_prompt, etc…
#   ~/.extra can be used for settings you don’t want to commit,
#   Use it to configure your PATH, thus it being first in line.
for file in ~/.{extra,exports,aliases,functions}; do
    [ -r "$file" ] && source "$file"
done
unset file
