# A weekly digest of what shipped in the repos I have starred.
#
# digest.py is the flow; this file is only the schedule and the environment it
# needs. systemd owns the schedule rather than prefect because `Persistent`
# reruns a job the machine slept through, and the laptop is usually asleep at
# nine on a Monday.
#
# No token to mint: the flow borrows gh's, which reaches the login keyring
# from a user unit while the session is unlocked. Set GITHUB_TOKEN in
# ~/.config/starred-digest/env only to override that.
#
# Run it now rather than waiting for Monday with:
#   systemctl --user start starred-digest
{ pkgs, config, ... }:
let
  # Plain `python3` cannot import prefect - the top-level `prefect` package is
  # a wrapped application - so the flow gets its own interpreter.
  #
  # The http2 extra resolves to h2 alone, so httpx2 itself has to be listed
  # beside it. Seventeen paginated requests to one host is what h2 is for.
  python = pkgs.python3.withPackages (
    ps:
    [
      ps.prefect
      ps.httpx2
    ]
    ++ ps.httpx2.optional-dependencies.http2
  );

  stateDir = "${config.xdg.stateHome}/starred-digest";
in
{
  systemd.user.services.starred-digest = {
    Unit.Description = "weekly digest of releases in starred github repos";

    Service = {
      Type = "oneshot";
      # prefect resolves PREFECT_HOME at import, before the flow creates its
      # state directory, and warns that it could not make it. Nothing else
      # creates this path on a first run.
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${stateDir}/prefect";
      ExecStart = "${python}/bin/python ${./digest.py}";

      Environment = [
        # Report to the loopback server from modules/prefect-local.nix, so runs
        # and their logs are inspectable at http://127.0.0.1:4200 instead of
        # vanishing with the process. If it is down prefect starts a temporary
        # server of its own and the digest still gets written.
        "PREFECT_API_URL=http://127.0.0.1:4200/api"
        "PREFECT_HOME=${stateDir}/prefect"
        "STARRED_DIGEST_STATE=${stateDir}"
        # gh hands over the github token, notify-send announces the result.
        "PATH=${pkgs.gh}/bin:${pkgs.libnotify}/bin"
      ];

      # Optional, and normally absent: the leading `-` is what lets the flow
      # fall through to gh's token instead of systemd refusing to start.
      EnvironmentFile = "-%h/.config/starred-digest/env";

      # Seventeen paginated requests, then a local model generation. There is
      # no retry at this level on purpose: the flow retries its own network
      # tasks, which is also what covers coming back up before the wifi does.
      TimeoutStartSec = "30min";
    };
  };

  systemd.user.timers.starred-digest = {
    Unit.Description = "weekly trigger for the starred-repo digest";

    Timer = {
      OnCalendar = "Mon 09:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };

    Install.WantedBy = [ "timers.target" ];
  };
}
