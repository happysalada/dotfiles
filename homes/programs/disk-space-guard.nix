# Warn before the root filesystem fills. A full / is how one boot turns into
# journald, nix-daemon, cups, agenix and half the user units failing on ENOSPC
# at once, while btrbk's own deletions are the only thing that frees it again.
#
# A user unit because mako is a user service and the warning is only useful to
# the session that is looking at it; disk-space-guard.nu does the deciding.
{ pkgs, ... }:
{
  systemd.user.services.disk-space-guard = {
    Unit.Description = "warn when the root filesystem is close to full";

    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.nushell}/bin/nu ${./disk-space-guard.nu}";
      Environment = [ "PATH=${pkgs.coreutils}/bin:${pkgs.libnotify}/bin" ];
    };
  };

  systemd.user.timers.disk-space-guard = {
    Unit.Description = "hourly disk-space check";

    Timer = {
      OnCalendar = "hourly";
      # also soon after login, so a boot that starts above the line says so
      # instead of waiting for the next hour.
      OnStartupSec = "2min";
      Persistent = true;
    };

    Install.WantedBy = [ "timers.target" ];
  };
}
