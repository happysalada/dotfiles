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
def --wrapped main [...args] {
  let first = ($args | first | default "")
  let real = $env.FILE_PWD | path join reasonix-bin

  # `--set-default`, which is what the wrapper this replaced did.
  if ($env.REASONIX_TELEMETRY? | is-empty) { $env.REASONIX_TELEMETRY = "0" }
  if ($env.REASONIX_NO_INLINE? | default "") != "" { exec $real ...$args }

  # `tui` spelled out is the same session, so the flag belongs after it and the
  # caller's own flags stay where they are. Repeating `--inline` is accepted.
  if $first == "tui" { exec $real tui --inline ...($args | skip 1) }

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

  exec $real tui --inline ...$args
}
