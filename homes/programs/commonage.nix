# Keeps an immutable copy of what the SEC published, in the store the archiver
# finds on its own: `crates/store/data` inside the project's own checkout, ignored
# by git, and where the corpus, the decoder and a release look too. Nothing here
# sets `COMMONAGE_ROOT`, so a scheduled run and a hand-run one grow the same store
# instead of two.
#
# The only thing on this machine with a clock on it: a version of the SEC's own
# derived data that is not taken today cannot be bought back later, because the
# SEC regenerates those files in place.
#
# Three units, because three things change at three different rates. `recent`
# reads the daily index and picks up filings that just landed, so it is cheap
# enough to run often. `sweep` reads the SEC's own company-facts directory and
# refreshes the filers that changed, slowly and resumably. `indexes` keeps the
# quarterly index files, which say who filed what in each quarter and are what the
# EDGAR metadata graph is rebuilt from.
#
# systemd owns the schedule, but none of the three encodes EDGAR's hours: EDGAR's
# day is US Eastern and this machine's is not, so the archiver checks the window
# itself and exits 0 outside it. A timer firing at the wrong hour therefore costs
# one process start and nothing else.
#
# The binary is the project's own `cargo build --release` rather than a nix
# package. Deliberately temporary, and the reason is the clock: packaging it can
# follow, but the days in between are vintages nobody can recover.
{ config, ... }:
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
  # gate, so two overlapping units add rather than share. Four plus two plus two
  # leaves headroom; the numbers below are chosen to keep the sum under ten.
  systemd.user.services.commonage-recent = {
    Unit.Description = "archive SEC filings from the last few days";

    Service = {
      Type = "oneshot";
      ExecStart = "${binary} recent --days 2 --limit 300";
      Environment = environment ++ [ "COMMONAGE_RPS=4" ];
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

    Service = {
      Type = "oneshot";
      ExecStart = "${binary} sweep --limit 800";
      Environment = environment ++ [ "COMMONAGE_RPS=2" ];
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

    Service = {
      Type = "oneshot";
      # Nine index files at ~50 MB each, so this is the one unit that is
      # bandwidth-bound rather than request-bound.
      ExecStart = "${binary} indexes --months 24";
      Environment = environment ++ [ "COMMONAGE_RPS=2" ];
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
}
