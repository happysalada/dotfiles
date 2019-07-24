#!/bin/bash

# Install command-line tools using Homebrew

# Make sure we’re using the latest Homebrew
brew update

# Upgrade any already-installed formulae
brew upgrade

# GNU core utilities (those that come with OS X are outdated)
brew install coreutils
brew install moreutils
# GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed
brew install findutils
# GNU `sed`, overwriting the built-in `sed`
brew install gnu-sed
brew install gnupg

# for embedded development (e.g. Nerves)
brew install fwup squashfs

# Bash 4
# Note: don’t forget to add `/usr/local/bin/bash` to `/etc/shells` before running `chsh`.
brew install bash

brew install bash-completion

# Install wget with IRI support
brew install wget

# z hopping around folders
brew install z

# required for erlang/OTP
# java is required for these dependencies
brew cask install java
brew install fop
brew install psqlodbc
brew install autoconf
brew install wxmac

# wrk for stress testing
brew install wrk

# better ls
brew install exa

# mtr - ping & traceroute. best.
brew install prettyping

# Install other useful binaries
brew install the_silver_searcher
#fuzzy finder
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install

brew install git
brew install imagemagick 
brew install pv
brew install rename
brew install tree
brew install zopfli
brew install ffmpeg

brew install terminal-notifier

brew install pidcat   # colored logcat guy

brew install ncdu # find where your diskspace went

brew install zsh
brew install zsh-completions
# change shell to zsh
sudo sh -c "echo $(which zsh) >> /etc/shells"
chsh -s $(/bin/zsh)
brew install tmux

# find out how many lines of code in a project
brew install tokei

# add fd to find files
# find all hidden env file including the ones ignored by git
# fd --hidden --no-ignore env
# find all files with md extensions
# fd -e md
# remove ds_store files
# fd '^*.DS_Store$' --hidden --no-ignore -x rm
brew install fd

brew install ripgrep

# Remove outdated versions from the cellar
brew cleanup
