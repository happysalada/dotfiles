# update system
sudo pacman -Syyu

sudo pacman -S exa git ffmpeg ncdu rsync zsh zsh-completions tmux

chsh -s /usr/bin/zsh

# required for erlang/OTP
sudo pacman -S fop autoconf

# Applications
sudo pacman -S code alacritty docker vlc pass redshift
git clone https://github.com/happysalada/psswrds.git ~/.password-store


# fuzzy finder
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install

mkdir -p ~/code
# plugin manager for oh-my-zh
git clone https://github.com/zsh-users/antigen ~/code/antigen
# plugin for autosuggestions on the shell
git clone https://github.com/zsh-users/zsh-autosuggestions ~/code/zsh-autosuggestions

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

asdf plugin-add yarn 
asdf install yarn 1.17.3

asdf plugin-add postgres 
asdf install postgres 11.5

# symlinks
./symlink-setup.sh