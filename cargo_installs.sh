#!/bin/bash
cargo install cargo-watch
cargo install diesel_cli --no-default-features --features "postgres sqlite"
cargo install cargo-edit
cargo install ruplacer
cargo install dua-cli
cargo install click
# jump into directories
cargo install zoxide
cargo install cargo-generate
# better find
cargo install fd-find
# better ls
cargo install exa
# shell prompt
cargo install starship
# deploy static sites
cargo install wrangler
# fzf like (no key bindings yet but want to use in the future)
cargo install skim
# process info
cargo install --git https://github.com/cjbassi/ytop ytop