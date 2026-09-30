# Language-agnostic dev tools: what an agent reaches for in any checkout before
# that project's own environment exists. Workstation only.
{ pkgs }:
with pkgs;
[
  just # the task runner most repos with a justfile expect
  watchexec # rerun a command on file change
  tokei # line counts per language - a cheap first map of an unknown repo
  # complexity per function. Two of them on purpose, to be tried side by side
  # before one is dropped: `lizard` gives CCN and NLOC, `bca` gives those plus
  # cognitive complexity, Halstead and maintainability index.
  python3Packages.lizard
  (callPackage ./big-code-analysis.nix { })
  # the SlopCodeBench pair - verbosity (redundancy) and structural erosion.
  # Rust-usable; its ast-grep rule half only ever fires on Python.
  (callPackage ./scb-check.nix { })
  difftastic # `difft`, syntax-aware diff
  shellcheck # for the bash that still has to be bash
  podman-compose # `podman compose`, for repos that ship a compose file

  # debuggers; perf is in systemPackages, it has to match the kernel
  gdb
  lldb
  bugstalker # `bs`, a TUI debugger that shows Rust types, not just addresses

  # `rr record` does not need kernel.perf_event_paranoid lowered on kernels
  # >= 6.10: at paranoid 2 it falls back to PERF_RECORD_SWITCH instead of the
  # kernel-only PERF_COUNT_SW_CONTEXT_SWITCHES event, and it sets
  # exclude_kernel on its own counters (rr's ContextSwitchEvent.h says as
  # much). Do not "fix" a future failure by dropping paranoid to 1.
  rr
]
