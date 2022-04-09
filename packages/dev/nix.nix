{ pkgs }:
with pkgs; [
  nix-index
  editorconfig-checker
  nixpkgs-fmt
  rnix-lsp
  nix-tree
  nix-du
  graphviz # needed to visualize nix-du
]
