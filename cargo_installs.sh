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
cargo install wrangle
# process info
cargo install -f --git https://github.com/cjbassi/ytop ytop