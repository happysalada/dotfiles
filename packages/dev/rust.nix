{ pkgs }:
with pkgs; [
  # most packages needed will be done on a per-repo basis in a dev shell
  #
  # Every machine imports this file, including the servers, so it stays empty:
  # the toolchain proper lives in ./rust-toolchain.nix and is imported by the
  # workstation alone. It needs the rust-overlay overlay, which the servers do
  # not apply and have no use for.
]
