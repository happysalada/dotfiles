{ pkgs, ... }:
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

  programSettings = import ./programs { };
in {

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
      bottom # rust htop
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
      niv
    ];

    file.".tmux.conf".source = ../.tmux.conf;
    file.".cargo/config.toml".source = ../config.cargo.toml;

    # doom config
    file.".emacs.d/init.el".text = ''
      (load "default.el")
    '';
  };

  news.display = "silent";

  programs = {
    # Let Home Manager install and manage itself.
    home-manager = {
      enable = true;
      path = "$HOME/.dotfiles/nix/home.nix";
    };

    inherit (programSettings) alacritty git fish ssh;

    tmux.enable = true;

    direnv = {
      enable = true;
      enableFishIntegration = true;
      enableNixDirenvIntegration = true;
    };

    starship = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        add_newline = false;
        character.symbol = "|>";
        package.disabled = true;
      };
    };

    broot = {
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

    zoxide = {
      enable = true;
      enableFishIntegration = true;
    };

    password-store = {
      enable = true;
      settings = {
        PASSWORD_STORE_DIR = "$HOME/.password-store";
        PASSWORD_STORE_KEY = "raphael@megzari.com";
        PASSWORD_STORE_CLIP_TIME = "60";
      };
    };

    skim = {
      enable = true;
      enableFishIntegration = true;
    };

    mcfly = {
      enable = true;
      enableFishIntegration = true;
    };
  };

  # wait until spacevim comes around
  # programs.neovim = import ./programs/neovim.nix { pkgs = pkgs; };

  # programs.neomutt = { enable = true; }; try out sometime
  # https://github.com/neomutt/neomutt

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
