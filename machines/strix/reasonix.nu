#!/usr/bin/env nu

# What `reasonix` resolves to, installed by the symlinkJoin in default.nix: the
# interactive session wants the renderer that appends to the terminal's own
# scrollback, and every subcommand has to reach the binary untouched.
#
# That renderer is opt-in since 2.28.0 - `reasonix tui --inline` - and the Termux
# sniff that used to choose it is gone from the binary, which is why the
# TERMUX_VERSION the wrapper set for the same purpose went inert on that bump.
# Unasked, a zellij pane running reasonix keeps alt-screen content only, so
# Ctrl+S and the wheel stop at the top of the current frame.
#
# A router rather than `wrapProgram --add-flags`, which prepends itself to every
# invocation and would deliver `reasonix run "x"` as `reasonix tui --inline run`.
# `REASONIX_NO_INLINE=1 reasonix` opts one run back to the full screen, the way
# `TERMUX_VERSION= reasonix` did before.
#
# The third thing is YOLO, this machine's standing posture for an interactive
# session. No config key can set it: the 2.x line retired the approval-mode
# fields, and `[desktop] default_tool_approval_mode` reaches desktop windows
# only - a terminal frontend states its own posture. So it is the flag, on the
# sessions this router starts itself: `run`, `-p` and every subcommand keep
# failing closed on an unmatched command, and a mode the caller names wins,
# because reasonix refuses `--yolo` beside `--permission-mode` rather than
# letting the later flag win. `REASONIX_NO_INLINE=1` reaches the binary
# untouched, so it is the way past the posture as well as past the renderer.
def --wrapped main [...args] {
  let first = ($args | first | default "")
  let real = $env.FILE_PWD | path join reasonix-bin

  # `--set-default`, which is what the wrapper this replaced did.
  if ($env.REASONIX_TELEMETRY? | is-empty) { $env.REASONIX_TELEMETRY = "0" }
  if ($env.REASONIX_NO_INLINE? | default "") != "" { exec $real ...$args }

  # YOLO unless the caller named a mode themselves - see the header, and note
  # that `--yolo` beside `--permission-mode` is an error rather than a conflict
  # the later flag resolves.
  let namedMode = (
    $args
    | any {|arg|
      [ "--yolo" "--dangerously-skip-permissions" "--permission-mode" ]
      | any {|flag| ($arg == $flag) or ($arg | str starts-with $"($flag)=") }
    }
  )
  let posture = (if $namedMode { [] } else { [ "--yolo" ] })

  # `tui` spelled out is the same session, so the flag belongs after it and the
  # caller's own flags stay where they are. Repeating `--inline` is accepted.
  if $first == "tui" { exec $real tui --inline ...$posture ...($args | skip 1) }

  # From `reasonix --help`. Anything that names its own mode, so an interactive
  # run is what is left over. A first argument that is here but belongs to a
  # subcommand named later - `--base main review` - is read as interactive and
  # rejected by `tui`, loudly rather than silently.
  let subcommands = [
    "run" "review" "web" "serve" "acp" "setup" "config" "report" "mcp" "login"
    "whoami" "logout" "subagent" "init" "doctor" "session" "hook" "trust" "task"
    "upgrade" "completion" "version" "help"
  ]
  # Not a terminal UI at all.
  let non_tui = [
    "-p" "--print" "--acp" "-v" "--version" "-h" "--help" "--output-format"
  ]
  if ($first in $subcommands) or ($first in $non_tui) { exec $real ...$args }

  exec $real tui --inline ...$posture ...$args
}
