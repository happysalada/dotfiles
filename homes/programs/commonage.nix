# Keeps an immutable copy of what the SEC published, under $HOME/commonage.
#
# The only thing on this machine with a clock on it: a version of the SEC's own
# derived data that is not taken today cannot be bought back later, because the
# SEC regenerates those files in place.
#
# Three units, because two things change at two different rates. `recent` reads
# the daily index and picks up filings that just landed, so it is cheap enough to
# run often. `sweep` walks the roster slowly so that nothing is missed. `roster`
# re-derives that list from the quarterly indexes.
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
  # Outside the checkout on purpose. This grows to hundreds of GB of filings, and
  # a dataset that size inside a git working tree is a trap for everything that
  # walks one.
  dataDir = "${config.home.homeDirectory}/commonage";

  binary = "${config.home.homeDirectory}/dev/commonage/target/release/commonage-archiver";

  # The SEC's ceiling is ten requests a second and each process keeps its own
  # token gate, so two overlapping units add rather than share. Four plus two
  # leaves headroom; the numbers below are chosen to keep the sum under ten.
  environment = [
    "COMMONAGE_ROOT=${dataDir}"
    "COMMONAGE_USER_AGENT=commonage-archiver/0.1 (commonage@megzari.com)"
  ];
in
{
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
    Unit.Description = "refresh the SEC's derived datasets across the filer list";

    Service = {
      Type = "oneshot";
      ExecStart = "${binary} sweep --limit 800";
      Environment = environment ++ [ "COMMONAGE_RPS=2" ];
      TimeoutStartSec = "40min";
    };
  };

  systemd.user.timers.commonage-sweep = {
    Unit.Description = "half-hourly rotation through the filer list";

    Timer = {
      # The list is ~7,700 filers and a pass takes 800, so a full rotation is
      # about five passes - two and a half hours. Slow on purpose: this is the
      # safety net for filers that `recent` never sees, not the freshness
      # mechanism, and the fast half already covers anything that just filed.
      OnCalendar = "*:0/30";
      RandomizedDelaySec = "5min";
      Persistent = true;
    };

    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.commonage-roster = {
    Unit.Description = "re-derive the SEC filer roster from the quarterly indexes";

    Service = {
      Type = "oneshot";
      # Nine index files at ~50 MB each, so this is the one unit that is
      # bandwidth-bound rather than request-bound.
      ExecStart = "${binary} roster --months 24";
      Environment = environment ++ [ "COMMONAGE_RPS=2" ];
      TimeoutStartSec = "40min";
    };
  };

  systemd.user.timers.commonage-roster = {
    Unit.Description = "quarterly trigger for the filer roster";

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
