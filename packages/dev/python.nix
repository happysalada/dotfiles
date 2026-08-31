# Python, and the Astral tools that replaced most of what used to be here.
#
# Per-project dependencies belong in the project's own `uv` lockfile, not on
# PATH. What stays global is the toolchain an agent reaches for in any
# checkout, before that project's environment exists.
{ pkgs }:
with pkgs;
[
  python3 # 3.14 in this nixpkgs; `python3` tracks the default, so it moves on
  # its own at flake-update time rather than needing a bump here.

  uv # environments, lockfiles, and the python versions themselves. `uv python
  # install` works on this box because programs.nix-ld.enable is on - uv's
  # interpreters are portable standalone builds and would otherwise fail to
  # find their loader.

  ruff # lint and format in one pass. Also a language server (`ruff server`),
  # wired up in homes/programs/helix.nix.

  ty # type checker and language server, from the same people as ruff and uv.
  # Pre-1.0 and it says so, but it is fast enough to run on every keystroke,
  # which pyright was not. It replaces pyright here.

  marimo # notebooks stored as plain .py, so they diff and import like modules.
  # Cells re-run on their dependencies rather than in scroll order, which is
  # the failure mode that makes a .ipynb unreproducible.

  py-spy # sampling profiler that attaches to an already-running process by
  # pid. No instrumentation, no restart - the tool for "why is this hanging".

  python3Packages.ipython # the REPL, for the times `python -c` is too small
  # and a scratch file is too much.

  prefect # workflow orchestration
]
