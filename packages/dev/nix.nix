{ pkgs }:
with pkgs; [
  nix-index
  editorconfig-checker
  rnix-lsp
  nix-tree
  nix-prefetch
  nvd
  nil
  nix-update
  nixpkgs-review
  poetry # packaging python projects for nix
]
