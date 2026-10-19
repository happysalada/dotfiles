# modules/commonage-edinet.nix
#
# Keeping the EDINET side of the commonage archive current, and parsed.
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
{ ... }:
let
  user = "yt";

  # Where the checkout lives, and where its EDINET release accumulates. Partitions are
  # keyed by the bytes they were made from, so re-running the parse adds the filings
  # that are new and leaves every other partition alone; one already complete at the
  # current format is skipped without being read. A new name here is how one is frozen.
  #
  # 2026-10-16 is stale and stays that way: the partition paths were re-keyed to
  # `source_blake3=<digest>/filing_id=<id>` and the taxonomy input set gained six
  # 2013-08-31 schemas, so every manifest under it now mismatches and a run there
  # would rewrite what it touched. Rebuild into the new root instead.
  repo = "/home/yt/dev/commonage";
  release = "data/releases/edinet/2026-10-19";

  # The taxonomy vintages the filings were made under. `catalog fetch-edinet` is
  # idempotent — a package already in the store is not fetched again — and a filing
  # whose own vintage is missing decodes without the labels and types its taxonomy
  # declares, which is why they are named rather than left to the default.
  years = "2015,2016,2017,2018,2019,2020,2021,2022,2023,2024,2025,2026";
in
{
  systemd.services.commonage-edinet = {
    description = "Walk and parse new EDINET filings into the commonage release";

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
      # Nothing here is urgent: it may be hours behind the newest filing without anyone
      # being able to tell, so it yields to whatever the machine is actually doing.
      Nice = 10;
      IOSchedulingClass = "idle";
      # The first parse of a full archive decodes every filing in it — hours of work, far
      # past systemd's 90-second default, which would kill it part-way and leave the
      # release half made. Later runs decode only what is new.
      TimeoutStartSec = "48h";
    };

    script = ''
      set -euo pipefail

      # pueue's socket lives here, and the walk jobs are queued through it. The
      # service already runs as the user, so the kernel is the one place that
      # knows the uid.
      export XDG_RUNTIME_DIR="/run/user/$(id -u)"

      # Days in the rolling window that are missing, or whose walk failed.
      just edinet-schedule --all

      # Then the taxonomy the filings are read under, and the parse itself.
      cargo run --release --locked -p commonage-archiver -- \
        --root ${repo}/crates/store/data \
        catalog fetch-edinet --years ${years}
      # The limit has to clear the whole archive, not just what is new: a pass that hits
      # it stops early and never reaches the later filings, which is how this release
      # never grew past 2023-11-13 while every run reported success. 500000 is above the
      # 426,921 main ZIPs held and leaves room for the archive to grow. Partitions
      # already made at the current format are skipped, so the cap only bounds the work
      # a first pass on a new root has to do.
      #
      # `--allow-undecodable` keeps the unit green on the handful of filings nothing can
      # decode yet - two malformed source ZIPs, two where one ZIP is served under two
      # document ids, and one whose IFRS ja label linkbase returns 404 upstream. They
      # are named in the log rather than failing the run; the flag is for a schedule,
      # and the fix belongs in the decoder or upstream, not in a red unit.
      cargo run --release --locked -p commonage-archiver -- \
        --root ${repo}/crates/store/data \
        decode-edinet --out ${repo}/${release} --limit 500000 --years ${years} \
        --allow-undecodable
    '';
  };

  systemd.timers.commonage-edinet = {
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
