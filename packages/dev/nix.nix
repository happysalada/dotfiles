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
  nix-init
  nix-melt
  nixfmt-rfc-style
  # colmena
  compose2nix
]
