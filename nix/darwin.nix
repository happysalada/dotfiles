{ pkgs, ... }:
{
  environment = {
    systemPackages = with pkgs; [
      exa # better ls
      ripgrep # better grep
      tealdeer # terser man
      fd # improved find
      procs # process monitor
      # tailscale # vpn management # not supported on macos
      smartmontools # ssd health monitoring
      bottom # a better top
      dua # a better du
      borgbackup # backup
      mdbook # for documentation sites
      oil # better shell language for scripts
      ion # rust shell
      gitAndTools.delta # better git diff
      gitui # terminal git ui
      sd # better sed
    ];
    variables = {
      EDITOR = "codium ";
      LANG = "en_US.UTF-8";
    };
    darwinConfig = "$HOME/.dotfiles/nix/darwin.nix";
  };

  programs = {
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    fish = {
      enable = true;
      useBabelfish = true;
      babelfishPackage = pkgs.babelfish;
    };
  };

  fonts = {
    enableFontDir = true;
    fonts = [ pkgs.fira-code ];
  };

  system.defaults = {
    NSGlobalDomain = {
      AppleMeasurementUnits = "Centimeters";
      AppleMetricUnits = 1;
      AppleShowScrollBars = "Automatic";
      AppleTemperatureUnit = "Celsius";
      AppleKeyboardUIMode = 3;
      ApplePressAndHoldEnabled = false;
      InitialKeyRepeat = 10;
      KeyRepeat = 3;
      _HIHideMenuBar = true;
    };

    dock = {
      autohide = true;
      mru-spaces = false;
      tilesize = 512;
    };

    finder = {
      AppleShowAllExtensions = true;
      QuitMenuItem = true;
      FXEnableExtensionChangeWarning = false;
    };

    trackpad = {
      Clicking = true;
      TrackpadThreeFingerDrag = true;
      TrackpadRightClick = true;
    };

    # Login and lock screen
    loginwindow = {
      GuestEnabled = false;
    };
  };

  networking = {
    dns = [
      # provided by nextdns
      "45.90.28.43"
      "45.90.30.43"
      # defaults
      "1.1.1.1"
      "8.8.8.8"
    ];
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
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
    maxJobs = 4;
    buildCores = 4;
    # - makes some builds fail midway
    # - takes more time to re-build something
    gc.automatic = false;
  };

  nixpkgs.config = {
    allowUnfree = true;
    # contentAddressedByDefault = true; # build fails for now
  };

  users = {
    nix.configureBuildUsers = true;
    users.raphael = {
      home = /Users/raphael;
      description = "Raphael megzari";
    };
  };

  services = {
    nix-daemon.enable = true;
    # smartd = { enable = true; }; # unavailable on macos
    # avahi.enable = true; # unavailable on macos

    # fails and clutters the logs
    # logs located at /var/log/system.log
    nextdns = {
      enable = false;
      arguments = [ "-config" "e42bf1" ];
    };
  };
}
