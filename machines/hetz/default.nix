{ home-manager, agenix, monorepo, lead }:
let
  raphaelSshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGyQSeQ0CV/qhZPre37+Nd0E9eW+soGs+up6a/bwggoP raphael@RAPHAELs-MacBook-Pro.local";
in
[
  ({ pkgs, config, ... }: {
    imports = [
      monorepo.nixosModules.x86_64-linux.brocop
      monorepo.nixosModules.x86_64-linux.brocop_admin
      lead.nixosModules.x86_64-linux.lead
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
      ../../modules/surrealdb.nix
      ../../modules/ntfy.nix
      ../../modules/restic.nix
      ../../modules/rustus.nix
      ../../modules/windmill.nix
      ../../modules/monorepo.nix
      ../../modules/lead.nix
    ];

    # Use GRUB2 as the boot loader.
    # We don't use systemd-boot because Hetzner uses BIOS legacy boot.
    boot.loader.systemd-boot.enable = false;
    boot.loader.grub = {
      enable = true;
      efiSupport = false;
      devices = [
        "/dev/disk/by-id/nvme-KXG60ZNV512G_TOSHIBA_Z99S105TT9LM"
        "/dev/disk/by-id/nvme-KXG60ZNV512G_TOSHIBA_Z99S1064T9LM"
      ];
      copyKernels = true;
    };

    boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;

    nix = {
      package = pkgs.nixUnstable;
      settings = {
        cores = 6;  
        auto-optimise-store = true;
      };
      extraOptions = ''
        experimental-features = nix-command flakes
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

    # Set your time zone.
    time.timeZone = "Etc/UTC";

    environment = {
      enableDebugInfo = true;
      systemPackages = with pkgs; [ vim lsof git agenix.packages.x86_64-linux.default ];
      shells = [ pkgs.nushellFull ];
    };

    fonts.packages = import ../../packages/fonts.nix { inherit pkgs; };

    networking.hostName = "hetzner-AX41-UEFI-ZFS-NVME";
    networking.hostId = "00000007";

    networking.enableIPv6 = true;
    networking.useDHCP = false;
    networking.interfaces."enp41s0".ipv4.addresses = [
      {
        address = "116.202.222.51";
        prefixLength = 24;
      }
    ];
    networking.interfaces."enp41s0".ipv6.addresses = [
      {
        address = "2a01:4f8:241:5621::1";
        prefixLength = 64;
      }
    ];
    networking.defaultGateway = "116.202.222.1";
    networking.defaultGateway6 = { address = "fe80::1"; interface = "enp41s0"; };
    networking.nameservers = [
      # Quad 9
      "9.9.9.9"
      "149.112.112.112"
      # opendns
      "208.67.222.222"
      "208.67.220.220"
      # cloudflare
      "1.1.1.1"
      "2606:4700:4700::1111"
      "2606:4700:4700::1001"
      # google
      "8.8.8.8"
      "2001:4860:4860::8888"
      "2001:4860:4860::8844"
    ];
    nixpkgs = {
      overlays = [
        # helix.overlays.default
        monorepo.overlays.x86_64-linux.default
        lead.overlays.x86_64-linux.default
      ];
      config.allowUnfree = true;
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
      # ssh-iptables jail is enabled by default
      fail2ban.enable = true;

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
        fangfrisch.enable = true;
        updater = {
          enable = true;
          settings = {
            DatabaseCustomURL = [
              "https://www.securiteinfo.com/get/signatures/80b7426e3b82a248c1db6abfea3daa32b9290fe6f52e17957061c70e520a120c799b280d5ae3730e82cfe652344eed5a3c10e9a9fe3497d60c0b201339012e6b/securiteinfo.hdb"
              "https://www.securiteinfo.com/get/signatures/80b7426e3b82a248c1db6abfea3daa32b9290fe6f52e17957061c70e520a120c799b280d5ae3730e82cfe652344eed5a3c10e9a9fe3497d60c0b201339012e6b/securiteinfo.ign2"
              "https://www.securiteinfo.com/get/signatures/80b7426e3b82a248c1db6abfea3daa32b9290fe6f52e17957061c70e520a120c799b280d5ae3730e82cfe652344eed5a3c10e9a9fe3497d60c0b201339012e6b/javascript.ndb"
              "https://www.securiteinfo.com/get/signatures/80b7426e3b82a248c1db6abfea3daa32b9290fe6f52e17957061c70e520a120c799b280d5ae3730e82cfe652344eed5a3c10e9a9fe3497d60c0b201339012e6b/spam_marketing.ndb"
              "https://www.securiteinfo.com/get/signatures/80b7426e3b82a248c1db6abfea3daa32b9290fe6f52e17957061c70e520a120c799b280d5ae3730e82cfe652344eed5a3c10e9a9fe3497d60c0b201339012e6b/securiteinfohtml.hdb"
              "https://www.securiteinfo.com/get/signatures/80b7426e3b82a248c1db6abfea3daa32b9290fe6f52e17957061c70e520a120c799b280d5ae3730e82cfe652344eed5a3c10e9a9fe3497d60c0b201339012e6b/securiteinfoascii.hdb"
              "https://www.securiteinfo.com/get/signatures/80b7426e3b82a248c1db6abfea3daa32b9290fe6f52e17957061c70e520a120c799b280d5ae3730e82cfe652344eed5a3c10e9a9fe3497d60c0b201339012e6b/securiteinfoandroid.hdb"
              "https://www.securiteinfo.com/get/signatures/80b7426e3b82a248c1db6abfea3daa32b9290fe6f52e17957061c70e520a120c799b280d5ae3730e82cfe652344eed5a3c10e9a9fe3497d60c0b201339012e6b/securiteinfoold.hdb"
              "https://www.securiteinfo.com/get/signatures/80b7426e3b82a248c1db6abfea3daa32b9290fe6f52e17957061c70e520a120c799b280d5ae3730e82cfe652344eed5a3c10e9a9fe3497d60c0b201339012e6b/securiteinfopdf.hdb"
            ];
          };
        };
      };

      # aide.enable = true;

      caddy.virtualHosts = {
        ":80" = {
          extraConfig = ''
            import security_headers
          '';
        };
        "grafana.sassy.technology" = {
          extraConfig = ''
            import security_headers
            reverse_proxy 127.0.0.1:${toString config.services.grafana.settings.server.http_port}
          '';
        };
        "surrealdb.sassy.technology" = {
          extraConfig = let 
            port = toString config.services.surrealdb.port;
            in ''
              import security_headers
              import websockets
              reverse_proxy 127.0.0.1:${port}
              reverse_proxy @websockets 127.0.0.1:${port}
            '';
        };
        "preview.brocop.com" = {
          extraConfig = ''
            import security_headers
            reverse_proxy 127.0.0.1:${toString config.services.brocop.port}
          '';
        };
        "bitval.brocop.com" = {
          extraConfig = ''
            import security_headers
            reverse_proxy 127.0.0.1:${toString config.services.brocop.port}
          '';
        };
        "impulso.brocop.com" = {
          extraConfig = ''
            import security_headers
            reverse_proxy 127.0.0.1:${toString config.services.brocop.port}
          '';
        };
        "brocop.com" = {
          extraConfig = ''
            import security_headers
            reverse_proxy 127.0.0.1:${toString config.services.brocop.port}
          '';
        };
        "acrux.brocop.com" = {
          extraConfig = ''
            import security_headers
            reverse_proxy 127.0.0.1:${toString config.services.brocop.port}
          '';
        };
        "www.brocop.com" = {
          extraConfig = ''
            import security_headers
            reverse_proxy 127.0.0.1:${toString config.services.brocop.port}
          '';
        };
        "inge180.brocop.com" = {
          extraConfig = ''
            import security_headers
            reverse_proxy 127.0.0.1:${toString config.services.brocop.port}
          '';
        };
        "eaxygroup.brocop.com" = {
          extraConfig = ''
            import security_headers
            reverse_proxy 127.0.0.1:${toString config.services.brocop.port}
          '';
        };
        "demo.brocop.com" = {
          extraConfig = ''
            import security_headers
            reverse_proxy 127.0.0.1:${toString config.services.brocop.port}
          '';
        };
        "admin.brocop.com" = {
          extraConfig = ''
            import security_headers
            reverse_proxy 127.0.0.1:${toString config.services.brocop_admin.port}
          '';
        };
        "find-stock-broker.com" = {
          extraConfig = ''
            reverse_proxy 127.0.0.1:${toString config.services.lead.port}
          '';
        };
      };
    };

    programs.mosh.enable = true;

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
        stateVersion = "23.05";
        # homeDirectory = /home/yt;

        # List packages installed in system profile. To search by name, run:
        # $ nix-env -qaP | grep wget
        packages = with pkgs; [
          # network
          mtr # network traffic
          # tcptrack
          # surrealdb-migrations
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
      host = "hetz";
      sshUser = "yt";
      buildOn = "remote"; # valid args are "local" or "remote"
      hermetic = false;
    };
  }
]
