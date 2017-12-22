# uncomment to profile prompt startup with zprof
# zmodload zsh/zprof

# history
SAVEHIST=100000

source ~/code/z/z.sh

# antigen time!
source ~/code/antigen/antigen.zsh

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

  # suggestions
  tarruda/zsh-autosuggestions

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



# bind UP and DOWN arrow keys for history search
zmodload zsh/terminfo
bindkey "$terminfo[kcuu1]" history-substring-search-up
bindkey "$terminfo[kcud1]" history-substring-search-down

export PURE_GIT_UNTRACKED_DIRTY=0

# Automatically list directory contents on `cd`.
auto-ls () {
  emulate -L zsh;
  # explicit sexy ls'ing as aliases arent honored in here.
  hash gls >/dev/null 2>&1 && CLICOLOR_FORCE=1 gls -aFh --color --group-directories-first || ls
}
chpwd_functions=( auto-ls $chpwd_functions )


# Enable autosuggestions automatically
zle-line-init() {
    zle autosuggest-start
}

zle -N zle-line-init


# history mgmt
# http://www.refining-linux.org/archives/49/ZSH-Gem-15-Shared-history/
setopt inc_append_history
setopt share_history


zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'


# uncomment to finish profiling
# zprof

eval "$(rbenv init -)"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Load our dotfiles like ~/.bash_prompt, etc…
#   ~/.extra can be used for settings you don’t want to commit,
#   Use it to configure your PATH, thus it being first in line.
for file in ~/.{extra,exports,aliases,functions}; do
    [ -r "$file" ] && source "$file"
done
unset file
