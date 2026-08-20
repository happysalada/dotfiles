{
  home-manager,
  agenix,
  nixos-hardware,
}:
[
  (
    { pkgs, config, lib, ... }:
    {
      imports = [
        ./hardware-configuration.nix

        # --- nixos-hardware -------------------------------------------------
        # there's no g834 profile upstream, so this is the g533zw profile
        # rebuilt for ada lovelace instead of ampere.
        nixos-hardware.nixosModules.common-cpu-intel
        nixos-hardware.nixosModules.common-pc-laptop
        nixos-hardware.nixosModules.common-pc-ssd
        # prime.nix -> nvidia offload + the `nvidia-offload` wrapper
        nixos-hardware.nixosModules.common-gpu-nvidia
        # not exported under a nixosModules name, so import by path
        "${nixos-hardware}/common/gpu/nvidia/ada-lovelace"
        # gives hardware.asus.battery.chargeUpto
        nixos-hardware.nixosModules.asus-battery
      ];

      # ---------------------------------------------------------------------
      # boot
      # ---------------------------------------------------------------------
      boot = {
        loader.systemd-boot.enable = true;
        loader.efi.canTouchEfiVariables = true;
        kernelPackages = pkgs.linuxPackages_latest;
      };

      # ---------------------------------------------------------------------
      # networking / locale
      # ---------------------------------------------------------------------
      networking = {
        hostName = "strix";
        networkmanager.enable = true;
      };

      time.timeZone = "America/Toronto";
      i18n.defaultLocale = "en_CA.UTF-8";

      # ---------------------------------------------------------------------
      # nvidia: prime offload
      #
      # the intel igpu drives the display; the 4090 stays powered down until
      # something asks for it via `nvidia-offload <cmd>`.
      # ---------------------------------------------------------------------
      hardware.nvidia = {
        modesetting.enable = true;
        nvidiaSettings = true;
        powerManagement = {
          enable = true;
          # lets the driver fully power down the dgpu when idle
          finegrained = true;
        };
        prime = {
          # from lspci: 00:02.0 intel, 01:00.0 nvidia
          intelBusId = "PCI:0:2:0";
          nvidiaBusId = "PCI:1:0:0";
        };
      };
      # adds a "battery-saver" boot entry that disables the dgpu outright
      hardware.nvidia.primeBatterySaverSpecialisation = true;

      # ---------------------------------------------------------------------
      # asus: rgb off + battery charge limit
      # ---------------------------------------------------------------------
      services.asusd.enable = true;

      # stop charging at 80% to keep the cells happy. re-applied on resume by
      # the nixos-hardware module. `charge-upto 100` overrides until reboot,
      # or `asusctl battery oneshot` for a single full charge before travel.
      hardware.asus.battery.chargeUpto = 80;

      # Applied after asusd is up, and again after resume.
      #
      # ORDER MATTERS: `asusctl aura effect ...` resets brightness back to Med,
      # so the effect and the per-zone power states go first and `leds set off`
      # goes last. Doing it the other way round leaves the keyboard lit.
      #
      # `asusctl aura power <zone>` with no flags sets boot/awake/sleep/shutdown
      # all false, i.e. off in every power state.
      systemd.services.asus-tuning = {
        description = "Aura RGB off + battery charge limit";
        wantedBy = [
          "multi-user.target"
          "post-resume.target"
        ];
        after = [
          "asusd.service"
          "post-resume.target"
        ];
        requires = [ "asusd.service" ];
        startLimitBurst = 5;
        startLimitIntervalSec = 60;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          # asusd needs a moment to claim the dbus name after boot
          Restart = "on-failure";
          RestartSec = 3;
        };
        script = ''
          asusctl=${pkgs.asusctl}/bin/asusctl

          $asusctl aura effect static -c 000000 || true
          for zone in keyboard lightbar logo lid rear-glow; do
            $asusctl aura power "$zone" || true
          done
          # last, so nothing above can raise it again
          $asusctl leds set off

          # asusd owns the charge threshold and re-applies its own stored value
          # at boot, so set it through asusctl rather than only via sysfs
          $asusctl battery limit 80
        '';
      };

      # ---------------------------------------------------------------------
      # desktop (gnome, as installed)
      # ---------------------------------------------------------------------
      services.xserver = {
        enable = true;
        xkb = {
          layout = "us";
          variant = "";
        };
      };
      services.displayManager.gdm.enable = true;
      services.desktopManager.gnome.enable = true;

      services.printing.enable = true;

      services.pulseaudio.enable = false;
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };

      # ---------------------------------------------------------------------
      # users
      #
      # NOTE: mutableUsers stays true, unlike bee/hetz. the install-time
      # password is kept; switch to hashedPassword + mutableUsers = false once
      # you've run `mkpasswd -m sha-512`.
      # ---------------------------------------------------------------------
      users.users.yt = {
        isNormalUser = true;
        description = "yt";
        extraGroups = [
          "networkmanager"
          "wheel"
          "video"
          "input"
        ];
        shell = pkgs.nushell;
      };

      environment = {
        shells = [ pkgs.nushell ];
        systemPackages = with pkgs; [
          vim
          git
          lsof
          agenix.packages.x86_64-linux.default
        ];
      };

      fonts.packages = import ../../packages/fonts.nix { inherit pkgs; };

      programs.firefox.enable = true;
      programs.dconf.enable = true;

      # lets unpatched dynamically-linked binaries (python wheels, mise-installed
      # tools) find a libc/libstdc++. replaces the global LD_LIBRARY_PATH that
      # used to be set in nushell env.nu, which could shadow the right libs.
      programs.nix-ld.enable = true;

      # ---------------------------------------------------------------------
      # nix
      # ---------------------------------------------------------------------
      nix = {
        package = pkgs.nixVersions.latest;
        settings = {
          cores = 0;
          max-jobs = "auto";
          auto-optimise-store = true;
          download-buffer-size = 104857600; # 100 Mb
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          trusted-users = [
            "root"
            "yt"
          ];
          substituters = [
            "https://cache.nixos.org"
            "https://nix-community.cachix.org"
          ];
          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          ];
        };
        extraOptions = ''
          keep-outputs = true
          keep-derivations = true
          builders-use-substitutes = true
          connect-timeout = 5
          log-lines = 25
          min-free = 128000000 # 128 MB
          max-free = 1000000000 # 1 GB
        '';
        gc = {
          automatic = true;
          options = "--delete-older-than 14d";
        };
      };

      nixpkgs = {
        config.allowUnfree = true;
        overlays = [
          (final: prev: {
            pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
              (pyFinal: pyPrev: {
                # curl-cffi (pulled in by yt-dlp) has a handful of tests that
                # assume working DNS/TLS against 127.0.0.1, which the nix
                # sandbox doesn't provide. The other ~370 still run.
                curl-cffi = pyPrev.curl-cffi.overridePythonAttrs (old: {
                  disabledTests = (old.disabledTests or [ ]) ++ [
                    "test_verify"
                    "test_delete_cookies"
                  ];
                });
              })
            ];
          })
        ];
        flake = {
          setFlakeRegistry = true;
          setNixPath = true;
        };
      };

      services.journald.extraConfig = ''
        MaxFileSec=1day
        MaxRetentionSec=1month
        SystemMaxUse=2G
      '';

      # shows what changed on every rebuild
      # MIT Jörg Thalheim - https://github.com/Mic92/dotfiles
      system.activationScripts.diff = ''
        if [[ -e /run/current-system ]]; then
          ${pkgs.nix}/bin/nix --extra-experimental-features nix-command \
            store diff-closures /run/current-system "$systemConfig" || true
        fi
      '';

      system.stateVersion = "26.05";
    }
  )
  agenix.nixosModules.age
  home-manager.nixosModules.home-manager
  {
    home-manager.useGlobalPkgs = true;
    home-manager.users.yt = (
      {
        pkgs,
        config,
        lib,
        ...
      }:
      {
        home = {
          username = "yt";
          # fresh home, no prior state to migrate, so track the current release.
          # NOTE: system.stateVersion above deliberately stays at 26.05 - that one
          # pins stateful service layouts and should keep the install-time value.
          stateVersion = "26.11";

          # ssh will not create the ControlPath directory itself; without it
          # multiplexing dies with `unix_listener: cannot bind to path ...`
          file.".ssh/control/.keep".text = "";

          packages =
            with pkgs;
            [
              btop
              nvtopPackages.full # intel + nvidia
              smartmontools
              pciutils
              usbutils
            ]
            ++ (import ../../packages/basic_cli_set.nix { inherit pkgs; })
            ++ (import ../../packages/ai.nix { inherit pkgs; })
            ++ (import ../../packages/linux_cli_set.nix { inherit pkgs; })
            ++ (import ../../packages/package_managers.nix { inherit pkgs; })
            ++ (import ../../packages/dev/rust.nix { inherit pkgs; })
            ++ (import ../../packages/dev/python.nix { inherit pkgs; })
            ++ (import ../../packages/dev/js.nix { inherit pkgs; })
            ++ (import ../../packages/dev/nix.nix { inherit pkgs; });
        };

        news.display = "silent";

        fonts.fontconfig.enable = true;


        # super+t -> new ghostty window
        dconf.settings = {
          "org/gnome/settings-daemon/plugins/media-keys" = {
            custom-keybindings = [
              "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ghostty/"
            ];
          };
          "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ghostty" = {
            name = "Ghostty";
            command = "${pkgs.ghostty}/bin/ghostty";
            binding = "<Super>t";
          };
        };

        programs =
          import ../../homes/common.nix { inherit pkgs config lib; }
          // (import ../../homes/programs/git.nix { inherit pkgs; })
          // {
          ghostty = import ../../homes/programs/ghostty.nix { inherit pkgs; };

        };
      }
    );
  }
]
