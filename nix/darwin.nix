{ config, pkgs, ... }:

{
  environment = {
    systemPackages = with pkgs; [
      home-manager
      openssl
      gnupg
      exa # better ls
      ytop # rust htop
      ripgrep # better grep
      tealdeer # terser man
      fd # rust find
      procs # rust process monitor
    ];
    shells = [ pkgs.fish ];
    variables = {
      EDITOR = "emacs";
      LANG = "en_US.UTF-8";
    };
    systemPath = [ /run/current-system/sw/bin ];
  };

  programs.nix-index.enable = true;
  programs.fish.enable = true;

  fonts = {
    enableFontDir = true;
    fonts = [ pkgs.fira-code ];
  };

  system.defaults = {
    NSGlobalDomain = {
      AppleKeyboardUIMode = 3;
      ApplePressAndHoldEnabled = false;
      InitialKeyRepeat = 10;
      KeyRepeat = 3;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
    };

    dock = {
      autohide = true;
      orientation = "bottom";
      showhidden = true;
      mru-spaces = false;
    };

    finder = {
      AppleShowAllExtensions = true;
      QuitMenuItem = true;
      FXEnableExtensionChangeWarning = false;
    };
  };

  system.defaults.trackpad = {
    Clicking = true;
    TrackpadThreeFingerDrag = true;
  };

  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToControl = false;

  networking = {
    dns = [ "45.90.28.43" "45.90.30.43" ]; # provided by nextdns
    knownNetworkServices = [
      "Wi-Fi"
      "Bluetooth PAN"
      "Thunderbolt Bridge"
      "NextDNS"
      "Tailscale Tunnel"
    ];
    hostName = "yt";
  };

  system.stateVersion = 4;

  nix = {
    useDaemon = true;
    package = pkgs.nixUnstable;
    maxJobs = 4;
    buildCores = 4;
    gc = {
      automatic = true;
      interval = {
        Hour = 24;
        Minute = 0;
      };
    };
  };

  nixpkgs.config = {
    allowUnfree = true;
    packageOverrides = pkgs: {
      nur = import (builtins.fetchTarball {
        url = "https://github.com/nix-community/NUR/archive/master.tar.gz";
        sha256 = "1c3rh7x8bql2m9xcn3kvdqng75lzzf6kpxb3m6knffyir0jcrfrh";
      }) { inherit pkgs; };
    };
  };

  users.users.raphael = {
    home = /Users/raphael;
    description = "Raphael megzari";
    shell = pkgs.fish;
  };

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services.nix-daemon.enable = true;
}
