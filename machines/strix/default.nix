{
  home-manager,
  agenix,
  nixos-hardware,
  rust-overlay,
  nix-index-database,
  llm-agents,
  openlogi,
}:
[
  (
    {
      pkgs,
      ...
    }:
    {
      imports = [
        ./hardware-configuration.nix

        # loopback-only SearXNG: firefox's default engine, and the search
        # backend `crw search` / the `crw_search` MCP tool proxy to.
        ../../modules/searx-local.nix

        # local LLM server on 127.0.0.1:11434, on the 4090 - see below.
        ../../modules/ollama.nix

        # WireGuard mesh to the phone, plus the sshd and firewall holes
        # that only make sense across it.
        ../../modules/netbird.nix

        # prefect's server on 127.0.0.1:4200 - the UI and run history for
        # the flows in homes/programs/starred-digest.
        ../../modules/prefect-local.nix

        # Logitech HID++ control for the MX Master 3S. The module is the point
        # of the flake input: it installs the package, the udev rules that
        # grant the desktop user uaccess on the mouse's /dev/hidraw, uinput and
        # event node (so no `input` group is involved), and the agent unit.
        openlogi.nixosModules.default

        # modules/kanata.nix is deliberately NOT imported: its chord processing
        # reorders ordinary typing. The header of that file has the detail.

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

      # boot
      boot = {
        loader.systemd-boot.enable = true;
        loader.efi.canTouchEfiVariables = true;

        # Long enough to reach the `battery-saver` specialisation, which only
        # exists as a boot entry. 10 cost 10s on every boot; holding space
        # during boot keeps the menu open regardless.
        loader.timeout = 3;

        # Cap how many generations get an entry written to /boot. Note this
        # limits the *menu*, not the store: `nix-collect-garbage` still decides
        # which generations survive, and /boot is only ever rewritten during a
        # `nixos-rebuild boot|switch`. Each generation also gets a second entry
        # for the battery-saver specialisation, so the menu holds roughly twice
        # this number of lines.
        loader.systemd-boot.configurationLimit = 10;

        kernelPackages = pkgs.linuxPackages_latest;

        # The dgpu's display engine times out being torn down under s2idle
        # ("Failed to tear down display engine channel"), which is what breaks
        # resume. Firmware offers real S3, and nvidia's suspend path is far
        # better tested against it.
        kernelParams = [ "mem_sleep_default=deep" ];

        # Every agent session starts its own fff-mcp, and each one recursively
        # watches its whole checkout - roughly 38k directories for nixpkgs. A
        # few concurrent sessions ate the entire 512k the desktop module
        # defaults to, and inotify reports that as ENOSPC ("No space left on
        # device") in whatever tool asks for the next watch.
        kernel.sysctl."fs.inotify.max_user_watches" = 1048576;

        # Swapping to zram costs a decompress, not an NVMe round trip, so it is
        # worth doing far earlier than the default 60 assumes.
        kernel.sysctl."vm.swappiness" = 150;

        # Readahead exists to amortise seeks. zram has none, so faulting in the
        # default 8 pages just decompresses 7 nobody asked for.
        kernel.sysctl."vm.page-cluster" = 0;
      };

      # A compressed swap device held in RAM. Buys roughly 3x its own footprint
      # back as headroom for the cold, highly compressible pages a wide rustc
      # fan-out leaves behind, and absorbs the spike far faster than the 8 GB
      # disk partition can. 25% rather than the 50% default: this only has to
      # cover a spike, and every page it stores is RAM the build cannot use.
      zramSwap = {
        enable = true;
        memoryPercent = 25;
      };

      # networking / locale
      networking = {
        hostName = "strix";
        networkmanager.enable = true;
      };

      # Held boot for ~5s waiting on a link. Nothing here needs the network up
      # before login, and a laptop is often offline anyway.
      systemd.services.NetworkManager-wait-online.enable = false;

      time.timeZone = "America/Toronto";
      i18n.defaultLocale = "en_CA.UTF-8";

      # nvidia: prime offload - the intel igpu drives the display; the 4090 stays
      # powered down until something asks for it via `nvidia-offload <cmd>`.
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

      # ollama: the cuda build is what puts it on the 4090, and
      # `services.ollama.package` is the only thing that selects a backend since
      # `acceleration` was removed upstream. It does NOT need the `nvidia-offload`
      # wrapper - that only redirects GLX/Vulkan; creating a cuda context alone
      # pulls the dgpu back out of its finegrained runtime suspend, so the gpu
      # stays awake while a model is resident (OLLAMA_KEEP_ALIVE, 5 minutes by
      # default). Under the battery-saver specialisation the dgpu is gone and
      # ollama falls back to CPU.
      services.ollama = {
        package = pkgs.ollama-cuda;
        # ~7GB of the 16GB of VRAM; add more with `ollama pull`, or here to
        # have them fetched on rebuild.
        loadModels = [ "mistral-nemo" ];
      };

      services.ollaya = {
        enable = true;
        package = pkgs.ollaya.override {
          onnxruntime = pkgs.onnxruntime.override { cudaSupport = true; };
          llama-cpp = pkgs.llama-cpp.override { cudaSupport = true; };
        };
        loadModels = [ "winnow:e4b" ];
        settings.OLLAYA_DEVICE = "auto";
      };

      # asus: rgb off + battery charge limit
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

      # desktop (gnome, as installed)
      services.xserver = {
        enable = true;
        xkb = {
          layout = "us";
          variant = "";
        };
      };
      services.displayManager.gdm.enable = true;
      services.desktopManager.gnome.enable = true;

      # gnome turns this on (mkDefault true, type "ibus"), which drops an
      # ibus-daemon XDG autostart entry marked NotShowIn=GNOME;KDE - gnome-shell
      # and kwin each start ibus themselves. niri is neither, so the entry fires,
      # ibus finds a wayland session nobody wired it into, and notifies about it
      # on every login. Nothing here uses an input engine beyond xkb:us, so drop
      # ibus rather than teach niri to host it.
      i18n.inputMethod.enable = false;

      # niri: a scrollable-tiling wayland compositor, and the session GDM logs
      # into by default. GNOME stays installed as the fallback - pick it from the
      # gear menu at the login screen if something is broken under niri. The
      # nixpkgs module handles the session file, the portals
      # (xdg-desktop-portal-gnome, needed for screen sharing) and gnome-keyring;
      # everything user-facing (config.kdl, bar, launcher, notifications, idle)
      # lives in homes/niri/.
      programs.niri.enable = true;

      # programs.niri already sets this with mkDefault; stated explicitly so the
      # choice is recorded here rather than inherited from the module.
      services.displayManager.defaultSession = "niri";

      # swaylock authenticates through PAM and there is no NixOS module for it.
      # Without this stanza it rejects every password and the only way out of
      # the lock screen is a VT switch.
      security.pam.services.swaylock = { };

      # Remap the MX Master 3S over HID++. launchAtLogin would put the agent on
      # graphical-session.target, which GNOME reaches too, so it is off here and
      # the agent is started by niri.service instead - the same treatment the
      # bar and the idle daemon get in homes/niri/. partOf is what stops it
      # again on logout rather than leaving it to the user manager's linger.
      programs.openlogi = {
        enable = true;
        launchAtLogin = false;
      };
      systemd.user.services.openlogi-agent = {
        wantedBy = [ "niri.service" ];
        partOf = [ "niri.service" ];
      };

      # Handy (packages/gui.nix) types by injecting below the compositor, which
      # is the only path that reaches native Wayland windows here - XTest
      # through xwayland-satellite reaches X11 clients only. Its handy_keys
      # backend grabs /dev/input and re-injects through a uinput clone, so it
      # wants the module, the udev rule and the group this brings (granted to
      # the user below). ydotool is the fallback typing tool it shells out to
      # when wtype is unusable, and this is what puts the daemon behind it up.
      hardware.uinput.enable = true;
      programs.ydotool.enable = true;

      # LocalSend: the phone's counterpart to AirDrop. The module opens its one
      # port (53317 TCP+UDP) on every interface, because discovery is UDP
      # multicast and has to reach whatever wifi this laptop is on; every
      # transfer still needs an accept here.
      programs.localsend.enable = true;

      services.printing.enable = true;

      # Firmware updates from LVFS: the NVMe drives, thunderbolt, and whatever
      # ASUS publishes there. `fwupdmgr get-updates`, then `fwupdmgr update`.
      services.fwupd.enable = true;

      # Rootless containers, so an agent can `docker run postgres` for an
      # integration test instead of guessing. dockerCompat puts `docker` on
      # PATH as podman.
      virtualisation.podman = {
        enable = true;
        dockerCompat = true;
        # containers on a compose network resolve each other by name
        defaultNetwork.settings.dns_enabled = true;
      };

      # Hourly read-only snapshots of /home, for undoing what an agent (or I)
      # just broke: `ls /.snapshots`, copy back what you need. Each one is also
      # sent incrementally to the second drive, which survives this one dying.
      services.btrbk.instances.home = {
        onCalendar = "hourly";
        settings = {
          snapshot_preserve_min = "2d";
          snapshot_preserve = "48h 14d 8w";
          # the other drive has the room for a longer history
          target_preserve_min = "no";
          target_preserve = "48h 14d 8w 12m";
          volume."/" = {
            snapshot_dir = ".snapshots";
            subvolume = "home";
            # not created by tmpfiles on purpose: with the drive unmounted it
            # would land on the root fs, and btrbk would back up onto itself
            target = "/mnt/backup/home";
          };
        };
      };
      # btrbk refuses to create its own snapshot_dir
      systemd.tmpfiles.rules = [ "d /.snapshots 0755 root root -" ];

      # `nh os switch` = nixos-rebuild + nom + a closure diff, in one command.
      # Its clean timer is left off: nix.gc below already owns that.
      programs.nh = {
        enable = true;
        flake = "/home/yt/dotfiles";
      };

      # GNOME brings avahi, and resolved answers mDNS too: two responders on
      # one port, which avahi warns makes discovery unreliable. Avahi is the one
      # cups and GNOME talk to, so it keeps the job and gets the NSS hook.
      services.avahi.nssmdns4 = true;
      services.resolved.settings.Resolve.MulticastDNS = false;

      services.pulseaudio.enable = false;
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };

      # users. NOTE: mutableUsers stays true, unlike bee/hetz - the install-time
      # password is kept; switch to hashedPassword + mutableUsers = false once
      # you've run `mkpasswd -m sha-512`.
      users.users.yt = {
        isNormalUser = true;
        description = "yt";
        # `input`, `uinput` and `ydotool` are Handy's, not the session's: it
        # reads /dev/input directly, re-injects through /dev/uinput, and falls
        # back to the socket ydotoold owns.
        extraGroups = [
          "networkmanager"
          "wheel"
          "video"
          "input"
          "uinput"
          "ydotool"
        ];
        shell = pkgs.nushell;
      };

      environment = {
        shells = [ pkgs.nushell ];
        systemPackages = with pkgs; [
          vim
          git
          lsof
          perf
          gptfdisk # sgdisk
          cryptsetup
          agenix.packages.x86_64-linux.default
        ];

        # /etc/set-environment, so the desktop session and sudo get helix too:
        # neither reads nushell's env.nu, and a tool with an `EDITOR-or-vi`
        # default would open vim. nixpkgs only ships nano here, by mkDefault.
        variables = {
          EDITOR = "hx";
          VISUAL = "hx";
        };
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

      # nix
      nix = {
        package = pkgs.nixVersions.latest;
        settings = {
          # cores = 0 gave each cuda build all 32 threads - one cicc per .cu at
          # 1-2GB - and two such jobs at once (llama-cpp + onnxruntime) took 33GB.
          cores = 8;
          max-jobs = 2;
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

            # numtide's cache. Its key names niks3.numtide.com even though the
            # URL is cache.numtide.com - the key name is what the signature
            # carries, so that string is what has to be trusted. The llm-agents
            # flake declares both in its own nixConfig, but that only applies
            # when you build that flake directly, so they are declared here.
            #
            # It carries their packages built against nixpkgs-unstable's current
            # HEAD, not only against their own pin, which is what lets the
            # llm-agents overlay in the nixpkgs block above follow nixpkgs and
            # still substitute: codex, reasonix, openresearch, rtk, icm, nono,
            # opencode2 and claude-code all come down as downloads. A miss would
            # not break anything, it would build that one package here.
            "https://cache.numtide.com"
          ];
          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
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
          # A laptop is rarely up at 03:15, so the default Persistent=true turns
          # every missed run into a catch-up that fires seconds into the next
          # boot. After five days down that was 16.7 GB and 15041 paths, which
          # held the screen black for 37s past the password prompt.
          persistent = false;
        };
      };

      # Belt to the above's braces, for the runs that do land while I am typing.
      # Only the CPU half bites on this machine: ionice needs a scheduler that
      # honours ioprio and both NVMEs run `none`.
      systemd.services.nix-gc.serviceConfig = {
        CPUSchedulingPolicy = "idle";
        IOSchedulingClass = "idle";
      };

      # Without a ceiling the OOM killer takes the desktop instead: user@.service
      # carries OOMScoreAdjust=100 while nixbld sits at 0, so a 12 GB rustc outranks
      # every session process. Kill inside the build cgroup instead.
      systemd.services.nix-daemon.serviceConfig = {
        MemoryHigh = "40G";
        MemoryMax = "48G";
      };

      # Every reboot sat 90s on a terminal scope: claude processes spawned after
      # the reboot request ignore SIGTERM until the stop timeout SIGKILLs them.
      systemd.user.settings.Manager.DefaultTimeoutStopSec = "10s";

      nixpkgs = {
        config.allowUnfree = true;
        overlays = [
          # puts `rust-bin` in scope for packages/dev/rust-toolchain.nix.
          # Everything it provides is fetched from static.rust-lang.org rather
          # than built, so this costs a download, not a compile.
          rust-overlay.overlays.default

          # Every agent CLI this machine runs, from numtide/llm-agents.nix. This
          # is the only place it is read: it shadows the nixpkgs names -
          # claude-code, codex, handy,
          # rtk, icm, nono, tuicr, herdr - so homes/programs/*.nix and
          # packages/*.nix go on saying pkgs.claude-code and pkgs.rtk without
          # knowing where they came from.
          #
          # `opencode` is that flake's `opencode2`. Upstream v2's binary really is
          # called `opencode`, which llm-agents renames so it can coexist with
          # v1's; only v2 is used here, and the HM module, the serve unit, the
          # state directory and the agent instructions all say `opencode`, so the
          # symlink buys the name back. A symlinkJoin rather than an
          # overrideAttrs: an override would rebuild llm-agents' cached path,
          # this keeps its patched binary and only adds a link.
          #
          # `reasonix` is the one package that is overridden, and not by
          # rebuilding it either - see the wrapper below for the two env defaults
          # this machine wants and llm-agents does not set.
          (
            final: _prev:
            let
              sys = final.stdenv.hostPlatform.system;
              lm = llm-agents.packages.${sys};
            in
            {
              claude-code = lm.claude-code;
              codex = lm.codex;
              opencode2 = lm.opencode2;
              rtk = lm.rtk;
              icm = lm.icm;
              funes = lm.funes;
              nono = lm.nono;
              terminal-browser = lm.terminal-browser;
              openresearch = lm.openresearch;
              tuicr = lm.tuicr;
              ccusage = lm.ccusage;
              codegraph = lm.codegraph;
              jscpd = lm.jscpd;
              ck = lm.ck;
              semble = lm.semble;
              plannotator-tui = lm.plannotator-tui;
              agent-browser = lm.agent-browser;
              handy = lm.handy;

              # llm-agents' herdr, relinked with lld - the one binding in this
              # block that is not their derivation untouched. Theirs does not link
              # on this machine: rustc passes `-Wl,--eh-frame-hdr`, and ld.bfd then
              # rejects the FDEs in the vendored zig-built libghostty-vt with
              # ".eh_frame_hdr refers to overlapping FDEs". mold gets past that and
              # then refuses zig's compiler_rt.o outright (undefined symbols with
              # no name at all). lld links it and keeps the .eh_frame_hdr table;
              # turning the header off links too, but throws that table away.
              #
              # Overriding costs no substitution: this output path is not in
              # numtide's cache either way, which is the same reason there is
              # nothing to preserve here the way the reasonix wrapper preserves
              # theirs. Delete it when their derivation links on its own.
              herdr = lm.herdr.overrideAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.lld ];
                RUSTFLAGS = "-C link-arg=-fuse-ld=lld";
              });

              opencode = final.symlinkJoin {
                name = "opencode-${lm.opencode2.version}";
                paths = [ lm.opencode2 ];
                postBuild = ''ln -s opencode2 "$out/bin/opencode"'';
                inherit (lm.opencode2) version;
                meta = lm.opencode2.meta // {
                  mainProgram = "opencode";
                };
              };

              # llm-agents wraps reasonix with codegraph, ripgrep and bubblewrap
              # on PATH but leaves the environment alone. Two things go on top,
              # both in reasonix.nu, which is what stands in front of the binary:
              #
              # REASONIX_TELEMETRY=0 is this machine's standing choice - see
              # homes/programs/ai-context.nix for the other tools it is set for.
              #
              # The other is the renderer. reasonix has exactly one that stays
              # out of the alternate screen and appends to the terminal's own
              # scrollback, and since 2.28.0 `reasonix tui --inline` is the only
              # way to ask for it: the Termux sniff that used to select it is
              # gone from the binary, so the TERMUX_VERSION this wrapper set for
              # the same purpose went inert on that bump. Unasked, a zellij pane
              # running reasonix keeps alt-screen content only, and Ctrl+S and
              # the wheel stop at the top of the current frame.
              #
              # Wrapped as a symlinkJoin rather than an overrideAttrs so the Go
              # binary stays the one llm-agents built, which substitutes; an
              # override would recompile it on this machine on every bump.
              reasonix = final.symlinkJoin {
                name = "reasonix-${lm.reasonix.version}";
                paths = [ lm.reasonix ];
                postBuild = ''
                  # reasonix-bin is llm-agents' own entry point, left beside the
                  # router, which finds it by its own directory.
                  mv "$out/bin/reasonix" "$out/bin/reasonix-bin"
                  install -m 755 ${./reasonix.nu} "$out/bin/reasonix"
                '';
                inherit (lm.reasonix) version meta;
              };

              # mcptoon installs an agent-visible skill for every coding agent it
              # detects, and its config module does that on *import* - so any
              # invocation, `mcptoon --help` included, drops a SKILL.md into
              # ~/.claude/skills, ~/.codex/skills, ~/.agents/skills and friends,
              # all of which this repo generates. Measured, not assumed: a run
              # against a scratch HOME created six of them before printing help.
              #
              # Its own escape hatch is MCPTOON_SKIP_SELF_HEAL, so the wrapper
              # forces it rather than defaulting it - a guard a stray environment
              # variable can lift is not a guard. The store binary is still there
              # unwrapped if the skill install is ever wanted deliberately.
              mcptoon = final.symlinkJoin {
                name = "mcptoon-${lm.mcptoon.version}";
                paths = [ lm.mcptoon ];
                nativeBuildInputs = [ final.makeBinaryWrapper ];
                postBuild = ''
                  wrapProgram "$out/bin/mcptoon" \
                    --set MCPTOON_SKIP_SELF_HEAL 1
                '';
                inherit (lm.mcptoon) version meta;
              };
            }
          )

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

      services.journald.settings.Journal = {
        MaxFileSec = "1day";
        MaxRetentionSec = "1month";
        SystemMaxUse = "2G";
      };

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

    # programs.claude-code takes ownership of ~/.claude/CLAUDE.md and
    # ~/.claude/settings.json, which already exist as plain files. Without a
    # backup extension, activation aborts rather than clobbering them; with it,
    # the originals are moved to *.hm-bak on the first rebuild.
    home-manager.backupFileExtension = "hm-bak";
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
        imports = [
          agenix.homeManagerModules.default
          # nix-index with a prebuilt database, plus comma: `, sqlite3` runs a
          # command that is not installed, instead of "command not found"
          nix-index-database.homeModules.nix-index
          ../../homes/niri
          # Shared MCP registry first - all four agents read it.
          ../../homes/programs/ai-mcp.nix
          ../../homes/programs/claude-code.nix
          ../../homes/programs/opencode.nix
          ../../homes/programs/codex.nix
          # ~/.reasonix/config.toml, which is what turns that registry into
          # plugins for the fourth agent. Last of the four on purpose: it reads
          # programs.mcp.servers, including crw's entry below.
          ../../homes/programs/reasonix.nix
          # Sandboxed launchers over those three, nono-claude / nono-codex /
          # nono-reasonix. After them on purpose: it reads
          # programs.claude-code.finalPackage and programs.codex.package.
          ../../homes/programs/nono.nix
          # Serves that same opencode over the mesh, for the phone.
          ../../homes/programs/opencode-server.nix
          # Registers its own MCP server next to the units it talks to.
          ../../homes/programs/crw.nix
          # ~/.symposium/config.toml, so `cargo agents init` never has to run.
          ../../homes/programs/symposium.nix
          # ~/.cargo/config.toml, which is what makes rustc cache through sccache
          # and link with mold.
          ../../homes/programs/cargo.nix
          # ctrl-space command search. Seeds its own store, so it is a module
          # rather than a programs entry.
          ../../homes/programs/intelli-shell
          # Monday-morning digest of releases in my starred repos.
          ../../homes/programs/starred-digest
          # The pueued user service and ~/.config/pueue/pueue.yml, so a queue
          # outlives the terminal that started it.
          ../../homes/programs/pueue.nix
          # The ccusage prompt segment. Separate from homes/common.nix's starship
          # block because it needs a package only strix has.
          ../../homes/programs/ccusage.nix
          # Seeds ~/.config/openlogi/config.toml for the MX Master 3S, once.
          ../../homes/programs/openlogi.nix
          # ~/.config/terminal-browser/settings.json, which no upstream module
          # writes, so the render settings it would otherwise take by default
          # are declared there instead.
          ../../homes/programs/terminal-browser.nix
        ];

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
            ++ (import ../../packages/gui.nix { inherit pkgs; })
            ++ (import ../../packages/office.nix { inherit pkgs; })
            ++ (import ../../packages/package_managers.nix { inherit pkgs; })
            ++ (import ../../packages/dev/rust.nix { inherit pkgs; })
            # rustc/cargo/clippy/rustfmt/rust-analyzer at stable latest, plus the
            # cargo subcommands worth having on PATH. Workstation only - it needs
            # the rust-overlay overlay applied above.
            ++ (import ../../packages/dev/rust-toolchain.nix { inherit pkgs; })
            ++ (import ../../packages/dev/python.nix { inherit pkgs; })
            # general dev and debugging tools an agent expects to find
            ++ (import ../../packages/dev/tools.nix { inherit pkgs; })
            ++ (import ../../packages/dev/nix.nix { inherit pkgs; });
        };

        age.secrets.deepseek-api-key = {
          file = ../../secrets/deepseek.api.key.age;
          path = "${config.home.homeDirectory}/.reasonix/.env";
        };

        # The same ciphertext again, for the second Reasonix home that
        # `nono-reasonix` runs with (homes/programs/nono.nix). Separate entry
        # rather than a symlink between the two so that neither home depends on
        # the other existing.
        age.secrets.deepseek-api-key-nono = {
          file = ../../secrets/deepseek.api.key.age;
          path = "${config.home.homeDirectory}/.reasonix-nono/.env";
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
            # Keeps the cache behind a bare `tldr <cmd>` fresh, via the
            # services.tldr-update user timer this pulls in.
            tealdeer = import ../../homes/programs/tealdeer.nix { inherit pkgs; };
            nix-index-database.comma.enable = true;

          };
      }
    );
  }
]
