#!/bin/bash
apt-get update -y
apt-get upgrade -y

apt-get install build-essential curl file git software-properties-common apt-transport-https wget ca-certificates
# a better ls
apt-get install exa
apt-get install bash-completion
# z linux equivalent
apt-get install fasd

#fuzzy finder
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install

# utilities
apt-get install ffmpeg
apt-get install ncdu
apt-get install rsync

# shell
apt-get install zsh
# no package zsh-completions on 18.04
apt-get install zsh-completions
sudo sh -c "echo $(which zsh) >> /etc/shells"
chsh -s /bin/zsh
mkdir -p ~/code
# plugin manager for oh-my-zh
git clone https://github.com/zsh-users/antigen ~/code/antigen
# plugin for autosuggestions on the shell
git clone https://github.com/zsh-users/zsh-autosuggestions ~/code/zsh-autosuggestions

# terminal
apt-get install tmux

# required for erlang/OTP
# java is required for these dependencies
apt-get install default-jdk
apt-get install fop
apt-get install erlang-odbc
apt-get install autoconf
apt-get install wx-common

# vscode 
wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main"
sudo apt update
sudo apt install code

# docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
sudo apt update
sudo apt install docker-ce


# enable security upgrades
apt-get install unattended-upgrades

vi /etc/apt/apt.conf.d/10periodic
# add the following
# APT::Periodic::Update-Package-Lists "1";
# APT::Periodic::Download-Upgradeable-Packages "1";
# APT::Periodic::AutocleanInterval "7";
# APT::Periodic::Unattended-Upgrade "1";

# apps
sudo apt-get install vlc
sudo apt-get install pass
git clone https://github.com/happysalada/psswrds.git ~/.password-store
sudo apt-get install redshift

# albert
sudo sh -c "echo 'deb http://download.opensuse.org/repositories/home:/manuelschneid3r/xUbuntu_18.04/ /' > /etc/apt/sources.list.d/home:manuelschneid3r.list"
sudo apt-get update
sudo apt-get install albert

# asdf
git clone https://github.com/asdf-vm/asdf.git ~/.asdf
cd ~/.asdf
git checkout "$(git describe --abbrev=0 --tags)"

asdf plugin-add elixir
asdf install elixir 1.9.1

asdf plugin-add erlang
asdf install erlang 22.0.7

asdf plugin-add nodejs
bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring
asdf install nodejs 12.8.0

asdf plugin-add rust 
asdf install rust 1.36.0
cargo install cargo-watch
cargo install diesel_cli --no-default --features "postgres sqlite" --force
cargo install cargo-edit
cargo install ruplacer
cargo install dua-cli
cargo install click
asdf reshim rust

asdf plugin-add yarn 
asdf install yarn 1.17.3

asdf plugin-add postgres 
asdf install postgres 11.5

# symlinks
./symlink-setup.sh