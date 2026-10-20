# Keeps an immutable copy of what the SEC published, and of the tables the Taiwan
# exchanges publish, in the store the archiver finds on its own: `crates/store/data`
# inside the project's own checkout, ignored by git, and where the corpus, the
# decoder and a release look too. Nothing here sets `FUNDIES_ROOT`, so a
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
# `iex` is the sixth and is a price source rather than a filing one: IEX publishes
# yesterday's DEEP capture as gzip'd packet capture, one file per trading day, and
# the archive keeps only the bars each one yields. One unit for the day just
# published; the history back to 2017-05-15 is a pueue job, because at 9.7 TiB it
# is bandwidth and not a clock.
#
# systemd owns the schedule, but none of the EDGAR units encodes EDGAR's hours:
# EDGAR's day is US Eastern and this machine's is not, so the archiver checks the
# window itself and exits 0 outside it. A timer firing at the wrong hour therefore
# costs one process start and nothing else.
#
# Every unit runs the archiver through `cargo run --release --locked` rather than
# exec'ing `target/release/fundies-archiver`. Nothing rebuilt that binary, so
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
  checkout = "${config.home.homeDirectory}/dev/fundies";

  # A user unit has no login shell, and systemd resolves `ExecStart` against the
  # search path it was compiled with rather than the unit's own `PATH` - so a bare
  # `cargo` is 203/EXEC however the environment below is set, which is what every
  # unit here was doing. This is the profile a run from a shell finds, so the
  # toolchain stays the rust-overlay stable rather than nixpkgs'.
  bin = "${config.home.profileDirectory}/bin";

  archiver = "${bin}/cargo run --release --locked -p fundies-archiver --";

  iex = "${bin}/cargo run --release --locked -p fundies-iex --";

  # The SEC's fair-access policy refuses a User-Agent with no way to reach the
  # operator, so the address stays. Quoted because systemd splits an unquoted value
  # at its spaces and would drop it, leaving a user agent the archiver rejects.
  #
  # `PATH` is still needed beside the absolute `cargo` above: cargo looks rustc and
  # cc up by name, and the unit's default path holds neither.
  environment = [
    "FUNDIES_USER_AGENT=\"fundies-archiver/0.1 (fundies@megzari.com)\""
    "PATH=${bin}:/run/current-system/sw/bin"
  ];
in
{
  # The SEC's ceiling is ten requests a second and each process keeps its own token
  # gate, so two overlapping units add rather than share. Two plus one plus one
  # leaves six for a corpus walk, which the queue pins there for this reason: what
  # is bounded is the sum, across units and walks together, not any one number.
  systemd.user.services.fundies-recent = {
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
    Unit.After = [ "fundies-sweep.service" ];
    Unit.Wants = [ "fundies-sweep.service" ];

    Service = {
      Type = "oneshot";
      WorkingDirectory = checkout;
      # Fourteen days so a pass that ran on stale code for a week still reaches
      # over the gap: settled days come from the ledger, not the network.
      ExecStart = "${archiver} recent --days 14 --limit 1000";
      Environment = environment ++ [ "FUNDIES_RPS=2" ];
      # A thousand filings is up to two thousand requests, and a 10-K
      # submission is tens of MB, so this is bounded by bytes rather than by
      # request count.
      TimeoutStartSec = "45min";
    };
  };

  systemd.user.timers.fundies-recent = {
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

  systemd.user.services.fundies-sweep = {
    Unit.Description = "refresh the derived datasets of the filers that changed";
    Unit.X-SwitchMethod = "keep-old";

    Service = {
      Type = "oneshot";
      WorkingDirectory = checkout;
      ExecStart = "${archiver} sweep --limit 800";
      Environment = environment ++ [ "FUNDIES_RPS=1" ];
      TimeoutStartSec = "40min";
    };
  };

  systemd.user.timers.fundies-sweep = {
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

  systemd.user.services.fundies-indexes = {
    Unit.Description = "keep the SEC's quarterly index files";
    Unit.X-SwitchMethod = "keep-old";

    Service = {
      Type = "oneshot";
      WorkingDirectory = checkout;
      # Nine index files at ~50 MB each, so this is the one unit that is
      # bandwidth-bound rather than request-bound.
      ExecStart = "${archiver} indexes --months 24";
      Environment = environment ++ [ "FUNDIES_RPS=1" ];
      TimeoutStartSec = "40min";
    };
  };

  systemd.user.timers.fundies-indexes = {
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
  systemd.user.services.fundies-openfigi = {
    Unit.Description = "refresh SEC submissions metadata, then the OpenFIGI mappings";
    Unit.X-SwitchMethod = "keep-old";

    # Pulls a sweep into this transaction and runs it first, the same pairing `recent`
    # uses. It starts the service rather than waiting to be triggered by its timer, so
    # it still works while that timer is not firing.
    Unit.After = [ "fundies-sweep.service" ];
    Unit.Wants = [ "fundies-sweep.service" ];

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

  systemd.user.timers.fundies-openfigi = {
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
  # `FUNDIES_RPS` either, which paces EDGAR. The client paces itself three
  # seconds apart against its own budget file under the store, which makes a cold
  # full pass minutes rather than hours.
  systemd.user.services.fundies-mops = {
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

  systemd.user.timers.fundies-mops = {
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
  systemd.user.services.fundies-openpermid = {
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

  systemd.user.timers.fundies-openpermid = {
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
  systemd.user.services.fundies-search = {
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

  systemd.user.timers.fundies-search = {
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

  # Prices, from IEX's own historical captures. One unit, for the day published a
  # few hours ago; the history is one pueue job rather than a timer, because 2,385
  # DEEP days and 9.7 TiB are bandwidth and not a clock. It gets a group of its own
  # so it neither waits behind nor blocks the archiver's:
  #
  #   pueue group add iex-backfill
  #   pueue add --group iex-backfill --label iex-backfill -p -- \
  #     "cd /home/yt/dev/fundies && /run/current-system/sw/bin/flock --exclusive \
  #      data/prices/.iex-backfill.lock /etc/profiles/per-user/yt/bin/cargo run \
  #      --release --locked -p fundies-iex -- backfill --from 20161212 \
  #      --skip-existing --out-dir data/prices --manifest data/prices/manifest.json \
  #      --catalog data/search/catalog.jsonl --temp data/prices/tmp --rps 1"
  #
  # No `--limit`: `--skip-existing` and the manifest make the one job resumable, so
  # re-adding that command continues from the oldest date it does not hold. The temp
  # capture is the largest thing written (up to 20 GiB a day) and is deleted once
  # digested; only the bar's few hundred KB per day stays. There is no second disk
  # here, so it lives under the checkout with everything else.
  systemd.user.services.fundies-iex = {
    Unit.Description = "fetch the last three IEX DEEP days into prices";
    Unit.X-SwitchMethod = "keep-old";

    # The catalog join reads `data/search/catalog.jsonl`, which the search unit
    # rewrote the night before. Ordering only, no `Wants`: a second export in this
    # transaction would be served from the store and still paid for. The user
    # manager has no `network-online.target` on this host, so that half is inert.
    Unit.After = [
      "network-online.target"
      "fundies-search.service"
    ];
    Unit.Wants = [ "network-online.target" ];

    Service = {
      Type = "oneshot";
      WorkingDirectory = checkout;
      # The backfill holds that lock for as long as it runs, and both write the
      # manifest read-modify-write. So wait for it - half an hour at most, after
      # which this fire is skipped rather than failed, because an `ExecCondition`
      # that exits 1 is a skip. The next fire's three-day lookback covers the day.
      ExecCondition = "${pkgs.bash}/bin/bash -c 'mkdir -p ${checkout}/data/prices && exec ${pkgs.util-linux}/bin/flock --wait 1800 --exclusive ${checkout}/data/prices/.iex-backfill.lock ${pkgs.coreutils}/bin/true'";
      # Three days, not one: the machine can sleep through 07:00, and a date the
      # manifest already holds costs no request.
      ExecStart = "${iex} fetch --recent 3 --out-dir data/prices --manifest data/prices/manifest.json --catalog data/search/catalog.jsonl --temp data/prices/tmp --rps 1";
      Environment = environment;
      # The wait above is inside this; the captures behind it take minutes at the
      # ~60 MB/s measured, and the client's own per-request timeout is the hour.
      TimeoutStartSec = "1h";
    };
  };

  systemd.user.timers.fundies-iex = {
    Unit.Description = "morning trigger for the last three IEX days";

    Timer = {
      # 07:00 on the exchange's clock, not UTC: what makes a run late is a file
      # published after the US close, not a window the fetcher could test and skip.
      # `Persistent` replays a fire the machine slept through; the three-day
      # lookback then covers the gap it left.
      OnCalendar = "*-*-* 07:00:00 America/New_York";
      Persistent = true;
    };

    Install.WantedBy = [ "timers.target" ];
  };

  # The serving pair, not the archive. The API keeps the release tables and
  # Meilisearch on loopback; the SvelteKit server is the only process a tunnel
  # or proxy reaches. `fnox` supplies MEILISEARCH_API_KEY from the project's
  # fnox.toml, the same way `just server-start` does.
  systemd.user.services.fundies-server = {
    Unit.Description = "fundies read API";

    Service = {
      Type = "simple";
      WorkingDirectory = checkout;
      ExecStart = "${pkgs.fnox}/bin/fnox exec -- ${checkout}/target/release/fundies-server";
      Environment = environment ++ [
        "FUNDIES_BIND=127.0.0.1:3000"
        "MEILISEARCH_URL=http://127.0.0.1:7700"
        # The server's own default. data/search also carries a
        # fundies_full_v2 receipt; use that name if it is the index the
        # search unit last built.
        "MEILISEARCH_INDEX=fundies_full_v1"
      ];
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.fundies-frontend = {
    Unit.Description = "fundies SvelteKit frontend";
    Unit.After = [ "fundies-server.service" ];

    Service = {
      Type = "simple";
      WorkingDirectory = "${checkout}/frontend";
      ExecStart = "${pkgs.bun}/bin/bun ./build";
      Environment = [
        "HOST=127.0.0.1"
        "PORT=3001"
        "FUNDIES_API_URL=http://127.0.0.1:3000"
        "PATH=${bin}:/run/current-system/sw/bin"
      ];
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = [ "default.target" ];
  };
}
