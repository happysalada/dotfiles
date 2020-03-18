#!/bin/bash
set -x

# `crontab -l` sez this runs every night at 3am
yarn cache clean

brew cleanup -s
rm -rf "$(brew --cache)"

# XCODE is enormous
#   kill cache
rm -rf ~/Library/Caches/com.apple.dt.Xcode
