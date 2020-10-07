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
      fd # improved find
      procs # process monitor
      nextdns # faster dns, `sudo nextdns config set -config "e42bf1"`
      # tailscale # vpn management # not supported on macos
      smartmontools # ssd health monitoring
    ];
    shells = [ pkgs.fish ];
    variables = {
      EDITOR = "emacs";
      LANG = "en_US.UTF-8";
    };
    systemPath = [ /run/current-system/sw/bin ];
  };

  programs = {
    nix-index.enable = true;
    fish.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };

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
    };

    dock = {
      autohide = true;
      mru-spaces = false;
    };

    finder = {
      AppleShowAllExtensions = true;
      QuitMenuItem = true;
      FXEnableExtensionChangeWarning = false;
    };

    trackpad = {
      Clicking = true;
      TrackpadThreeFingerDrag = true;
    };
  };

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
    # allow until openssl is updated
    permittedInsecurePackages = [ "openssl-1.0.2u" ];
  };

  users.users.raphael = {
    home = /Users/raphael;
    description = "Raphael megzari";
    shell = pkgs.fish;
  };

  services = {
    nix-daemon.enable = true;
    # smartd = { enable = true; }; # unavailable on macos
  };
}
