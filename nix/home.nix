{ config, lib, pkgs, ... }:
let
  doom-emacs = pkgs.callPackage (builtins.fetchTarball {
    url = "https://github.com/vlaci/nix-doom-emacs/archive/master.tar.gz";
  }) {
    doomPrivateDir = ./doom.d; # Directory containing your config.el init.el
    emacsPackagesOverlay = self: super: {
      magit-delta = super.magit-delta.overrideAttrs
        (esuper: { buildInputs = esuper.buildInputs ++ [ pkgs.git ]; });
    };
  };

  unstable = import <nixpkgs-unstable> { };
in {

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home = {
    username = "raphael";
    homeDirectory = "/Users/raphael";
    # This value determines the Home Manager release that your
    # configuration is compatible with. This helps avoid breakage
    # when a new Home Manager release introduces backwards
    # incompatible changes.
    #
    # You can update Home Manager without changing this value. See
    # the Home Manager release notes for a list of state version
    # changes in each release.
    stateVersion = "20.09";

    # List packages installed in system profile. To search by name, run:
    # $ nix-env -qaP | grep wget
    packages = with unstable; [
      doom-emacs # editor
      gitAndTools.delta # fancy diffs
      # vlc # video player. does not compile on darwin

      # dev
      # elixir related
      beam.packages.erlangR23.elixir_1_10
      nodejs-14_x
      yarn
      postgresql_13
      # rust
      rustup
      sccache
      # cargo-edit # build fails on macos for now
      cargo-deps
      wasm-pack
      rust-analyzer
      wrangler # deploy static sites with cloudflare

      mdbook # for documentation sites

      nixfmt
    ];
  };

  # doom config
  home.file.".emacs.d/init.el".text = ''
    (load "default.el")
  '';

  news.display = "silent";

  # wait until spacevim comes around
  # programs.neovim = import ./programs/neovim.nix { pkgs = pkgs; };

  programs.alacritty = import ./programs/alacritty.nix;
  programs.git = import ./programs/git.nix;

  programs.tmux.enable = true;
  home.file.".tmux.conf".source = ../.tmux.conf;

  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
    enableNixDirenvIntegration = true;
  };

  programs.fish = import ./programs/fish.nix { pkgs = pkgs; };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
  };
  home.file.".config/starship.toml".source = ../starship.toml;

  home.file.".cargo/config.toml".source = ../config.cargo.toml;
  programs.broot = {
    enable = true;
    enableFishIntegration = true;
    verbs = {
      "p" = { execution = ":parent"; };
      "edit" = {
        shortcut = "e";
        execution = "$EDITOR {file}";
      };
      "create {subpath}" = { execution = "$EDITOR {directory}/{subpath}"; };
    };
  };

  programs.ssh = import ./programs/ssh.nix;

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.password-store = {
    enable = true;
    settings = {
      PASSWORD_STORE_DIR = "$HOME/.password-store";
      PASSWORD_STORE_KEY = "raphael@megzari.com";
      PASSWORD_STORE_CLIP_TIME = "60";
    };

  };

  programs.skim = {
    enable = true;
    enableFishIntegration = true;
  };

  # somehow firefox says not supported
  # programs.firefox = {
  #   enable = true;
  #   # install https://github.com/nix-community/NUR first
  #   # extensions = with pkgs.nur.repos.rycee.firefox-addons; [
  #   #   https-everywhere
  #   #   privacy-badger
  #   # ];
  # };

}
