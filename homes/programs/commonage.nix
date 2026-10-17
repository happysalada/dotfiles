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
# The binary is the project's own `cargo build --release` rather than a nix
# package. Deliberately temporary, and the reason is the clock: packaging it can
# follow, but the days in between are vintages nobody can recover.
{ config, pkgs, ... }:
let
  binary = "${config.home.homeDirectory}/dev/commonage/target/release/commonage-archiver";

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
      ExecStart = "${binary} recent --days 2 --limit 300";
      Environment = environment ++ [ "COMMONAGE_RPS=2" ];
      # Three hundred filings is up to six hundred requests, and a 10-K
      # submission is tens of MB, so this is bounded by bytes rather than by
      # request count.
      TimeoutStartSec = "30min";
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
      ExecStart = "${binary} sweep --limit 800";
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
      # Nine index files at ~50 MB each, so this is the one unit that is
      # bandwidth-bound rather than request-bound.
      ExecStart = "${binary} indexes --months 24";
      Environment = environment ++ [ "COMMONAGE_RPS=1" ];
      TimeoutStartSec = "40min";
    };
  };

  systemd.user.timers.commonage-indexes = {
    Unit.Description = "quarterly trigger for the index files";

    Timer = {
      # UTC on purpose: 14:00 UTC is mid-morning US Eastern in both summer and
      # winter, so it lands inside EDGAR's window whatever this machine's clock
      # is doing.
      OnCalendar = "*-01,04,07,10-01 14:00 UTC";
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
      WorkingDirectory = "${config.home.homeDirectory}/dev/commonage";
      Environment = environment;
      ExecStart = [
        "${pkgs.fnox}/bin/fnox exec -- ${binary} hydrate-submissions"
        "${pkgs.fnox}/bin/fnox exec -- ${binary} enrich-openfigi"
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
    Unit.Description = "archive the Taiwan exchanges' published tables";
    Unit.X-SwitchMethod = "keep-old";

    Service = {
      Type = "oneshot";
      # No arguments: the bare pass covers all 56 tables of the six datasets, and
      # no `--root`, so it grows the store the other units write.
      ExecStart = "${binary} mops snapshot";
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
}
