{ home-manager, agenix, rust-overlay }:
[
  ({ pkgs, config, ... }:
    {
      imports = [
        agenix.darwinModules.age
      ];
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
          KeyRepeat = 1;
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
          # Quad 9
          "9.9.9.9"
          "149.112.112.112"
          # opendns
          "208.67.222.222"
          "208.67.220.220"
          # cloudflare
          "1.1.1.1"
          "1.0.0.1"
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
          connect-timeout = 5
          log-lines = 25
          min-free = 128000000 # 128 MB
          max-free = 1000000000 # 1 GB
          # auto-optimise-store = true # doesn't work on macos for now
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

      nixpkgs = {
        overlays = [
          rust-overlay.overlays.default
          # helix.overlays.default
          # deploy-rs.overlay
          # (self: super: {
          #   copilot-lsp = super.pkgs.stdenv.mkDerivation {
          #     pname = "copilot-lsp";
          #     version = "0.0.1";
          #     src = copilot-lsp-src;              
          #     nativeBuildInputs = [ super.pkgs.makeWrapper ];
          #     dontConfigure = true;
          #     dontBuild = true;
          #     installPhase = ''
          #       mkdir -p $out
          #       cp $src/copilot/dist/* $out
          #       makeWrapper '${super.pkgs.nodejs}/bin/node' "$out/copilot" \
          #         --add-flags "$out/agent.js"
          #     '';
          #   };
          # })
        ];
        config = {
          allowUnfree = true;
          # contentAddressedByDefault = true; # build fails for now
        };
      };

      users = {
        users.raphael = {
          home = /Users/raphael;
          shell = with pkgs; [ nushellFull ];
        };
      };


      services = {
        nix-daemon.enable = true;
        # smartd = { enable = true; }; # unavailable on macos
        # avahi.enable = true; # unavailable on macos
      };
    })
  home-manager.darwinModules.home-manager
  {
    # `home-manager` config
    home-manager.useGlobalPkgs = true;
    home-manager.users.raphael = ({ pkgs, config, lib, ... }: {
      imports = [
        agenix.homeManagerModules.age
        {
          config.programs.nushell.environmentVariables = {
            OPENAI_API_KEY = "(open $'(getconf DARWIN_USER_TEMP_DIR)/agenix/OPENAI_API_KEY')";
            COPILOT_API_KEY = "(open $'(getconf DARWIN_USER_TEMP_DIR)/agenix/COPILOT_API_KEY')";
            CODEIUM_API_KEY = "(open $'(getconf DARWIN_USER_TEMP_DIR)/agenix/CODEIUM_API_KEY')";
            NIX_CONFIG = "(open $'(getconf DARWIN_USER_TEMP_DIR)/agenix/NIX_ACCESS_TOKENS')";
          };
        }
      ];
      age = {
        identityPaths = [ "/Users/raphael/.ssh/id_ed25519" ];
        secrets =  {
          OPENAI_API_KEY = {
            file = ../secrets/openai.key.age;
          };
          COPILOT_API_KEY = {
            file = ../secrets/copilot.api.key.age;
          };
          CODEIUM_API_KEY = {
            file = ../secrets/codeium.api.key.age;
          };
          NIX_ACCESS_TOKENS = {
            file = ../secrets/nix.conf.extra.age;
          };
        };
      };
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
        stateVersion = "23.05";
        homeDirectory = /Users/raphael;

        # List packages installed in system profile. To search by name, run:
        # $ nix-env -qaP | grep wget
        packages = with pkgs; [
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

          # machine specific
          agenix.packages.x86_64-darwin.default
          pkgs.rust-bin.nightly.latest.default
          helix-gpt
          # onionshare
          # deploy-rs.packages.x86_64-darwin.default
      ] ++
        (import ../packages/basic_cli_set.nix { inherit pkgs; }) ++
        (import ../packages/gui.nix { inherit pkgs; }) ++
        (import ../packages/dev/js.nix { inherit pkgs; }) ++
        (import ../packages/offensive.nix { inherit pkgs; }) ++
        (import ../packages/crypto.nix { inherit pkgs; }) ++
        (import ../packages/dev/nix.nix { inherit pkgs; });

        file.".cargo/config.toml".source = ../config/cargo.toml;
      };

      news.display = "silent";
      programs = import ../homes/common.nix { inherit pkgs config lib; } //
        {
          vscode = import ../homes/programs/vscodium.nix { inherit pkgs; };
          git = import ../homes/programs/git.nix { inherit pkgs; };
        };
    });
  }
]
