#!/bin/bash
set -x

# `crontab -l` sez this runs every night at 3am
brew_update
yarn cache clean

asdf update
asdf plugin-update --all

# XCODE is enormous
#   kill cache
rm -rf ~/Library/Caches/com.apple.dt.Xcode

# run backup
echo "RUN YOUR BACKUP PLEASE"
