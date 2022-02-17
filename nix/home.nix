{ nixpkgs-review, agenix, nix-update, username, ... }:
{ pkgs, ... }:
{
  home = {
    inherit username;
    # This value determines the Home Manager release that your
    # configuration is compatible with. This helps avoid breakage
    # when a new Home Manager release introduces backwards
    # incompatible changes.
    #
    # You can update Home Manager without changing this value. See
    # the Home Manager release notes for a list of state version
    # changes in each release.
    stateVersion = "22.05";
    homeDirectory = /Users/raphael;

    # List packages installed in system profile. To search by name, run:
    # $ nix-env -qaP | grep wget
    packages = with pkgs; [
      # vlc # video player. does not compile on darwin
      element-desktop

      # elixir related
      beam.packages.erlangR24.elixir_1_12
      elixir_ls

      #db
      postgresql_13
      # dbeaver

      # rust
      sccache
      cargo-edit
      cargo-deps
      wasm-pack
      sqlx-cli
      cargo-audit
      cargo-outdated
      cargo-bloat
      cargo-cross
      rust-analyzer
      rust-bin.stable.latest.default

      # js
      nodePackages.prettier
      nodePackages.pnpm
      nodePackages.node2nix
      nodePackages.npm-check-updates
      nodePackages.svelte-language-server
      nodejs-16_x
      nodePackages.yarn
      yarn2nix

      # network
      mtr # network traffic
      # tcptrack # does not work on macos

      # nix
      nix-index
      nixpkgs-review.defaultPackage.x86_64-darwin
      agenix.defaultPackage.x86_64-darwin
      mix2nix
      jq
      editorconfig-checker
      nix-update.defaultPackage.x86_64-darwin
      nixpkgs-fmt
      rnix-lsp
      nix-tree

      # shell stuff
      nodePackages.bash-language-server
      shellcheck

      # keyboard dactyl 
      # clojure
      # leiningen

      # for qmk # enable when keyboard comes back                       
      # pkgsCross.avr.buildPackages.gcc                                 
      # pkgsCross.avr.buildPackages.binutils                            
      # arduino-cli                                                     
      # cargo-flash                                                    
      # cargo-embed                                                     
      # cargo-binutils                                                  

      # testing out
      zstd
      # blender # dep jemalloc failing
      remarshal
      comby
      tmate
      czkawka
      # zig
      worker-build
    ];

    file.".tmux.conf".source = ./config/.tmux.conf;
    file.".cargo/config.toml".source = ./config/cargo.toml;
  };

  news.display = "silent";

  programs = {
    alacritty = import ./programs/alacritty.nix;
    git = import ./programs/git.nix { inherit pkgs; };
    fish = import ./programs/fish.nix;
    ssh = import ./programs/ssh.nix;
    helix = import ./programs/helix.nix;

    tmux.enable = true;

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    zellij = {
      enable = true;
      settings = {
        pane_frames = false;
      };
    };

    starship = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        add_newline = false;
        package.disabled = true;
      };
    };

    nix-index = {
      enable = true;
      enableFishIntegration = true;
    };

    broot = {
      enable = true;
      enableFishIntegration = true;
      verbs = [
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

  };

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
