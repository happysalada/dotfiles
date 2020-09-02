{ config, pkgs, ... }:

{
  users.users.raphael = {
    home = "/Users/raphael";
    description = "Raphael megzari";
    shell = pkgs.fish;
  };

  environment.systemPackages = with pkgs; [
    home-manager
    wget
    coreutils
    openssl
    gnupg
  ];

  environment.shells = [ pkgs.fish ];

  programs.nix-index.enable = true;

  fonts.fonts = [
    pkgs.fira-code
  ];

  nixpkgs.config.allowUnfree = true;

  environment.darwinConfig = "Users/raphael/.dotfiles/nix/darwin.nix";

  system.defaults.NSGlobalDomain.AppleKeyboardUIMode = 3;
  system.defaults.NSGlobalDomain.ApplePressAndHoldEnabled = false;
  system.defaults.NSGlobalDomain.InitialKeyRepeat = 1;
  system.defaults.NSGlobalDomain.KeyRepeat = 1;
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

  system.defaults.trackpad.Clicking = false;
  system.defaults.trackpad.TrackpadThreeFingerDrag = true;

  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToControl = false;

  services.nix-daemon.enable = true;
  nix.useDaemon = true;
  programs.zsh.enable = true;
  system.stateVersion = 4;
  nix.maxJobs = 4;
  nix.buildCores = 4;
}