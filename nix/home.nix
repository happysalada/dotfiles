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
    fzf
    exa
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
  # programs.broot = {
  #   enable = true;
  #   enableFishIntegration = true;
  #   verbs = {
  #     "p" = { execution = ":parent"; };
  #     "edit" = { shortcut = "e"; execution = "$EDITOR {file}" ; };
  #     "create {subpath}" = { execution = "$EDITOR {directory}/{subpath}"; };
  #   };
  # };

  programs.ssh = {
    enable = true;
    extraOptionOverrides = {
      Include = "~/.dotfiles/ssh.config";
    };
    controlMaster = "auto";
    controlPath = "~/.ssh/control/%r@%h:%p";
    controlPersist = "5m";
    compression = true;
    matchBlocks."*" = {
      extraOptions = {
        UseRoaming = "no";
        KexAlgorithms =
          "curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256";
        HostKeyAlgorithms =
          "ssh-ed25519-cert-v01@openssh.com,ssh-rsa-cert-v01@openssh.com,ssh-ed25519,ssh-rsa";
        Ciphers =
          "chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr";
        PubkeyAuthentication = "yes";
        MACs =
          "hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com";
        PasswordAuthentication = "no";
        ChallengeResponseAuthentication = "no";
        # UseKeychain = "yes";
        AddKeysToAgent = "yes";
        identityFile = "~/.ssh/id_rsa";
      };
    };

    matchBlocks.union = {
      hostname = "136.243.134.16";
      identityFile = "~/.ssh/hetzner";
    };
    matchBlocks.github = {
      hostname = "github.com";
      identityFile = "~/.ssh/github";
    };
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