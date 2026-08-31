# Python, and the Astral tools that replaced most of what used to be here.
#
# Per-project dependencies belong in the project's own `uv` lockfile, not on
# PATH. What stays global is the toolchain an agent reaches for in any
# checkout, before that project's environment exists.
#
# Plain `python3`, not `python314FreeThreading`: cache.nixos.org builds the
# free-threaded interpreter but none of the package set on top of it, and
# asgiref, dill and proto-plus fail under it besides. `uv python install
# cpython-3.14t` gets a no-GIL interpreter into the one project that wants it,
# without dragging the global toolchain along.
{ pkgs }:
with pkgs;
[
  python3

  uv # environments, lockfiles, and the python versions themselves. `uv python
  # install` works on this box because programs.nix-ld.enable is on - uv's
  # interpreters are portable standalone builds and would otherwise fail to
  # find their loader.

  ruff # lint and format in one pass. Also a language server (`ruff server`),
  # wired up in homes/programs/helix.nix.

  ty # type checker and language server, from the same people as ruff and uv.
  # Pre-1.0 and it says so, but it is fast enough to run on every keystroke,
  # which pyright was not. It replaces pyright here.

  py-spy # sampling profiler that attaches to an already-running process by
  # pid. No instrumentation, no restart - the tool for "why is this hanging".

  marimo # notebooks stored as plain .py, so they diff and import like modules.
  # Cells re-run on their dependencies rather than in scroll order, which is
  # the failure mode that makes a .ipynb unreproducible.

  python3Packages.ipython # the REPL, for the times `python -c` is too small
  # and a scratch file is too much. The only one of these with no top-level
  # alias.

  prefect # workflow orchestration
]
