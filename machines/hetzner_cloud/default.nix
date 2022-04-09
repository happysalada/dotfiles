{ home-manager, agenix }:
let
  raphaelSshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGyQSeQ0CV/qhZPre37+Nd0E9eW+soGs+up6a/bwggoP raphael@RAPHAELs-MacBook-Pro.local";
in
[
  {
    environment.systemPackages = [ agenix.defaultPackage.x86_64-linux ];
    # nixpkgs.overlays = [ self.overlay ];
  }
  ({pkgs, ...}:{
    imports = [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../modules/vector.nix
      # ../modules/postgresql.nix
      ../../modules/grafana.nix
      ../../modules/chrony.nix
      ../../modules/loki.nix
      # ../modules/caddy.nix
      ../../modules/prometheus.nix
      ../../modules/ssh.nix
      # ./gitea.nix
      # ./plausible.nix
    ];

    # Use GRUB2 as the boot loader.
    # We don't use systemd-boot because Hetzner uses BIOS legacy boot.
    boot.loader.systemd-boot.enable = false;
    boot.loader.grub = {
      enable = true;
      version = 2;
      devices = [ "/dev/sda" ];
      # efiSupport = false;
      # devices = [ "/dev/disk/by-id/nvme-SAMSUNG_MZVLB512HBJQ-00000_S4GENA0NA00424" "/dev/disk/by-id/nvme-SAMSUNG_MZVLB512HBJQ-00000_S4GENA0NA00427" ];
      # copyKernels = true;
    };
    # boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;

    nix = {
      package = pkgs.nixFlakes;
      settings.auto-optimise-store = true;
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

    environment.enableDebugInfo = true;

    # networking.hostName = "hetzner-AX41-UEFI-ZFS-NVME";
    # networking.hostId = "00000007";

    networking.enableIPv6 = true;
    networking.useDHCP = false;
    networking.interfaces.enp1s0.useDHCP = true;
    networking.nameservers = [ "8.8.8.8" ];

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
    };

    programs.mosh.enable = true;

    # This value determines the NixOS release with which your system is to be
    # compatible, in order to avoid breaking some software such as database
    # servers. You should change this only after NixOS release notes say you
    # should.
    system.stateVersion = "21.11"; # Did you read the comment?
  })
  agenix.nixosModules.age
  # vf-sqlite-graphql.nixosModules.backend
  home-manager.nixosModules.home-manager {
    # `home-manager` config
    home-manager.useGlobalPkgs = true;
    home-manager.users.yt = ({pkgs, ...}: {
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
        homeDirectory = /home/yt;

        # List packages installed in system profile. To search by name, run:
        # $ nix-env -qaP | grep wget
        packages = with pkgs; [
          # network
          mtr # network traffic
          # tcptrack

          # shell stuff
          nodePackages.bash-language-server
          shellcheck

          remarshal
          comby
        ] ++
        (import ./packages/basic_cli_set.nix { inherit pkgs; }) ++
        (import ./packages/dev/rust.nix { inherit pkgs; }) ++
        (import ./packages/dev/js.nix { inherit pkgs; }) ++
        (import ./packages/dev/nix.nix { inherit pkgs; });
      };
      news.display = "silent";
      programs = import ./homes/common.nix { inherit pkgs; };
    });
  }
  {
    _module.args.nixinate = {
      host = "135.181.253.119";
      sshUser = "root";
      buildOn = "remote"; # valid args are "local" or "remote"
    };
  }
]
