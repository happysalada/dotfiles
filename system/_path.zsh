export PATH="/usr/local/Cellar:./bin:/usr/local/bin:/usr/sbin:/Applications:$ZSH/bin:$PATH:$(yarn global bin):/Users/${USER}/Library/Android/sdk/platform-tools"
export MANPATH="/usr/local/man:/Applications:/usr/local/git/man:$MANPATH"
export MONGOPATH="/Applications:/usr/local/Caskroom/mongodb:$MONGOPATH"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Applications/google-cloud-sdk/path.zsh.inc' ]; then source '/Applications/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Applications/google-cloud-sdk/completion.zsh.inc' ]; then source '/Applications/google-cloud-sdk/completion.zsh.inc'; fi
