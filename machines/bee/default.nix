{
  home-manager,
  agenix,
  megzari_com,
}:
let
  raphaelSshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGyQSeQ0CV/qhZPre37+Nd0E9eW+soGs+up6a/bwggoP raphael@RAPHAELs-MacBook-Pro.local";
in
[
  (
    { pkgs, config, ... }:
    {
      imports = [
        megzari_com.nixosModules.x86_64-linux.megzari_com
        # monorepo.nixosModules.x86_64-linux.sweif
        # monorepo.nixosModules.x86_64-linux.brocop
        # monorepo.nixosModules.x86_64-linux.brocop_admin
        # Include the results of the hardware scan.
        ./hardware-configuration.nix
        ../../modules/fail2ban.nix
        ../../modules/vector.nix
        ../../modules/postgresql.nix
        ../../modules/grafana
        ../../modules/ntpd-rs.nix
        ../../modules/loki.nix
        ../../modules/mimir.nix
        ../../modules/caddy.nix
        ../../modules/prometheus.nix
        ../../modules/ssh.nix
        ../../modules/vaultwarden.nix
        ../../modules/surrealdb.nix
        ../../modules/gitea.nix
        ../../modules/qdrant.nix
        ../../modules/uptime-kuma.nix
        ../../modules/atuin.nix
        ../../modules/meilisearch.nix
        # ../../modules/rustic.nix
        ../../modules/megzari_com.nix
        ../../modules/windmill.nix
        # ../../modules/rustus.nix
        ../../modules/ntfy.nix
        # ../../modules/monorepo.nix
        ../../modules/home_assistant.nix
        ../../modules/adguardhome.nix
        ../../modules/searx.nix
        ../../modules/open-webui.nix
        ../../modules/cloudflare-dyndns.nix
        ../../modules/ollama.nix
        ../../modules/prefect.nix
        ../../modules/paperless.nix
        ../../modules/invidious.nix
      ];

      boot.loader.systemd-boot.enable = true;
      boot.loader.efi = {
        canTouchEfiVariables = true;
        # efiSysMountPoint = "/boot/EFI";
      };

      systemd.targets.sleep.enable = false;
      systemd.targets.suspend.enable = false;
      systemd.targets.hibernate.enable = false;
      systemd.targets.hybrid-sleep.enable = false;

      environment = {
        enableDebugInfo = true;
        systemPackages = with pkgs; [
          vim
          lsof
          git
          agenix.packages.x86_64-linux.default
          prefect
        ];
        shells = [ pkgs.nushell ];
      };

      # Increase the maximum send and the receive buffer size to roughly 7.5 MB
      # For adguardhome
      boot.kernel.sysctl."net.core.rmem_max" = 7500000;
      boot.kernel.sysctl."net.core.wmem_max" = 7500000;

      # hardware.nvidia = {
      #   # Modesetting is required.
      #   modesetting.enable = true;

      #   # Enable the Nvidia settings menu,
      #   # accessible via `nvidia-settings`.
      #   nvidiaSettings = true;

      #   # Optionally, you may need to select the appropriate driver version for your specific GPU.
      #   package = config.boot.kernelPackages.nvidiaPackages.stable;
      # };

      networking = {
        hostName = "bee";
        hostId = "00000001";

        enableIPv6 = true;
        nameservers = [
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
        networkmanager = {
          enable = true;
          ensureProfiles = {
            environmentFiles = [
              config.age.secrets.nm-secrets.path
            ];
            profiles = {
              birnam = {
                connection = {
                  id = "BELL969";
                  type = "wifi";
                };
                ipv4.method = "auto";
                ipv6 = {
                  addr-gen-mode = "stable-privacy";
                  method = "auto";
                };
                wifi = {
                  mode = "infrastructure";
                  ssid = "BELL969";
                };
                wifi-security = {
                  key-mgmt = "wpa-psk";
                  psk = "$BIRNAM_PSK";
                };
              };
            };
          };
        };
      };

      nix = {
        package = pkgs.nixVersions.latest;
        settings = {
          cores = 16;
          max-jobs = "auto";
          auto-optimise-store = true;
          download-buffer-size = 104857600; # 100 Mb

          substituters = [
            "https://nix-community.cachix.org"
          ];
          trusted-public-keys = [
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          ];
        };
        extraOptions = ''
          experimental-features = nix-command flakes configurable-impure-env auto-allocate-uids
          keep-outputs = true
          keep-derivations = true
          builders-use-substitutes = true
          connect-timeout = 5
          log-lines = 25
          min-free = 128000000 # 128 MB
          max-free = 1000000000 # 1 GB
          auto-optimise-store = true
        '';

        gc = {
          automatic = true;
          options = "--delete-older-than 7d";
        };
      };

      nixpkgs = {
        overlays = [
          megzari_com.overlays.x86_64-linux.default
          # monorepo.overlays.x86_64-linux.default
        ];
        config = {
          allowUnfree = true;
          # cudaSupport = true;
        };
        flake = {
          setFlakeRegistry = true;
          setNixPath = true;
        };
        # contentAddressedByDefault = true; # build fails for now
      };

      users = {
        mutableUsers = false;
        users = {
          root = {
            # Initial empty root password for easy login:
            initialHashedPassword = "";
            openssh.authorizedKeys.keys = [ raphaelSshKey ];
          };
          yt = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            # mkpasswd -m sha-512
            hashedPassword = "$6$AtFC2R2J$SO/WAdF0jthAKEfbSiWWYFz0sQudi3U9WuIehWk7jx9c9.QYUFjXt4NLWEPDOajnzjAN829v2jqvLWKfJz5N.0";
            openssh.authorizedKeys.keys = [ raphaelSshKey ];
            shell = pkgs.nushell;
          };
        };
      };

      services = {
        # Load nvidia driver for Xorg and Wayland
        # xserver.videoDrivers = [ "nvidia" ];

        # TODO use a cronjob to backup and delete old logs
        # https://askubuntu.com/questions/1012912/systemd-logs-journalctl-are-too-large-and-slow/1012913#1012913
        journald.extraConfig = ''
          MaxFileSec=1day
          MaxRetentionSec=1week
          SystemMaxUse=1G
        '';

        # antivirus
        clamav = {
          daemon.enable = true;
          updater.enable = true;
        };

        smartd.enable = true;

        bpftune.enable = true;

        caddy.virtualHosts = {
          ":80" = {
            extraConfig = ''
              import security_headers
            '';
          };
        };
      };

      age.secrets = {
        CLOUDFLARE_API_TOKEN = {
          file = ../../secrets/cloudflare.api.token.age;
        };
        HUGGINGFACE_API_TOKEN = {
          file = ../../secrets/huggingface.token.age;
        };
        UNSTRUCTURED_API_KEY = {
          file = ../../secrets/unstructured.api.key.age;
        };
        PAPERLESS_PASSWORD = {
          file = ../../secrets/paperless.password.age;
        };
        nm-secrets = {
          file = ../../secrets/nm.secrets.age;
        };
      };

      # mosh uses a random port between 60000 and 61000 so no bueno behind the router
      # programs.mosh.enable = true;

      # simple nix version diff tool
      # MIT Jörg Thalheim - https://github.com/Mic92/dotfiles/blob/c6cad4e57016945c4816c8ec6f0a94daaa0c3203/nixos/modules/upgrade-diff.nix
      system.activationScripts.diff = ''
        if [[ -e /run/current-system ]]; then
          ${pkgs.nix}/bin/nix store diff-closures /run/current-system "$systemConfig"
        fi
      '';

      # This value determines the NixOS release with which your system is to be
      # compatible, in order to avoid breaking some software such as database
      # servers. You should change this only after NixOS release notes say you
      # should.
      system.stateVersion = "25.11"; # Did you read the comment?

      # Set your time zone.
      time.timeZone = "Etc/UTC";
    }
  )
  agenix.nixosModules.age
  home-manager.nixosModules.home-manager
  {
    # `home-manager` config
    home-manager.useGlobalPkgs = true;
    home-manager.users.yt = (
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
            # agenix home manager module doesn't seem to work with my current setup somehow.
            config.programs.nushell.envFile.text = ''
              $env.OPENAI_API_KEY = (open $'($env.XDG_RUNTIME_DIR)/agenix/OPENAI_API_KEY');
              $env.GITHUB_TOKEN = (open $'($env.XDG_RUNTIME_DIR)/agenix/GITHUB_TOKEN');
            '';
          }
        ];
        age = {
          identityPaths = [ "/home/yt/.ssh/id_ed25519" ];
          secrets = {
            OPENAI_API_KEY = {
              file = ../../secrets/openai.key.age;
            };
            GITHUB_TOKEN = {
              file = ../../secrets/github_access_token.age;
            };
          };
        };
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
          stateVersion = "25.05";
          # homeDirectory = /home/yt;

          # List packages installed in system profile. To search by name, run:
          # $ nix-env -qaP | grep wget
          packages =
            with pkgs;
            [
              # network
              # mtr # network traffic
              # tcptrack

              # surrealdb.packages.x86_64-linux.default
              # surrealdb
              surrealdb-migrations
              # document-search.packages.x86_64-linux.default

              # openai-whisper-cpp
              # openai-whisper
              # (let torchWithRocm = python3Packages.torchWithRocm;
              #   in
              # openai-whisper.override {
              #   torch = torchWithRocm;
              #   transformers = python3Packages.transformers.override {
              #     torch = torchWithRocm;
              #   };
              # })
              nvtopPackages.amd # GPU usage
              btop # top with cpu freq
              smartmontools
              intentrace # better strace
            ]
            ++ (import ../../packages/basic_cli_set.nix { inherit pkgs; })
            ++ (import ../../packages/dev/rust.nix { inherit pkgs; })
            ++ (import ../../packages/dev/python.nix { inherit pkgs; })
            ++ (import ../../packages/dev/js.nix { inherit pkgs; })
            ++ (import ../../packages/dev/nix.nix { inherit pkgs; })
            ++ (import ../../packages/dev/ebook.nix { inherit pkgs; });
        };
        news.display = "silent";
        programs = import ../../homes/common.nix { inherit pkgs config lib; };
      }
    );
  }
  {
    _module.args.nixinate = {
      host = "bee";
      sshUser = "yt";
      buildOn = "remote"; # valid args are "local" or "remote"
      hermetic = false;
    };
  }
]
