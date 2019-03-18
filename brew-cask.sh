#!/bin/bash


# to maintain cask ....
#     brew update && brew upgrade brew-cask && brew cleanup && brew cask cleanup`


# Install native apps

brew install caskroom/cask/brew-cask
brew tap caskroom/versions

# daily
brew cask install flux

# dev
brew cask install vscode
brew cask install alacritty
brew cask install alfred

# backup
brew cask install borgbackup

# browser stuff
brew cask install firefox
brew cask install chrome

# less often
brew cask install vlc
brew cask install gpgtools
brew cask install qbittorent
brew cask install dynalist
brew cask install docker
brew cask install karabiner-elements
brew cask install macpass
brew cask install metabase
brew cask install virtualbox
brew cask install fantastical
brew cask install dash
brew cask anki
brew install popsql
echo "add canary mail"

# fonts
brew tap caskroom/fonts
brew cask install font-fira-code
brew cask install font-source-code-pro-for-powerline
brew cask install font-source-code-pro
brew cask install font-source-sans-pro
brew cask install font-source-serif-pro
brew cask install font-fontawesome
brew cask install font-awesome-terminal-fonts
brew cask install font-hack
brew cask install font-inconsolata-dz-for-powerline
brew cask install font-inconsolata-g-for-powerline
brew cask install font-inconsolata-for-powerline
brew cask install font-roboto-mono
brew cask install font-roboto-mono-for-powerline
brew cask install font-source-code-pro
