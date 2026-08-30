{ pkgs }:
with pkgs;
[
  nix-index
  editorconfig-checker
  nix-prefetch
  nvd
  nix-update
  nixpkgs-review
  nix-output-monitor
  nix-fast-build # parallel eval + build of every output of a flake at once,
  # wrapping nix-eval-jobs and nom. nixpkgs 1.6.0, upstream 2.0.0.
  nix-init
  nix-melt
  nixfmt
  # colmena
  compose2nix
]
