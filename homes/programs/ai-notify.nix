# The clickable "<agent> is done" notification, shared by claude-code, codex and
# reasonix. All three fire it from a turn-end hook - Claude's and Codex's `Stop`,
# reasonix's `Stop` event - so one script serves them and only the label differs.
#
# A script rather than each tool's own notification setting, because those only
# pop a toast: this one focuses the session again when the toast is clicked.
{ lib, pkgs }:
rec {
  # The hook command. It resolves the window to focus, then hands both halves to
  # the waiter below, which owns the notification itself and blocks on it.
  #
  # The window is found by title rather than at session start, because
  # `niri msg focused-window` only names the terminal if you happened to be
  # looking at it, and zellij's session-name prefix ("main | <tab>") is
  # focus-independent, where ghostty is single-instance and PIDs cannot tell
  # windows apart. Started outside zellij - a `codex exec`, a `claude -p` - there
  # is no pane, and the click just focuses the window.
  mkStopNotify =
    { app, summary }:
    let
      # Blocks on the notification; a click focuses, a dismissal does nothing.
      waiter = pkgs.writers.writeNu "${app}-focus-waiter" ''
        def main [wid: string, pane: string, zsession: string, body: string] {
          let answer = ${notifySend} -a ${app} -A default=Focus "${summary}" $body | complete | get stdout | str trim
          if $answer != "default" { return }

          if $wid != "" { ${niri} msg action focus-window --id $wid | complete | ignore }
          # zellij resolves the target session from the env, so this works from
          # outside the pane
          if $pane != "" {
            with-env { ZELLIJ_SESSION_NAME: $zsession } { ${zellij} action focus-pane-id $pane | complete | ignore }
          }
        }
      '';
    in
    pkgs.writers.writeNu "${app}-stop-notify" ''
      def main [] {
        let zsession = $env.ZELLIJ_SESSION_NAME? | default ""
        let pane = $env.ZELLIJ_PANE_ID? | default ""

        let by_title = if $zsession == "" { null } else {
          try { ${niri} msg --json windows | from json } catch { [] }
          | where {|w| ($w.title? | default "") | str starts-with $"($zsession) | " }
          | get -o 0.id
        }
        let wid = $by_title | default (
          try { ${niri} msg --json focused-window | from json | get -o id } catch { null }
        )

        # -f: notify-send -A blocks until answered, so the waiter must outlive us
        ${setsid} -f ${waiter} ($wid | default "" | into string) $pane $zsession ($env.PWD | path basename) o+e> /dev/null
      }
    '';

  # What the scripts call, pinned to store paths so no wrapper can shadow them.
  # The `^` prefix is nushell's external-command marker.
  niri = "^${lib.getExe pkgs.niri}";
  zellij = "^${lib.getExe pkgs.zellij}";
  notifySend = "^${pkgs.libnotify}/bin/notify-send";
  setsid = "^${pkgs.util-linux}/bin/setsid";
}
