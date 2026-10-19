# Keeps an immutable copy of what the SEC published, and of the tables the Taiwan
# exchanges publish, in the store the archiver finds on its own: `crates/store/data`
# inside the project's own checkout, ignored by git, and where the corpus, the
# decoder and a release look too. Nothing here sets `COMMONAGE_ROOT`, so a
# scheduled run and a hand-run one grow the same store instead of two.
#
# The only thing on this machine with a clock on it: a version of the SEC's own
# derived data that is not taken today cannot be bought back later, because the
# SEC regenerates those files in place.
#
# Three EDGAR units, because three things change at three different rates. `recent`
# reads the daily index and picks up filings that just landed, so it is cheap
# enough to run often. `sweep` reads the SEC's own company-facts directory and
# refreshes the filers that changed, slowly and resumably. `indexes` keeps the
# quarterly index files, which say who filed what in each quarter and are what the
# EDGAR metadata graph is rebuilt from.
#
# `mops` is the fourth and is not EDGAR at all: the Taiwan exchanges publish one
# version of each table per day, so one pass per day captures it and a second is a
# no-op the archiver answers from the store.
#
# `openfigi` is the fifth and is not published data either: it asks OpenFIGI to map
# the securities of companies the archive knows to FIGIs, one query per symbol. It
# can only ask about a company whose submissions document it holds, so it hydrates
# them first and maps what it just fetched.
#
# systemd owns the schedule, but none of the EDGAR units encodes EDGAR's hours:
# EDGAR's day is US Eastern and this machine's is not, so the archiver checks the
# window itself and exits 0 outside it. A timer firing at the wrong hour therefore
# costs one process start and nothing else.
#
# Every unit runs the archiver through `cargo run --release --locked` rather than
# exec'ing `target/release/commonage-archiver`. Nothing rebuilt that binary, so
# units fired week-old code and reported success while archiving nothing (13 Oct),
# and a fixed schedule plus an unbuilt binary is exactly how that stays quiet.
# The cost is that a compile counts against the unit's own timeout on the first
# fire after a source change, and that a run executes whatever the tree holds -
# including a tree mid-edit. Still: the project's own `cargo build --release`
# rather than a nix package, deliberately temporary and for the clock's sake -
# packaging it can follow, but the days in between are vintages nobody recovers.
{ config, pkgs, ... }:
let
  # The checkout, which is where `cargo run` has to start: cargo finds the
  # workspace from the working directory, not from the argument list.
  checkout = "${config.home.homeDirectory}/dev/commonage";

  archiver = "cargo run --release --locked -p commonage-archiver --";

  # The SEC's fair-access policy refuses a User-Agent with no way to reach the
  # operator, so the address stays. Quoted because systemd splits an unquoted value
  # at its spaces and would drop it, leaving a user agent the archiver rejects.
  environment = [
    "COMMONAGE_USER_AGENT=\"commonage-archiver/0.1 (commonage@megzari.com)\""
  ];
in
{
  # The SEC's ceiling is ten requests a second and each process keeps its own token
  # gate, so two overlapping units add rather than share. Two plus one plus one
  # leaves six for a corpus walk, which the queue pins there for this reason: what
  # is bounded is the sum, across units and walks together, not any one number.
  systemd.user.services.commonage-recent = {
    Unit.Description = "archive SEC filings from the last few days";

    # Every unit here is a oneshot that runs for minutes, and home-manager's
    # activation waits on the start job it creates: a changed definition would
    # block the switch until the crawl ends and die on its 5-minute timeout
    # first. keep-old leaves a run alone; the new definition reaches it at the
    # next timer fire.
    Unit.X-SwitchMethod = "keep-old";

    # `sweep` holds the store's writer lock for minutes at a stretch and
    # `recent` fires every fifteen, so a start that lands inside one exits 1 on
    # the lock instead of archiving. `Wants` is what puts sweep in this unit's
    # transaction, and `After` orders units only inside one, so the pair
    # together is what makes recent wait its turn instead of failing.
    Unit.After = [ "commonage-sweep.service" ];
    Unit.Wants = [ "commonage-sweep.service" ];

    Service = {
      Type = "oneshot";
      WorkingDirectory = checkout;
      # Fourteen days so a pass that ran on stale code for a week still reaches
      # over the gap: settled days come from the ledger, not the network.
      ExecStart = "${archiver} recent --days 14 --limit 1000";
      Environment = environment ++ [ "COMMONAGE_RPS=2" ];
      # A thousand filings is up to two thousand requests, and a 10-K
      # submission is tens of MB, so this is bounded by bytes rather than by
      # request count.
      TimeoutStartSec = "45min";
    };
  };

  systemd.user.timers.commonage-recent = {
    Unit.Description = "quarter-hourly trigger for the recent-filings pass";

    Timer = {
      # Every quarter hour, every day. The archiver decides whether anything can
      # have changed, so the closed hours cost a process start each.
      OnCalendar = "*:0/15";
      RandomizedDelaySec = "2min";
      Persistent = true;
    };

    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.commonage-sweep = {
    Unit.Description = "refresh the derived datasets of the filers that changed";
    Unit.X-SwitchMethod = "keep-old";

    Service = {
      Type = "oneshot";
      WorkingDirectory = checkout;
      ExecStart = "${archiver} sweep --limit 800";
      Environment = environment ++ [ "COMMONAGE_RPS=1" ];
      TimeoutStartSec = "40min";
    };
  };

  systemd.user.timers.commonage-sweep = {
    Unit.Description = "half-hourly trigger for the stale-filer sweep";

    Timer = {
      # Slow on purpose: this is the safety net under `recent` for filers the feed
      # never shows, not the freshness mechanism. A pass only advances the directory
      # it compared against once every changed filer has been refreshed, so one cut
      # short by `--limit` or by the timeout is continued by the next.
      OnCalendar = "*:0/30";
      RandomizedDelaySec = "5min";
      Persistent = true;
    };

    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.commonage-indexes = {
    Unit.Description = "keep the SEC's quarterly index files";
    Unit.X-SwitchMethod = "keep-old";

    Service = {
      Type = "oneshot";
      WorkingDirectory = checkout;
      # Nine index files at ~50 MB each, so this is the one unit that is
      # bandwidth-bound rather than request-bound.
      ExecStart = "${archiver} indexes --months 24";
      Environment = environment ++ [ "COMMONAGE_RPS=1" ];
      TimeoutStartSec = "40min";
    };
  };

  systemd.user.timers.commonage-indexes = {
    Unit.Description = "monthly trigger for the index files";

    Timer = {
      # Monthly on the 5th, not quarterly on the first day of the quarter. The SEC
      # publishes a quarter's full-index files some days *after* the quarter ends,
      # so a run on the 1st systematically missed the quarter it fired for - which
      # is why 2026/QTR2 was the newest index held. `indexes --months 24` is
      # idempotent and serves a repeat from the store, so the runs in between cost a
      # process start and a handful of requests.
      #
      # UTC on purpose, and 14:00 of it: mid-morning US Eastern in both summer and
      # winter, so it lands inside EDGAR's window whatever this machine's clock is
      # doing.
      OnCalendar = "*-*-05 14:00 UTC";
      Persistent = true;
    };

    Install.WantedBy = [ "timers.target" ];
  };

  # Metadata, then mappings. The mapping pass can only ask about companies whose
  # submissions document is held - mapping without hydrating is a no-op - so the two
  # run as one pipeline and stop at the first failure.
  systemd.user.services.commonage-openfigi = {
    Unit.Description = "refresh SEC submissions metadata, then the OpenFIGI mappings";
    Unit.X-SwitchMethod = "keep-old";

    # Pulls a sweep into this transaction and runs it first, the same pairing `recent`
    # uses. It starts the service rather than waiting to be triggered by its timer, so
    # it still works while that timer is not firing.
    Unit.After = [ "commonage-sweep.service" ];
    Unit.Wants = [ "commonage-sweep.service" ];

    Service = {
      Type = "oneshot";
      # `fnox` reads fnox.toml from here, and the age identity from the user's home.
      WorkingDirectory = checkout;
      Environment = environment;
      ExecStart = [
        "${pkgs.fnox}/bin/fnox exec -- ${archiver} hydrate-submissions"
        "${pkgs.fnox}/bin/fnox exec -- ${archiver} enrich-openfigi"
      ];
      TimeoutStartSec = "90min";
    };
  };

  systemd.user.timers.commonage-openfigi = {
    Unit.Description = "weekly trigger for metadata and mappings";

    Timer = {
      # Weekly: new listings appear at human speed, and both steps are incremental -
      # the mapping pass asks only for queries its journal does not hold.
      OnCalendar = "Sun 04:00";
      RandomizedDelaySec = "20min";
      Persistent = true;
    };

    Install.WantedBy = [ "timers.target" ];
  };

  # MOPS and TPEx publish open data: no key, so no fnox exec, and no
  # `COMMONAGE_RPS` either, which paces EDGAR. The client paces itself three
  # seconds apart against its own budget file under the store, which makes a cold
  # full pass minutes rather than hours.
  systemd.user.services.commonage-mops = {
    Unit.Description = "archive the Taiwan exchanges' published tables, then build the day's release";
    Unit.X-SwitchMethod = "keep-old";

    Service = {
      Type = "oneshot";
      # No `--root`, so it grows the store the other units write. Two commands only
      # because this is a oneshot: systemd runs them in order and stops at the first
      # failure, so the release is built from a snapshot that succeeded or not at all.
      ExecStart = [
        # No arguments: the bare pass covers all the tables of the six datasets.
        "${archiver} mops snapshot"
        # Reads the ledger and the store, asks nobody anything, so it needs no key and
        # no network. `--out` is absolute because the default is relative and a user
        # unit starts in `$HOME`, which would make it `~/data/releases/mops`.
        "${archiver} mops release --out ${checkout}/data/releases/mops"
      ];
      WorkingDirectory = checkout;
      Environment = environment;
      TimeoutStartSec = "30min";
    };
  };

  systemd.user.timers.commonage-mops = {
    Unit.Description = "daily trigger for the Taiwan snapshot";

    Timer = {
      # 22:00 UTC is 06:00 Taipei, sixteen hours after the 13:30 close, so the
      # day's final tables have settled. The archiver's freshness window for them
      # is exactly 24 h, so one pass a day stores each new version once and a
      # second the same day is served from the archive. UTC because Taipei has no
      # DST to follow.
      OnCalendar = "*-*-* 22:00:00 UTC";
      RandomizedDelaySec = "10min";
      Persistent = true;
    };

    Install.WantedBy = [ "timers.target" ];
  };

  # Open PermID is a daily budget, not a published snapshot. The first runs fill
  # the filers the archive knows; after that the 30-day cache expires in the
  # order it was filled, so the same pass refreshes old candidate links and
  # picks up filers the ledger gained. `--refresh` is deliberately not used:
  # with a cap it would restart at the same hash prefix every day and starve
  # the rest.
  systemd.user.services.commonage-openpermid = {
    Unit.Description = "consume the daily Open PermID budget and refresh candidate links";
    Unit.X-SwitchMethod = "keep-old";

    Service = {
      Type = "oneshot";
      WorkingDirectory = checkout;
      Environment = environment;
      ExecStart = "${pkgs.fnox}/bin/fnox exec -- ${archiver} enrich-openpermid --limit 4500 --cache-days 30";
      # 4,500 records plus at most one verification search each is ~75 minutes
      # at one request/second; the rest of the daily budget goes to a cached
      # verification backlog, and the run resumes what the quota cuts off.
      TimeoutStartSec = "150min";
    };
  };

  systemd.user.timers.commonage-openpermid = {
    Unit.Description = "daily trigger for the Open PermID candidate pass";

    Timer = {
      # The live quota resets at 00:00 UTC; 15 minutes later is unambiguous.
      OnCalendar = "*-*-* 00:15:00 UTC";
      RandomizedDelaySec = "10min";
      Persistent = true;
    };

    Install.WantedBy = [ "timers.target" ];
  };

  # The search catalog is derived data - it can be rebuilt from the store - so it
  # is rebuilt on a clock rather than kept current incrementally. The export reads
  # the ledger and the blobs and asks nobody anything: no key, no network, which
  # is why the user agent below is only there to match its siblings.
  systemd.user.services.commonage-search = {
    Unit.Description = "rebuild the search catalog from the archive";
    Unit.X-SwitchMethod = "keep-old";

    Service = {
      Type = "oneshot";
      # `--out` defaults to `data/search/catalog.jsonl`, relative, and a user unit
      # starts in `$HOME` - which would put it at `~/data/search/catalog.jsonl`.
      WorkingDirectory = checkout;
      ExecStart = "${archiver} export-search";
      Environment = environment;
      TimeoutStartSec = "30min";
    };
  };

  systemd.user.timers.commonage-search = {
    Unit.Description = "daily trigger for the search catalog";

    Timer = {
      # An hour after the MOPS pass, which starts at 22:00 UTC and takes about
      # four minutes with its release. The gap is the ordering: export-search
      # reads the ledger and the blobs, and the snapshot is writing them. A
      # `Wants`/`After` pairing would order them too, but it would also start a
      # second MOPS pass in this unit's transaction - served from the archive,
      # yet not free.
      OnCalendar = "*-*-* 23:00:00 UTC";
      RandomizedDelaySec = "10min";
      Persistent = true;
    };

    Install.WantedBy = [ "timers.target" ];
  };
}
