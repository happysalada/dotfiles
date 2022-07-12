{ home-manager, agenix, rust-overlay, }:
[
  ({ pkgs, ... }:
    {
      environment = {
        systemPackages = with pkgs; [
          mdbook # for documentation sites
          ion # rust shell
        ];
        variables = {
          EDITOR = "hx ";
          LANG = "en_US.UTF-8";
        };
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
          # defaults
          "1.1.1.1"
          "8.8.8.8"
        ];
        knownNetworkServices = [
          "Wi-Fi"
          "Bluetooth PAN"
          "Thunderbolt Bridge"
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
        maxJobs = 40;
        buildCores = 40;
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
        users.yt = {
          home = /Users/yt;
        };
      };

      services = {
        nix-daemon.enable = true;
      };
    })
  agenix.nixosModules.age
  {
    nixpkgs.overlays = [ rust-overlay.overlays.default ];
  }
  # `home-manager` module
  home-manager.darwinModules.home-manager
  {
    # `home-manager` config
    home-manager.useGlobalPkgs = true;
    home-manager.users.yt = ({ pkgs, ... }: {
      home = {
        username = "yt";
        # This value determines the Home Manager release that your
        # configuration is compatible with. This helps avoid breakage
        # when a new Home Manager release introduces backwards
        # incompatible changes.
        #
        # You can update Home Manager without changing this value. See
        # the Home Manager release notes for a list of state version
        # changes in each release.
        stateVersion = "22.05";
        homeDirectory = /Users/yt;

        # List packages installed in system profile. To search by name, run:
        # $ nix-env -qaP | grep wget
        packages = with pkgs; [
          # vlc # video player. does not compile on darwin

          #db
          postgresql_13
          # dbeaver

          # network
          mtr # network traffic
          # tcptrack # does not work on macos

          # shell stuff
          nodePackages.bash-language-server
          shellcheck


          # testing out
          remarshal
          comby
          # zig

        ] ++
        (import ../packages/basic_cli_set.nix { inherit pkgs; }) ++
        (import ../packages/dev/rust.nix { inherit pkgs; }) ++
        (import ../packages/dev/js.nix { inherit pkgs; }) ++
        (import ../packages/offensive.nix { inherit pkgs; }) ++
        (import ../packages/dev/nix.nix { inherit pkgs; });

        file.".cargo/config.toml".source = ../config/cargo.toml;
      };
      news.display = "silent";
      programs = import ../homes/common.nix { inherit pkgs; } //
        import ./overrides.nix;
    });
  }
]
