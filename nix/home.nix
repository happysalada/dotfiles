{ nixpkgs-update, nixpkgs-review, agenix }:
{ pkgs, ... }:
let programSettings = import ./programs { };
in
{
  home = {
    username = "raphael";
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
    packages = with pkgs; [
      gitAndTools.delta # better git diff
      # vlc # video player. does not compile on darwin

      # dev
      bottom # rust htop
      # elixir related
      beam.packages.erlangR23.elixir_1_11

      #db
      postgresql_13
      dbeaver

      # rust
      rustup
      sccache
      cargo-edit
      cargo-deps
      wasm-pack
      rust-analyzer
      sqlx-cli # broken on darwin for no
      # cargo-tarpaulin # code coverage # not supported on darwin

      wrangler # deploy static sites with cloudflare
      # js
      nodePackages.prettier
      nodePackages.pnpm
      nodejs-15_x

      # network
      mtr # network traffic
      # tcptrack # does not work on macos

      # nix
      nodePackages.node2nix
      nixpkgs-fmt
      nix-index
      nixpkgs-update.defaultPackage.x86_64-darwin
      nixpkgs-review.defaultPackage.x86_64-darwin
      agenix.defaultPackage.x86_64-darwin

      # keyboard dactyl stuff
      clojure
      # jdk # some dependency has zulu
      leiningen
      # for qmk
      pkgsCross.avr.buildPackages.gcc
      pkgsCross.avr.buildPackages.binutils

      # zig
    ];

    file.".tmux.conf".source = ../.tmux.conf;
    file.".cargo/config.toml".source = ../config.cargo.toml;
  };

  news.display = "silent";

  programs = {
    inherit (programSettings) alacritty fish ssh;
    git = import ./programs/git.nix { inherit pkgs; };

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
      verbs = [
        {
          invocation = "p";
          execution = ":parent";
        }
        {
          invocation = "edit";
          shortcut = "e";
          execution = "$EDITOR {file}";
        }
        {
          invocation = "create {subpath}";
          execution = "$EDITOR {directory}/{subpath}";
        }
      ];
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

  # programs.neovim = import ./programs/neovim.nix { pkgs = pkgs; };

  # programs.neomutt = { enable = true; }; try out sometime
  # https://github.com/neomutt/neomutt

  # not supported on darwin
  # programs.firefox = {
  #   enable = true;
  #   # install https://github.com/nix-community/NUR first
  #   # extensions = with pkgs.nur.repos.rycee.firefox-addons; [
  #   #   https-everywhere
  #   #   privacy-badger
  #   # ];
  # };

}
