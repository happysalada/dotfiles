{ pkgs }:
with pkgs; [
  # js
  nodejs-slim
  nodePackages_latest.prettier
  nodePackages_latest.pnpm
  nodePackages_latest.npm-check-updates
  nodePackages_latest.svelte-language-server
  nodePackages_latest.degit
]
