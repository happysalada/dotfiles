{
  home-manager,
  agenix,
  rust-overlay,
}:
[
  (
    { pkgs, ... }:
    {
      imports = [
        agenix.darwinModules.age
      ];

      programs = {
        gnupg.agent = {
          enable = true;
          enableSSHSupport = true;
        };
      };

      fonts = {
        packages = import ../packages/fonts.nix { inherit pkgs; };
      };

      system = {
        primaryUser = "macintoshhd";
        defaults = {
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
        package = pkgs.nixVersions.latest;
        extraOptions = ''
          experimental-features = nix-command flakes
          keep-outputs = true
          keep-derivations = true
          builders-use-substitutes = true
          connect-timeout = 5
          log-lines = 25
          min-free = 128000000 # 128 MB
          max-free = 1000000000 # 1 GB
        '';
        settings = {
          max-jobs = "auto";
          cores = 4;
          # auto-optimise-store = true; # doesn't work on macos for now
          substituters = [
            "https://nix-community.cachix.org"
          ];
          trusted-public-keys = [
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          ];
        };
        # - makes some builds fail midway
        # - takes more time to re-build something
        gc.automatic = false;
      };

      nixpkgs = {
        hostPlatform = "x86_64-darwin";
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
        flake = {
          setFlakeRegistry = true;
          setNixPath = true;
        };
      };

      users = {
        users.macintoshhd = {
          home = /Users/macintoshhd;
          shell = pkgs.nushell;
        };
      };

      services = {
        # smartd = { enable = true; }; # unavailable on macos
        # avahi.enable = true; # unavailable on macos
      };

      system.stateVersion = 5;
    }
  )
  home-manager.darwinModules.home-manager
  {
    # `home-manager` config
    home-manager.useGlobalPkgs = true;
    home-manager.users.macintoshhd = (
      {
        pkgs,
        config,
        lib,
        ...
      }:
      {
        imports = [
          agenix.homeManagerModules.age
          {
            config.programs.nushell.envFile.text = ''
              # Fix path on darwin
              $env.PATH = (
                $env.PATH
                | split row (char esep)
                | prepend '/run/current-system/sw/bin'
                | prepend '/Users/macintoshhd/.nix-profile/bin'
                | prepend '/Users/macintoshhd/.local/bin'
              )

              $env.OPENAI_API_KEY = (open $'(getconf DARWIN_USER_TEMP_DIR)agenix/OPENAI_API_KEY');
              $env.COPILOT_API_KEY = (open $'(getconf DARWIN_USER_TEMP_DIR)agenix/COPILOT_API_KEY');
              $env.CODEIUM_API_KEY = (open $'(getconf DARWIN_USER_TEMP_DIR)agenix/CODEIUM_API_KEY');
              $env.NIX_CONFIG = (open $'(getconf DARWIN_USER_TEMP_DIR)agenix/NIX_ACCESS_TOKENS');
              $env.ANTHROPIC_API_KEY = (open $'(getconf DARWIN_USER_TEMP_DIR)agenix/ANTHROPIC_API_KEY');
              $env.GITHUB_TOKEN = (open $'(getconf DARWIN_USER_TEMP_DIR)agenix/GITHUB_TOKEN');
              $env.YOUTUBE_API_KEY = (open $'(getconf DARWIN_USER_TEMP_DIR)agenix/YOUTUBE_API_KEY');
              $env.TAVILY_API_KEY = (open $'(getconf DARWIN_USER_TEMP_DIR)agenix/TAVILY_API_KEY');
              $env.DEEPSEEK_API_KEY = (open $'(getconf DARWIN_USER_TEMP_DIR)agenix/DEEPSEEK_API_KEY');
            '';
          }
        ];
        age = {
          identityPaths = [ "/Users/macintoshhd/.ssh/id_ed25519" ];
          secrets = {
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
            ANTHROPIC_API_KEY = {
              file = ../secrets/anthropic.key.age;
            };
            GITHUB_TOKEN = {
              file = ../secrets/github_access_token.age;
            };
            YOUTUBE_API_KEY = {
              file = ../secrets/youtube.key.age;
            };
            TAVILY_API_KEY = {
              file = ../secrets/tavily.key.age;
            };
            DEEPSEEK_API_KEY = {
              file = ../secrets/deepseek.api.key.age;
            };
          };
        };
        home = {
          username = "macintoshhd";
          # This value determines the Home Manager release that your
          # configuration is compatible with. This helps avoid breakage
          # when a new Home Manager release introduces backwards
          # incompatible changes.
          #
          # You can update Home Manager without changing this value. See
          # the Home Manager release notes for a list of state version
          # changes in each release.
          stateVersion = "25.11";
          homeDirectory = /Users/macintoshhd;

          # List packages installed in system profile. To search by name, run:
          # $ nix-env -qaP | grep wget
          packages =
            with pkgs;
            [
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
              pkgs.rust-bin.stable.latest.default
              helix-gpt
              localsend
              # onionshare
              # deploy-rs.packages.x86_64-darwin.default
              pinentry_mac # gpg stuff
              docker_28
              docker-compose
            ]
            ++ (import ../packages/basic_cli_set.nix { inherit pkgs; })
            ++ (import ../packages/package_managers.nix { inherit pkgs; })
            ++ (import ../packages/gui.nix { inherit pkgs; })
            ++ (import ../packages/dev/js.nix { inherit pkgs; })
            ++ (import ../packages/dev/python.nix { inherit pkgs; })
            ++ (import ../packages/offensive.nix { inherit pkgs; })
            ++ (import ../packages/crypto.nix { inherit pkgs; })
            ++ (import ../packages/dev/nix.nix { inherit pkgs; });

          file.".cargo/config.toml".source = ../config/cargo.toml;
        };

        news.display = "silent";
        programs = import ../homes/common.nix { inherit pkgs config lib; } // {
          vscode = import ../homes/programs/vscodium.nix { inherit pkgs; };
          git = import ../homes/programs/git.nix { inherit pkgs; };
        };

        # Only works on linux
        # services = {
        #   gpg-agent = {
        #     enable = true;
        #     enableSshSupport = true;
        #     enableNushellIntegration = true;
        #     enableExtraSocket = true;
        #   };
        # };

        accounts = {
          email.accounts =
            let
              # gmail_settings = {
              #   imap = {
              #     host = "imap.gmail.com";
              #     port = 993;
              #   };
              #   smtp = {
              #     host = "smtp.gmail.com";
              #     port = 465;
              #   };
              # };
              mailbox_org_settings = {
                imap = {
                  host = "imap.mailbox.org";
                  port = 993;
                };
                smtp = {
                  host = "pop3.mailbox.org";
                  port = 995;
                };
              };
              mail_settings = {
                neomutt = {
                  enable = true;
                  # settings.sync.enable = true;
                };
                notmuch.enable = true;
                mbsync = {
                  enable = true;
                  # frequency = "*-*-* 00:00:00";
                  create = "both"; # maildir and imap
                  expunge = "both";
                };
              };
            in
            {
              "raphael@megzari.com" =
                mailbox_org_settings
                // mail_settings
                // {
                  primary = true;
                  address = "fj5vky7k52ajzuba6ku8qwu@mailbox.org";
                  userName = "fj5vky7k52ajzuba6ku8qwu@mailbox.org";
                  realName = "Raphael Megzari";
                  passwordCommand = "rbw get login.mailbox.org";
                  aliases = [
                    "raphael@megzari.com"
                    "raphael@sassy.technology"
                  ];
                };
            };
          calendar = {
            basePath = "Calendar";
            accounts = {
              "main" = {
                khal = {
                  enable = true;
                  type = "discover";
                };
                primary = true;
                vdirsyncer = {
                  enable = true;
                };
                local.encoding = "UTF-8";
                remote = {
                  type = "caldav";
                  url = "https://dav.mailbox.org";
                  userName = "fj5vky7k52ajzuba6ku8qwu@mailbox.org";
                  passwordCommand = [
                    "rbw"
                    "get"
                    "login.mailbox.org"
                  ];
                };
              };
            };
          };
          contact = {
            basePath = "Contact";
            accounts = {
              "main" = {
                khal = {
                  enable = true;
                };
                khard = {
                  enable = true;
                };
                vdirsyncer = {
                  enable = true;
                };
                local = {
                  encoding = "UTF-8";
                };
                remote = {
                  type = "carddav";
                  url = "https://dav.mailbox.org/carddav";
                  userName = "fj5vky7k52ajzuba6ku8qwu@mailbox.org";
                  passwordCommand = [
                    "rbw"
                    "get"
                    "login.mailbox.org"
                  ];
                };
              };
            };
          };
        };
      }
    );
  }
]
