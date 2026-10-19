# modules/commonage-release.nix
#
# Parsing the EDINET filings commonage has already walked into a release.
#
# The walks and the parse share the archive but not a clock: the day's walks are queued
# at noon by modules/commonage-edinet.nix, one short pueue job each, so by the evening
# the Japanese day they cover has settled and everything the archive holds can be read.
# Split out of that module so a long or failing parse delays neither the next day's
# walks nor itself.
#
# The release root is rolling and this unit never rotates it: a pass adds only the
# filings that arrived, and the refusal `decode-edinet` gives when the taxonomy inputs
# change is the signal for a human to move it.
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
  systemd.services.commonage-release = {
    description = "Parse EDINET filings into the commonage release";

    serviceConfig = {
      Type = "oneshot";
      User = user;
      Group = "users";
      WorkingDirectory = repo;
      Environment = [
        # `path` would append /bin to each entry; this is the PATH the user's shell has.
        "PATH=/etc/profiles/per-user/${user}/bin:/run/current-system/sw/bin"
        "HOME=/home/${user}"
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

      # The taxonomy the filings are read under. A failed fetch stops the run here.
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

  systemd.timers.commonage-release = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 21:00:00";
      Persistent = true;
      # Deliberately no ordering against the walk unit: the release reads the store,
      # so it still builds on a day the walks failed or are still queued.
      RandomizedDelaySec = "15m";
    };
  };
}
