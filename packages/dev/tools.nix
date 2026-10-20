# Language-agnostic dev tools: what an agent reaches for in any checkout before
# that project's own environment exists. Workstation only.
{ pkgs }:
with pkgs;
[
  # nixpkgs spells it gnumake - there is no `pkgs.make`. The binary it installs
  # is `make`, which C builds (jemalloc in tikv, most tarball projects) invoke.
  gnumake
  # `./configure` and crate build scripts (openssl-sys and friends) ask for C
  # library flags through this by name; without it they stop at "pkg-config
  # not found" rather than at a missing library. fundies' build needs it.
  pkg-config
  # native-tls goes through openssl-sys, whose build script asks pkg-config for
  # openssl - and the .pc file is in the dev output, which the `openssl` CLI in
  # basic_cli_set.nix does not install (only bin and man). `out` comes along
  # because the .pc's libdir points at it.
  openssl.dev
  openssl.out
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
