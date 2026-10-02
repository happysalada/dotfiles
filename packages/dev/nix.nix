{ pkgs }:
with pkgs;
[
  # nix-index comes from nix-index-database on strix, with its database
  editorconfig-checker
  nix-prefetch
  nvd
  nix-update
  nixpkgs-review
  nix-output-monitor
  nix-fast-build # parallel eval + build of every output of a flake at once,
  # wrapping nix-eval-jobs and nom.
  nix-init
  nix-melt
  nixfmt
  # colmena
  compose2nix
]
