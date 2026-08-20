{ pkgs }:
with pkgs;
[
  # nixpkgs tracks upstream closely but can lag by a few days. `claude update`
  # is a no-op here (the store is read-only) - bump nixpkgs instead, or run it
  # off mise/npm if you need same-day releases.
  claude-code
]
