{ home-manager, agenix }:
let
  raphaelSshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGyQSeQ0CV/qhZPre37+Nd0E9eW+soGs+up6a/bwggoP raphael@RAPHAELs-MacBook-Pro.local";
in
[
  # document-search.nixosModules.x86_64-linux.default
  {
    environment.systemPackages = [
      agenix.packages.x86_64-linux.default
    ];

  }
  ({ pkgs, config, ... }: {
    imports = [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../modules/fail2ban.nix
      ../../modules/vector.nix
      ../../modules/postgresql.nix
      ../../modules/grafana
      ../../modules/chrony.nix
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
      ../../modules/restic.nix
    ];


    boot.loader.systemd-boot.enable = true;
    boot.loader.efi = {
        canTouchEfiVariables = true;
        # efiSysMountPoint = "/boot/EFI";
    };
    boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;

    nix = {
      package = pkgs.nixUnstable;
      settings = {
        cores = 8;  
        auto-optimise-store = true;
      };
      extraOptions = ''
        experimental-features = nix-command flakes
      '';

      gc = {
        automatic = true;
        options = "--delete-older-than 7d";
      };
    };

    # Set your time zone.
    time.timeZone = "Etc/UTC";

    environment = {
      enableDebugInfo = true;
      systemPackages = with pkgs; [ vim lsof git ];
      shells = [ pkgs.nushellFull ];
    };

    networking.hostName = "bee";
    networking.hostId = "00000001";

    networking.enableIPv6 = true;
    networking.nameservers = [
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

    nixpkgs.config = {
      allowUnfree = true;
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
          shell = pkgs.nushellFull;
        };
      };
    };

    services = {
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

      caddy.virtualHosts = {
        "vaultwarden.megzari.com" = {
          extraConfig = ''
            reverse_proxy 127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}
          '';
        };
        "git.megzari.com" = {
          extraConfig = ''
            reverse_proxy 127.0.0.1:${toString config.services.gitea.settings.server.HTTP_PORT}
          '';
        };
        "grafana.megzari.com" = {
          extraConfig = ''
            reverse_proxy 127.0.0.1:3000
          '';
        };
        "atuin.megzari.com" = {
          extraConfig = ''
            reverse_proxy ${config.services.atuin.host}:${toString config.services.atuin.port}
          '';
        };
        "qdrant.megzari.com" = {
          extraConfig = ''
            reverse_proxy 127.0.0.1:${toString config.services.qdrant.settings.service.http_port}
          '';
        };
        "meilisearch.megzari.com" = {
          extraConfig = ''
            reverse_proxy ${config.services.meilisearch.listenAddress}:${toString config.services.meilisearch.listenPort}
          '';
        };
        "uptime.megzari.com" = {
          extraConfig = ''
            reverse_proxy ${config.services.uptime-kuma.settings.HOST}:${config.services.uptime-kuma.settings.PORT}
          '';
        };
        "surrealdb.megzari.com" = {
          extraConfig = ''
            reverse_proxy 127.0.0.1:${toString config.services.surrealdb.port}
          '';
        };
        # "search.toagora.com" = {
        #   extraConfig = ''
        #     reverse_proxy 127.0.0.1:${toString config.services.document-search.port}
        #   '';
        # };
      };

      cfdyndns = {
        enable = true;
        apiTokenFile = config.age.secrets.CLOUDFLARE_API_TOKEN.path;
        records = [
          "vaultwarden.megzari.com"
          "git.megzari.com"
          "gitea.megzari.com"
          "grafana.megzari.com"
          "atuin.megzari.com"
          "qdrant.megzari.com"
          "meilisearch.megzari.com"
          "uptime.megzari.com"
          "surrealdb.megzari.com"
          # "windmill.megzari.com"
        ];
      };

      # document-search = {
      #   enable = true;
      #   package = document-search.packages.x86_64-linux.default;
      #   origin = "https://search.toagora.com";
      #   huggingfaceApiTokenPath = config.age.secrets.HUGGINGFACE_API_TOKEN.path;
      #   unstructuredApiKeyPath = config.age.secrets.UNSTRUCTURED_API_KEY.path;
      #   collection = "agora_anonymised_3";
      # };
    };

    age.secrets =  {
      CLOUDFLARE_API_TOKEN = {
        file = ../../secrets/cloudflare.api.token.age;
      };
      HUGGINGFACE_API_TOKEN = {
        file = ../../secrets/huggingface.token.age;
      };
      UNSTRUCTURED_API_KEY = {
        file = ../../secrets/unstructured.api.key.age;
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
    system.stateVersion = "23.11"; # Did you read the comment?
  })
  agenix.nixosModules.age
  home-manager.nixosModules.home-manager
  {
    # `home-manager` config
    home-manager.useGlobalPkgs = true;
    home-manager.users.yt = ({ pkgs, config, lib, ... }: {
      imports = [
        agenix.homeManagerModules.age
        {
          # agenix home manager module doesn't seem to work with my current setup somehow.
          # config.programs.nushell.environmentVariables = {
          #   OPENAI_API_KEY = "(open $'($env.XDG_RUNTIME_DIR)/agenix/OPENAI_API_KEY')";
          #   GITHUB_ACCESS_TOKEN = "(open $'($env.XDG_RUNTIME_DIR)/agenix/GITHUB_ACCESS_TOKEN')";
          #   SURREAL_USERNAME = "(open $'($env.XDG_RUNTIME_DIR)/agenix/SURREAL_USERNAME')";
          #   SURREAL_PASSWORD = "(open $'($env.XDG_RUNTIME_DIR)/agenix/SURREAL_PASSWORD')";
          # };
        }
      ];
      age = {
        identityPaths = [ "/home/yt/.ssh/id_ed25519" ];
        secrets =  {
          OPENAI_API_KEY = {
            file = ../../secrets/openai.key.age;
          };
          GITHUB_ACCESS_TOKEN = {
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
        stateVersion = "22.05";
        # homeDirectory = /home/yt;

        # List packages installed in system profile. To search by name, run:
        # $ nix-env -qaP | grep wget
        packages = with pkgs; [
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
          nvtop-amd # GPU usage
          btop # top with cpu freq
        ] ++
        (import ../../packages/basic_cli_set.nix { inherit pkgs; }) ++
        (import ../../packages/dev/rust.nix { inherit pkgs; }) ++
        (import ../../packages/dev/js.nix { inherit pkgs; }) ++
        (import ../../packages/dev/nix.nix { inherit pkgs; });
      };
      news.display = "silent";
      programs = import ../../homes/common.nix { inherit pkgs config lib; };
    });
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
