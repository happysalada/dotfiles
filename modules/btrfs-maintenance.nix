# Scheduled btrfs upkeep for both disks: a monthly scrub and a weekly balance.
# Data is the `single` profile, so a scrub detects bad data but can only repair
# metadata (DUP); it tells you when to restore from backup.
{
  lib,
  pkgs,
  ...
}:
let
  # Metadata chunks are never handed back on their own; this returns the ones
  # under half full, and data chunks under 5%, to the unallocated pool.
  balanceService = fs: {
    name = "btrfs-balance-${fs.name}";
    value = {
      description = "Balance sparse btrfs chunks on ${fs.path}";
      # the backup drive is nofail and may be absent
      unitConfig.ConditionPathIsMountPoint = fs.path;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe' pkgs.btrfs-progs "btrfs"} balance start -musage=50 -dusage=5 ${fs.path}";
        Nice = 19;
        IOSchedulingClass = "idle";
      };
    };
  };

  # Tuesdays, clear of the Sunday forget, Wednesday check and the monthly scrub.
  balanceTimer = fs: {
    name = "btrfs-balance-${fs.name}";
    value = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Tue *-*-* 05:00:00";
        Persistent = true;
      };
    };
  };

  filesystems = [
    {
      name = "root";
      path = "/";
    }
    {
      name = "backup";
      path = "/mnt/backup";
    }
  ];
in
{
  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = map (fs: fs.path) filesystems;
    # after rustic-local's 03:30 run; the units run at idle IO priority
    interval = "*-*-01 04:30:00";
  };

  systemd.services = lib.listToAttrs (map balanceService filesystems);

  systemd.timers = lib.listToAttrs (map balanceTimer filesystems);
}
