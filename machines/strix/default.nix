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

        # The stock menu flashes past too fast to pick anything. This is also
        # what you need in order to reach the `battery-saver` specialisation,
        # which only exists as a boot entry.
        loader.timeout = 10;

        # Cap how many generations get an entry written to /boot. Note this
        # limits the *menu*, not the store: `nix-collect-garbage` still decides
        # which generations survive, and /boot is only ever rewritten during a
        # `nixos-rebuild boot|switch`. Each generation also gets a second entry
        # for the battery-saver specialisation, so the menu holds roughly twice
        # this number of lines.
        loader.systemd-boot.configurationLimit = 10;

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

      # ---------------------------------------------------------------------
      # niri: a scrollable-tiling wayland compositor, and the session GDM logs
      # into by default. GNOME stays installed as the fallback - pick it from
      # the gear menu at the login screen if something is broken under niri.
      #
      # The nixpkgs module handles the session file, the portals
      # (xdg-desktop-portal-gnome, needed for screen sharing) and gnome-keyring.
      # Everything user-facing - config.kdl, bar, launcher, notifications, idle
      # - lives in homes/niri/.
      # ---------------------------------------------------------------------
      programs.niri.enable = true;

      # programs.niri already sets this with mkDefault; stated explicitly so the
      # choice is recorded here rather than inherited from the module.
      services.displayManager.defaultSession = "niri";

      # swaylock authenticates through PAM and there is no NixOS module for it.
      # Without this stanza it rejects every password and the only way out of
      # the lock screen is a VT switch.
      security.pam.services.swaylock = { };

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

      # firefox is configured per-user in homes/programs/firefox.nix.
      # Epiphany (GNOME Web, webkitgtk) is excluded: GNOME registers it as the
      # https handler and claude.ai rejects it as an unsupported browser.
      environment.gnome.excludePackages = [ pkgs.epiphany ];
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
    # Install user packages into /etc/profiles/per-user/yt (managed by NixOS)
    # rather than ~/.nix-profile. Conventional when running home-manager as a
    # NixOS module, and it keeps HM out of the profile that `nix profile`
    # owns. Note: does NOT help gnome-shell notice newly added .desktop
    # entries - that still needs a re-login, since this path gets swapped
    # wholesale on activation too.
    home-manager.useUserPackages = true;
    home-manager.users.yt = (
      {
        pkgs,
        config,
        lib,
        ...
      }:
      let
        # dconf needs a type for an empty array; a bare [] is ambiguous
        noKey = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
      in
      {
        imports = [ ../../homes/niri ];

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
              # process viewer is `bottom` (btm), from basic_cli_set.nix below
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

        # Pinning the default browser declaratively. Left OFF for now: owning
        # ~/.config/mimeapps.list makes it a read-only store symlink, so no app
        # can register a handler at runtime any more - claude-code writes to
        # this file to register claude-cli:// for claude.ai deep links.
        #
        # Not strictly needed while epiphany is excluded: firefox is then the
        # only registered https handler, so GNOME picks it anyway. Re-enable
        # if the default ever drifts.
        #
        # xdg.mimeApps = {
        #   enable = true;
        #   defaultApplications = {
        #     "text/html" = "firefox.desktop";
        #     "x-scheme-handler/http" = "firefox.desktop";
        #     "x-scheme-handler/https" = "firefox.desktop";
        #     "x-scheme-handler/about" = "firefox.desktop";
        #     "x-scheme-handler/unknown" = "firefox.desktop";
        #     "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
        #   };
        # };

        # Tridactyl's rc file. Not a home-manager module, so it is wired by
        # hand; `programs.firefox.nativeMessagingHosts` in firefox.nix is what
        # actually lets the extension read it.
        xdg.configFile."tridactyl/tridactylrc".text = import ../../homes/programs/tridactylrc.nix {
          inherit pkgs;
        };

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

          # Key repeat: GNOME ships 500ms before the first repeat and 30ms
          # between them (~33/s). Both are sluggish for helix/vim-style
          # movement. `delay` is the hold time before repeating starts and
          # `repeat-interval` is the gap between repeats, both in ms - so
          # smaller is faster for each.
          #
          # niri does not read dconf; homes/niri/config.kdl.nix carries the
          # matching values for that session (as a rate in Hz: 20ms = 50/s).
          #
          # Both are uint32 in the schema; a bare nix int serialises as int32
          # and dconf silently refuses to load it.
          "org/gnome/desktop/peripherals/keyboard" = {
            delay = lib.hm.gvariant.mkUint32 200;
            repeat-interval = lib.hm.gvariant.mkUint32 20;
            repeat = true;
          };

          # super+left/right moves the window to the workspace on that side and
          # follows it there. GNOME binds those to mutter's toggle-tiled-*,
          # which only snaps the window to half of the *current* workspace, so
          # clear those first - a key bound in two schemas fires neither
          # reliably.
          #
          # Workspaces are dynamic, so "right" off the end creates a new one.
          "org/gnome/mutter/keybindings" = {
            toggle-tiled-left = noKey;
            toggle-tiled-right = noKey;
          };
          "org/gnome/desktop/wm/keybindings" = {
            # keeping the stock super+shift+pgup/pgdn as a second binding
            move-to-workspace-left = [
              "<Super>Left"
              "<Super><Shift>Page_Up"
            ];
            move-to-workspace-right = [
              "<Super>Right"
              "<Super><Shift>Page_Down"
            ];
          };
        };

        programs =
          import ../../homes/common.nix { inherit pkgs config lib; }
          // (import ../../homes/programs/git.nix { inherit pkgs; })
          // {
          ghostty = import ../../homes/programs/ghostty.nix { inherit pkgs; };
          firefox = import ../../homes/programs/firefox.nix { inherit pkgs; };

        };
      }
    );
  }
]
