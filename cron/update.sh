#!/bin/bash
brew -v update
brew upgrade
brew cask upgrade

asdf update
asdf plugin-update --all

~/.dotfiles/cargo_installs.sh