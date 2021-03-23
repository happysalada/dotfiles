{ pkgs, ... }:
{
  environment = {
    systemPackages = with pkgs; [
      openssl
      gnupg
      exa # better ls
      ripgrep # better grep
      tealdeer # terser man
      fd # improved find
      procs # process monitor
      # tailscale # vpn management # not supported on macos
      # smartmontools # ssd health monitoring
      s3cmd # used for backups

      borgbackup # backup

      mdbook # for documentation sites
    ];
    variables = {
      EDITOR = "emacs";
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
    extraOptions =
      "experimental-features = nix-command flakes"; # not working on macos
    maxJobs = 4;
    buildCores = 4;
    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
      interval = {
        Hour = 24;
        Minute = 0;
      };
    };
  };

  nixpkgs.config = {
    allowUnfree = true;
    packageOverrides = pkgs: {
      nur = import
        (builtins.fetchTarball {
          url = "https://github.com/nix-community/NUR/archive/master.tar.gz";
          sha256 = "1c3rh7x8bql2m9xcn3kvdqng75lzzf6kpxb3m6knffyir0jcrfrh";
        })
        { inherit pkgs; };
      # spacevim = pkgs.spacevim.override { spacevim_config = import ./programs/spacevim.nix; };
    };
    # allow until openssl is updated
    permittedInsecurePackages = [ "openssl-1.0.2u" ];
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

    nextdns = {
      enable = true;
      arguments = [ "-config" "e42bf1" ];
    };
  };
}
