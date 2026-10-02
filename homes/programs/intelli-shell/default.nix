# Command bookmarks plus tldr examples, on ctrl-space. Replaces navi, which
# has had no release since 2023 and whose cheat corpus was 33 files.
{ config, lib, ... }:
{
  programs.intelli-shell = {
    enable = true;

    # The nushell script is generated at build time and sourced from nushell.nix;
    # home-manager's integration shells out to `intelli-shell init nushell | save -f`
    # into the data dir on every shell start, a mkdir and write we do not need.
    enableNushellIntegration = false;

    # Deliberately not programs.intelli-shell.shellHotkeys: it writes
    # home.sessionVariables, which the nushell module never loads. The one hotkey
    # that matters (ESC) is set in nushell.nix, next to the source that reads it.

    # nix owns the version, so an update nag could only ever be noise.
    settings.check_updates = false;
  };

  # The commands that used to live in navi's cheats/dotfiles.cheat. Import is
  # an upsert keyed on the command, so re-running it on every activation adds
  # nothing and never disturbs anything bookmarked with ctrl-b.
  home.activation.intelliShellSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${config.programs.intelli-shell.package}/bin/intelli-shell import \
      --file ${./commands.txt} \
      || echo "intelli-shell: seeding ${./commands.txt} failed, continuing"
  '';

  # Without this the store holds only the commands above, and searching for
  # anything you never bookmarked comes back empty. On a timer, not in the
  # activation: it is a git fetch of ~30k examples, too slow to redo on every
  # rebuild. Persistent means a fresh machine fires shortly after boot.
  systemd.user = {
    services.intelli-shell-tldr = {
      Unit.Description = "Refresh intelli-shell's tldr command examples";
      Service = {
        Type = "oneshot";
        ExecStart = "${config.programs.intelli-shell.package}/bin/intelli-shell tldr fetch";
        # The likely failure is firing before the network is up.
        Restart = "on-failure";
        RestartSec = 120;
      };
    };

    timers.intelli-shell-tldr = {
      Unit.Description = "Refresh intelli-shell's tldr command examples";
      Timer = {
        OnCalendar = "weekly";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
