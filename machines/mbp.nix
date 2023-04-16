{ home-manager, agenix, rust-overlay, alejandra }:
[
  ({ pkgs, ... }:
    {
      environment = {
        variables = {
          EDITOR = "hx";
          LANG = "en_US.UTF-8";
        };
      };

      programs = {
        gnupg.agent = {
          enable = true;
          enableSSHSupport = true;
        };
      };

      fonts = {
        fontDir.enable = true;
        fonts = import ../packages/fonts.nix { inherit pkgs; };
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
          NSAutomaticWindowAnimationsEnabled = false;
        };

        dock = {
          autohide = true;
          mru-spaces = false;
          tilesize = 512;
          expose-animation-duration = 0.1;
          autohide-time-modifier = 0.1;
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
        package = pkgs.nixUnstable;
        extraOptions = ''
          experimental-features = nix-command flakes
          keep-outputs = true
          keep-derivations = true
          builders-use-substitutes = true
        '';
        configureBuildUsers = true;
        settings = {
          max-jobs = 4;
          cores = 4;
        };
        # - makes some builds fail midway
        # - takes more time to re-build something
        gc.automatic = false;
      };

      nixpkgs.config = {
        allowUnfree = true;
        # contentAddressedByDefault = true; # build fails for now
      };

      users = {
        users.raphael = {
          home = /Users/raphael;
          shell = with pkgs; [ nushell ];
        };
      };

      services = {
        nix-daemon.enable = true;
        # smartd = { enable = true; }; # unavailable on macos
        # avahi.enable = true; # unavailable on macos
      };
    })
  agenix.nixosModules.age
  {
    nixpkgs.overlays = [ rust-overlay.overlays.default ];
    age.secrets =  {
      NU_ENV = {
        file = ../secrets/env.nu.age;
      };
    };
  }
  # `home-manager` module
  home-manager.darwinModules.home-manager
  {
    # `home-manager` config
    home-manager.useGlobalPkgs = true;
    home-manager.users.raphael = ({ pkgs, config, ... }: {
      home = {
        username = "raphael";
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

          #db
          postgresql_15
          # dbeaver

          # network
          mtr # network traffic
          # tcptrack # does not work on macos

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
          # blender # dep jemalloc failing
          remarshal
          # comby # use in a shell when needed, very heavy
          tmate
          # zig
          # openscad # fails to build on darwin
          youtube-dl

          # machine specific
          agenix.packages.x86_64-darwin.default
          alejandra.packages.x86_64-darwin.default
      ] ++
        (import ../packages/basic_cli_set.nix { inherit pkgs; }) ++
        (import ../packages/dev/rust.nix { inherit pkgs; }) ++
        (import ../packages/dev/js.nix { inherit pkgs; }) ++
        (import ../packages/offensive.nix { inherit pkgs; }) ++
        (import ../packages/crypto.nix { inherit pkgs; }) ++
        (import ../packages/dev/nix.nix { inherit pkgs; });

        file.".cargo/config.toml".source = ../config/cargo.toml;
      };
      news.display = "silent";
      programs = import ../homes/common.nix { inherit pkgs; } //
        { vscode = import ../homes/programs/vscodium.nix { inherit pkgs; }; } //
        { git = import ../homes/programs/git.nix { inherit pkgs; }; };
    });
  }
]
