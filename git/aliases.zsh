# Use `hub` as our git wrapper:
#   http://defunkt.github.com/hub/
hub_path=$(which hub)
if (( $+commands[hub] ))
then
  alias git=$hub_path
fi

# The rest of my fun git aliases
alias gl='git pull --prune'
alias glog="git log --graph --pretty=format:'%Cred%h%Creset %an: %s - %Creset %C(yellow)%d%Creset %Cgreen(%cr)%Creset' --abbrev-commit --date=relative"
alias gp='git push origin HEAD'
alias gpf='git push --force'
alias gd='git diff'
alias gc='git commit -Sam'
alias gco='git checkout'
alias gbc='git checkout -b'
alias grb='git branch -m'
alias gdb='git branch -D'
alias gcb='git copy-branch-name'
alias gb='git branch'
alias gs='git status -sb' # upgrade your git if -sb breaks for you. it's fun.
alias gac='git add -A && git commit -S -m'
alias grh='git reset --hard && git clean -f -d'
alias gcf='git diff --name-only --diff-filter=U'
alias gro= "grep -lr '<<<<<<<' . | xargs git checkout --ours"
alias grt= "grep -lr '<<<<<<<' . | xargs git checkout --theirs"
alias gmo= 'git merge -Xours'
alias gmt= 'git merge -Xtheirs'
alias gr='git remote -v'
alias git-nuke='git reset --hard && git clean -fd'
