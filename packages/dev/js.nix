{ pkgs }:
with pkgs; [
  # js
  nodejs-slim
  nodePackages_latest.pnpm
  nodePackages_latest.degit
]
