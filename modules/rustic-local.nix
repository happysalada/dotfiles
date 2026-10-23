# Local backups of /home and /var/lib/fundies onto the second drive with rustic,
# replacing btrbk's persistent /home snapshot. Same tool, package and secret
# conventions as rustic.nix (the offsite B2 job); the repositories are independent.
# Source snapshots exist only during a run; design and cutover in
# docs/rustic-local-backup.md.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # The units, then what they read, in order of first use.

  job =
    description: extra:
    lib.recursiveUpdate common (
      {
        inherit description;
        onFailure = [ "rustic-local-failed@%n.service" ];
      }
      // extra
    );

  common = {
    path = [
      (import ./rustic-package.nix pkgs)
      pkgs.btrfs-progs
      pkgs.util-linux
      pkgs.coreutils
      pkgs.procps
    ];
    environment = {
      BACKUP_MOUNT = mount;
      BACKUP_FS_UUID = fsUuid;
      RUSTIC_REPOSITORY = repository;
      RUSTIC_CACHE_DIR = cacheDir;
      RUSTIC_PASSWORD_FILE = config.age.secrets.rustic-local-password.path;
      SNAP_DIR = snapDir;
      TOPLEVEL = "/";
      PROTECTED = builtins.toJSON (map (d: d // { globs = "${globFile "rustic-local-${d.name}" d.excludes}"; }) protected);
      KEEP_DAILY = toString keep.daily;
      KEEP_WEEKLY = toString keep.weekly;
      KEEP_MONTHLY = toString keep.monthly;
      CHECK_SUBSET = "5%";
    };
    unitConfig.RequiresMountsFor = mount;
    serviceConfig = {
      Type = "oneshot";
      Nice = 19;
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
    };
  };

  mount = "/mnt/backup";
  # The btrfs inside /dev/mapper/cryptbackup: a different or missing drive fails
  # the run instead of filling whatever sits at the mount point.
  fsUuid = "8b025d72-8310-4adc-b1ed-bd592b9089e4";
  repository = "${mount}/rustic/strix";
  cacheDir = "${mount}/rustic/cache"; # not /var/cache: that costs the primary disk
  snapDir = "/.rustic-snapshots";

  # `tree` is the path from the filesystem root, as `btrfs subvolume list` prints
  # it. /var/lib/fundies is a plain directory, so its volume is /. `excludes` are
  # rustic's exclusion globs, anchored at `path`; the subvolume audit tests
  # against the same list, so an excluded tree never fails a run.
  protected = [
    {
      name = "home";
      volume = "/home";
      path = "/home";
      tree = "home";
      excludes = [
        # Rebuildable
        "**/.cache/**"
        "**/.local/share/Trash/**"
        "**/node_modules/**"
        "**/target/**"
        "**/.venv/**"
        "**/__pycache__/**"
        "**/.direnv/**"
        # Agent scratch: one session's tmp/ alone was 14G of experiment output,
        # and these caches are rebuilt on the next start. The rest of
        # ~/.claude/jobs is kept - state.json and timeline.jsonl are tiny.
        "/yt/.claude/jobs/*/tmp"
        "/yt/.claude/jobs/*/tmp/**"
        "/yt/.reasonix/browser"
        "/yt/.reasonix/browser/**"
        "/yt/.reasonix/logs"
        "/yt/.reasonix/logs/**"
        "/yt/.reasonix/mcp-state"
        "/yt/.reasonix/mcp-state/**"
        "/yt/.codex/cache"
        "/yt/.codex/cache/**"
        # Reflink copies of /var/lib/fundies until post-cutover cleanup deletes
        # them; 735 GiB would be read twice. They stay on disk until that runs.
        "/yt/dev/fundies/data"
        "/yt/dev/fundies/data/**"
        "/yt/dev/fundies/crates/store/data"
        "/yt/dev/fundies/crates/store/data/**"
        "/yt/dev/fundies/crates/archiver/data"
        "/yt/dev/fundies/crates/archiver/data/**"
      ];
    }
    {
      name = "fundies";
      volume = "/";
      path = "/var/lib/fundies";
      tree = "var/lib/fundies";
      excludes = [
        # Copied into serving objects on publication
        "/publication-work/*/candidate"
        "/publication-work/*/candidate/**"
        # Vector index, rebuilt from the full text
        "/filings/qdrant"
        "/filings/qdrant/**"
      ];
    }
  ];

  # `!` makes a rustic glob an exclusion.
  globFile = name: globs: pkgs.writeText name (lib.concatMapStrings (g: "!${g}\n") globs);

  # A week of days, a month of weeks, half a year of months; see the doc.
  keep = {
    daily = 7;
    weekly = 4;
    monthly = 6;
  };

  # One backup at a time (snap); backups share the repository, forget and check
  # take it alone (repo).
  backupCommand = "${flock} --nonblock ${lockDir}/rustic-local-snap.lock ${flock} --shared --timeout 43200 ${lockDir}/rustic-local-repo.lock ${nu} backup";
  sweepCommand = "${flock} --nonblock --conflict-exit-code 0 ${lockDir}/rustic-local-snap.lock ${nu} sweep";
  exclusive =
    verb: "${flock} --exclusive --timeout 43200 ${lockDir}/rustic-local-repo.lock ${nu} ${verb}";

  flock = "${pkgs.util-linux}/bin/flock";
  lockDir = "/run/lock";
  nu = "${pkgs.nushell}/bin/nu --no-config-file ${script}";
  script = ./rustic-local.nu;

  notify = pkgs.writeShellScript "rustic-local-failed" ''
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
    detail=$(journalctl -u "$1" -n 20 --no-pager -o cat 2>/dev/null | tail -n 1 | cut -c1-240)
    ${pkgs.libnotify}/bin/notify-send -a rustic -u critical "$1 failed" "''${detail:-journalctl -u $1}"
  '';
  user = "yt";
in
{
  age.secrets.rustic-local-password.file = ../secrets/rustic-local.password.age;

  # Snapshots only; the repository and its cache go on the verified drive.
  systemd.tmpfiles.rules = [ "d ${snapDir} 0700 root root -" ];

  systemd.timers.rustic-local-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 03:30:00";
      Persistent = true;
    };
  };

  systemd.timers.rustic-local-forget = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun *-*-* 07:00:00";
      Persistent = true;
    };
  };

  systemd.timers.rustic-local-check = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Wed *-*-* 07:00:00";
      Persistent = true;
    };
  };

  systemd.services.rustic-local-backup =
    job "Back up /home and /var/lib/fundies to the backup drive"
      {
        serviceConfig.ExecStart = backupCommand;
        # also after a kill, so no snapshot outlives its run
        serviceConfig.ExecStopPost = sweepCommand;
      };

  systemd.services.rustic-local-forget = job "Apply retention to the local rustic repository" {
    serviceConfig.ExecStart = exclusive "forget";
  };

  systemd.services.rustic-local-check = job "Verify the local rustic repository" {
    serviceConfig.ExecStart = exclusive "check";
  };

  systemd.services.rustic-local-init = job "Create the local rustic repository on the backup drive" {
    serviceConfig.ExecStart = exclusive "init";
  };

  systemd.services.rustic-local-preflight =
    job "Dry run of the local backup: snapshots and repository, no data written"
      {
        serviceConfig.ExecStart = "${backupCommand} --preflight";
        serviceConfig.ExecStopPost = sweepCommand;
      };

  systemd.services."rustic-local-failed@" = {
    description = "announce that %i failed";
    serviceConfig = {
      Type = "oneshot";
      User = user;
      Group = "users";
      ExecStart = "${notify} %i";
    };
  };
}
