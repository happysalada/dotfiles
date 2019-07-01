#!/bin/bash
set -x

# `crontab -l` sez this runs every night at 3am
brew_update
yarn cache clean
clean_docker

asdf update
asdf plugin-update --all

rm -rf ~/.Trash/*
# XCODE is enormous
#   kill cache
rm -rf ~/Library/Caches/com.apple.dt.Xcode

# run backup
$HOME/.dotfiles/backup/backup.sh
echo "don't forget to run your physical backup !!!"
