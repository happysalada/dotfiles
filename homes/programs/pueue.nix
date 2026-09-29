# pueued as a systemd user service, plus ~/.config/pueue/pueue.yml - the config
# is what makes `pueue` typed in any shell reach the same daemon.
#
# The client binary already comes from packages/basic_cli_set.nix (same
# derivation, so the overlap costs nothing). Strix-only: a queue you can walk
# away from is a desktop thing, and bee/hetz only need the client.
{ pkgs, ... }:
{
  services.pueue = {
    enable = true;

    settings = {
      # Upstream defaults to the shades that read well on a light background.
      # ghostty, helix and zellij are all #000000 here.
      client.dark_mode = true;

      # The point of a queue is that you can walk away from it, so say
      # something when it stops making progress. `result` is the pueue
      # TaskResult variant - Success, Failed, FailedToSpawn, Killed, Errored,
      # DependencyFailed - and only the real failures are worth a popup,
      # otherwise it is one notification per build.
      #
      # The template is handlebars, rendered by the daemon and handed to
      # `sh -c`; it runs in strict mode, so a variable it does not know makes
      # the daemon skip the callback and log an error instead. `command` is
      # left out on purpose: it is interpolated verbatim into a shell command,
      # so a task containing a quote would break the callback.
      daemon.callback = ''case "{{result}}" in Failed | FailedToSpawn | Errored) ${pkgs.libnotify}/bin/notify-send -a pueue "pueue: task {{id}} {{result}}" "{{queued_count}} queued in group {{group}}" ;; esac'';
    };
  };
}
