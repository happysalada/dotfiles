{ pkgs }:
with pkgs; [
  # js
  nodePackages.prettier
  nodePackages.pnpm
  nodePackages.node2nix
  nodePackages.npm-check-updates
  nodePackages.svelte-language-server
  nodejs-16_x
  nodePackages.yarn
  yarn2nix
]
