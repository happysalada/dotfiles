# modules/fundies-gleif.nix
#
# Refreshing GLEIF's golden copy, which is what lets a Japanese filer join GLEIF at all: an EDINET
# filing states no LEI, so the crosswalk joins on the corporate number instead, and that join reads
# GLEIF's published file rather than its API (which cannot be asked about a number).
#
# Weekly rather than daily, and two copies rather than all of them: a copy is 635 MB of the whole
# LEI population, GLEIF republishes it every morning whether or not anything of ours changed, and
# the inputs move slowly — a Japanese filer gaining an LEI is a rare event. The retention is the
# fetch's own (--keep, default 2), so nothing here deletes anything.
{ ... }:
let
  user = "yt";
  repo = "/home/yt/dev/fundies";
in
{
  systemd.services.fundies-gleif = {
    description = "Fetch GLEIF's golden copy and rebuild the registry-number index";

    serviceConfig = {
      Type = "oneshot";
      User = user;
      Group = "users";
      WorkingDirectory = repo;
      Environment = [
        "PATH=/etc/profiles/per-user/${user}/bin:/run/current-system/sw/bin"
        "HOME=/home/${user}"
      ];
      Nice = 10;
      IOSchedulingClass = "idle";
      # 635 MB down, 8.5 GB read: minutes, not the EDINET parse's hours.
      TimeoutStartSec = "4h";
    };

    script = ''
      set -euo pipefail
      # The copy, pruned down to the newest two as it goes.
      just entity-golden
      # And the Japanese records the crosswalk joins on, from what just landed.
      just entity-golden-index
    '';
  };

  systemd.timers.fundies-gleif = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Sunday, an hour after the daily EDINET job, so the two are not on the same disk at once.
      OnCalendar = "Sun *-*-* 13:00:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };
}
