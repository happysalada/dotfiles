#!/bin/bash


# to maintain cask ....
#     brew update && brew upgrade brew-cask && brew cleanup && brew cask cleanup`


# Install native apps

brew install caskroom/cask/brew-cask
brew tap caskroom/versions

# daily
brew cask install flux

# window manager
brew cask install spectacle

# dev
brew cask install iterm2
brew cask install vscode
brew cask install alfred

# browser stuff
brew cask install firefox
brew cask install torbrowser
brew cask install chrome
brew cask install chromedriver

# less often
brew cask install disk-inventory-x
brew cask install vlc
brew cask install gpgtools
brew cask install transmission

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
