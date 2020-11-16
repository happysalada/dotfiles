{ pkgs, ... }:

  doom-emacs = pkgs.callPackage (builtins.fetchTarball {
    url = "https://github.com/vlaci/nix-doom-emacs/archive/master.tar.gz";
  }) {
    doomPrivateDir = ./doom.d; # Directory containing your config.el init.el
    emacsPackagesOverlay = self: super: {
      magit-delta = super.magit-delta.overrideAttrs
        (esuper: { buildInputs = esuper.buildInputs ++ [ pkgs.git ]; });
    };
  };
in {
  environment = {
    systemPackages = with pkgs; [
      openssl
      gnupg
      exa # better ls
      ripgrep # better grep
      tealdeer # terser man
      fd # improved find
      procs # process monitor
      nextdns # faster dns
      # tailscale # vpn management # not supported on macos
      smartmontools # ssd health monitoring
      s3cmd # used for backups
      doom-emacs
      gitAndTools.delta # better git diff
    ];
    variables = {
      EDITOR = "emacsclient -c";
      LANG = "en_US.UTF-8";
    };
    darwinConfig = "$HOME/.dotfiles/nix/darwin.nix";
  };

  programs = {
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    fish.enable = true;
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
  };

  services = {
    nix-daemon.enable = true;
    # smartd = { enable = true; }; # unavailable on macos
  };
}
