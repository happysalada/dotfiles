# modules/fundies-edinet.nix
#
# Queueing the walks that keep the EDINET side of the fundies archive current.
#
# The archive is filled one calendar day at a time, and the walk for a day has to be
# *started* by something. `just edinet-schedule` queues only the days that are not
# already queued, running or successful, which makes a daily run both incremental and
# self-healing: a day whose walk failed is queued again the next time this fires, and a
# machine that was off simply owes one run.
#
# The hour is not arbitrary. A day is walked once and its label then counts as done
# forever, so the walk for a Japanese day must run after that day has *ended* in Japan
# — Japan is 13 hours ahead of EDT and 14 ahead of EST, so midnight there is 11:00 or
# 10:00 here, and noon local is the first hour by which the list for the Japanese day
# just gone cannot grow any more. Running earlier would archive a truncated day and
# never revisit it. `Persistent` catches up a run the machine slept through, the same
# reason modules/prefect-local.nix gives for its timers.
#
# The scheduler fetches nothing itself: it queues jobs for pueue, which is a per-user
# daemon, so this runs as the desktop user with that user's runtime directory. The jobs
# it queues invoke `fnox` for the EDINET key, which is why the PATH below is the user's
# own profile — the run then uses exactly what a run from their shell uses.
#
# Parsing what the walks fetch is a separate unit on a separate clock, in
# modules/fundies-release.nix.
{ ... }:
let
  user = "yt";
  repo = "/home/yt/dev/fundies";
in
{
  systemd.services.fundies-edinet = {
    description = "Queue the walks for missing EDINET days";

    serviceConfig = {
      Type = "oneshot";
      User = user;
      Group = "users";
      WorkingDirectory = repo;
      Environment = [
        # `path` would append /bin to each entry; this is the PATH the user's shell has.
        "PATH=/etc/profiles/per-user/${user}/bin:/run/current-system/sw/bin"
        "HOME=/home/${user}"
        # XDG_RUNTIME_DIR is set in the script instead: it wants the uid, and
        # this machine keeps mutableUsers on, so `users.users.${user}.uid` is
        # null - `toString null` is empty, which is a path with no directory in
        # it and a pueue that cannot find its daemon.
      ];
    };

    script = ''
      set -euo pipefail

      # pueue's socket lives here, and the walk jobs are queued through it. The
      # service already runs as the user, so the kernel is the one place that
      # knows the uid.
      export XDG_RUNTIME_DIR="/run/user/$(id -u)"

      # Days in the rolling window that are missing, or whose walk failed.
      just edinet-schedule --all
    '';
  };

  systemd.timers.fundies-edinet = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 12:00:00";
      Persistent = true;
      # A quarter of an hour either way, so several machines sharing the EDINET request
      # budget do not all ask at once.
      RandomizedDelaySec = "15m";
    };
  };
}
