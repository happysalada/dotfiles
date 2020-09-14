{ config, pkgs, ... }:

{
  users.users.raphael = {
    home = "/Users/raphael";
    description = "Raphael megzari";
    shell = pkgs.fish;
  };

  environment = {
    systemPackages = with pkgs; [
      home-manager
      wget
      coreutils
      openssl
      gnupg
      fzf
      exa
      ytop
      which
      ripgrep
      tealdeer
      direnv
      zoxide
      fd # rust find
      procs # rust process monitor
    ];
    shells = [ pkgs.fish ];
    variables = { EDITOR = "code"; LANG = "en_US.UTF-8"; };
  };

  programs.nix-index.enable = true;

  fonts = {
    enableFontDir = true;
    fonts = [
      pkgs.fira-code
    ];
  };

  system.defaults.NSGlobalDomain.AppleKeyboardUIMode = 3;
  system.defaults.NSGlobalDomain.ApplePressAndHoldEnabled = false;
  system.defaults.NSGlobalDomain.InitialKeyRepeat = 10;
  system.defaults.NSGlobalDomain.KeyRepeat = 3;
  system.defaults.NSGlobalDomain.NSAutomaticCapitalizationEnabled = false;
  system.defaults.NSGlobalDomain.NSAutomaticDashSubstitutionEnabled = false;
  system.defaults.NSGlobalDomain.NSAutomaticPeriodSubstitutionEnabled = false;
  system.defaults.NSGlobalDomain.NSAutomaticQuoteSubstitutionEnabled = false;
  system.defaults.NSGlobalDomain.NSAutomaticSpellingCorrectionEnabled = false;
  system.defaults.NSGlobalDomain.NSNavPanelExpandedStateForSaveMode = true;
  system.defaults.NSGlobalDomain.NSNavPanelExpandedStateForSaveMode2 = true;

  system.defaults.dock.autohide = true;
  system.defaults.dock.orientation = "bottom";
  system.defaults.dock.showhidden = true;
  system.defaults.dock.mru-spaces = false;

  system.defaults.finder.AppleShowAllExtensions = true;
  system.defaults.finder.QuitMenuItem = true;
  system.defaults.finder.FXEnableExtensionChangeWarning = false;

  system.defaults.trackpad.Clicking = true;
  system.defaults.trackpad.TrackpadThreeFingerDrag = true;

  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToControl = false;

  services.nix-daemon.enable = true;
  system.stateVersion = 4;
  nix = {
    useDaemon = true;
    nixPath = [
      { darwin-config = "\$HOME/.nixpkgs/darwin-configuration.nix"; }
      "\$HOME/.nix-defexpr/channels"
    ];
    package = pkgs.nixUnstable;
    maxJobs = 4;
    buildCores = 4;
  };

  nixpkgs.config = {
    allowUnfree = true;
    packageOverrides = pkgs: {
      nur = import (builtins.fetchTarball {
        url = "https://github.com/nix-community/NUR/archive/master.tar.gz";
        sha256 = "1c3rh7x8bql2m9xcn3kvdqng75lzzf6kpxb3m6knffyir0jcrfrh";
      }) {
        inherit pkgs;
      };
    };
  };
}