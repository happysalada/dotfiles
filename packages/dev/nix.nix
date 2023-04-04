{ pkgs }:
with pkgs; [
  nix-index
  editorconfig-checker
  rnix-lsp
  nix-tree
  graphviz # needed to visualize nix-du
  nix-prefetch
  nvd
  nil
  nix-update
  nixpkgs-review
]
