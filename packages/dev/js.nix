{ pkgs }:
with pkgs; [
  # js
  nodePackages.prettier
  nodePackages.pnpm
  nodePackages.npm-check-updates
  nodePackages.svelte-language-server
  nodejs-18_x
  nodePackages.wrangler
]
