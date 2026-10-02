# Python, and the Astral tools that most of this file is.
#
# Per-project deps belong in the project's own `uv` lockfile, not on PATH; the
# globals are what an agent reaches for before that environment exists.
#
# Plain `python3`, not `python314FreeThreading`: cache.nixos.org builds the
# free-threaded interpreter but no package set on top of it - asgiref, dill and
# proto-plus fail under it besides. `uv python install cpython-3.14t` gets a
# no-GIL interpreter into the one project that wants it.
{ pkgs }:
with pkgs;
[
  python3

  uv # environments, lockfiles, and the python versions themselves. `uv python
  # install` works because programs.nix-ld.enable is on - its interpreters are
  # portable standalone builds and would otherwise fail to find their loader.

  ruff # lint and format in one pass. Also a language server (`ruff server`),
  # wired up in homes/programs/helix.nix.

  ty # type checker and language server, from the same people as ruff and uv.
  # Pre-1.0, but fast enough for every keystroke, which pyright was not; it
  # replaces pyright here.

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
