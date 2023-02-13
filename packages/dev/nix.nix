{ pkgs }:
with pkgs; [
  nix-index
  editorconfig-checker
  rnix-lsp
  nix-tree
  # nix-du # compilation fails on darwin
  graphviz # needed to visualize nix-du
  nix-prefetch
]
