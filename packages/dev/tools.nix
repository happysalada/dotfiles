# Language-agnostic dev tools: what an agent reaches for in any checkout before
# that project's own environment exists. Workstation only.
{ pkgs }:
with pkgs;
[
  just # the task runner most repos with a justfile expect
  watchexec # rerun a command on file change
  tokei # line counts per language - a cheap first map of an unknown repo
  difftastic # `difft`, syntax-aware diff
  shellcheck # for the bash that still has to be bash
  podman-compose # `podman compose`, for repos that ship a compose file

  # debuggers; perf is in systemPackages, it has to match the kernel
  gdb
  lldb
]
