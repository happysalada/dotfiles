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
brew install gnu-sed --with-default-names

# for embedded development (e.g. Nerves)
brew install fwup squashfs

# Bash 4
# Note: don’t forget to add `/usr/local/bin/bash` to `/etc/shells` before running `chsh`.
brew install bash

brew install bash-completion

brew install homebrew/completions/brew-cask-completion

# Install wget with IRI support
brew install wget --with-iri

# Install more recent versions of some OS X tools
brew install homebrew/dupes/nano
brew install homebrew/dupes/grep
brew install homebrew/dupes/openssh
brew install homebrew/dupes/screen

# z hopping around folders
brew install z

# run this script when this file changes guy.
brew install entr

# required for erlang/OTP
brew install fop
brew install psqlodbc

# wrk for stress testing
brew install wrk

# mtr - ping & traceroute. best.
brew install prettyping

# Install other useful binaries
brew install the_silver_searcher
#fuzzy finder
brew install fzf

brew install git
brew install imagemagick --with-webp
brew install pv
brew install rename
brew install tree
brew install zopfli
brew install ffmpeg --with-libvpx

brew install terminal-notifier

brew install pidcat   # colored logcat guy

brew install ncdu # find where your diskspace went

brew install zsh
brew install yarn --without-node
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

# editor
brew install emacs --with-cocoa
git clone https://github.com/syl20bnr/spacemacs ~/.emacs.d

brew install vscode

# Remove outdated versions from the cellar
brew cleanup
