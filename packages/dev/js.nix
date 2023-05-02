{ pkgs }:
with pkgs; [
  # js
  # nodejs-slim # use again when holochain project is over
  nodejs
  nodePackages_latest.prettier
  nodePackages_latest.pnpm
  nodePackages_latest.npm-check-updates
  nodePackages_latest.svelte-language-server
  nodePackages_latest.degit
  nodePackages_latest.typescript-language-server
]
