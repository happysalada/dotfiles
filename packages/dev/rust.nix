{ pkgs }:
with pkgs;
[
  # Every machine imports this file, including the servers, so it stays empty.
  # The toolchain lives in ./rust-toolchain.nix, imported by the workstation
  # alone, which needs the rust-overlay overlay the servers do not apply.
]
