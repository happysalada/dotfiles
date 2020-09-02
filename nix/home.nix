{ config, lib, pkgs, ... }:
{

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.username = "raphael";
  home.homeDirectory = "/Users/raphael";
  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "20.09";

  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  home.packages = with pkgs; [ 
    # utilities TODO figure out why it doesn't work with darwin.nix
    fzf
    exa
    ytop
    which
    git
    ripgrep
    tealdeer
    direnv
    # elixir related
    beam.packages.erlangR23.elixir_1_10
    nodejs-14_x
    yarn
    postgresql_12
    # rust
    rustup
    sccache
    cargo-edit
    cargo-deps
    wasm-pack
    rust-analyzer
    wrangler # deploy static sites with cloudflare
  ];

  nixpkgs.config = {
    allowUnfree = true;
    packageOverrides = pkgs: {
      neovim = pkgs.neovim.override {
        vimAlias = true;
      };
    };
  }; 

  news.display = "silent";

  programs.neovim = import ./programs/neovim.nix {pkgs=pkgs;};

  programs.alacritty = import ./programs/alacritty.nix;
  programs.git = import ./programs/git.nix;

  programs.tmux.enable = true;
  home.file.".tmux.conf".source = ../.tmux.conf;

  programs.direnv.enable = true;
  programs.direnv.enableNixDirenvIntegration = true;

  programs.fish = import ./programs/fish.nix {pkgs = pkgs;};

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
  };
  home.file."starship.toml".source = ../starship.toml;

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  home.file.".cargo/config.toml".source = ../config.cargo.toml;
  # programs.broot.enable = true;
  # programs.broot = {
  #   enable = true;
  #   enableFishIntegration = true;
  #   verbs = {
  #     "p" = { execution = ":parent"; };
  #     "edit" = { shortcut = "e"; execution = "$EDITOR {file}" ; };
  #     "create {subpath}" = { execution = "$EDITOR {directory}/{subpath}"; };
  #   };
  # };

  programs.ssh = import ./programs/ssh.nix ;
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