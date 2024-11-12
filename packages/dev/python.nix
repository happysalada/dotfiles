{ pkgs }:
with pkgs;
[
  pipx
  uv
  ruff
  python3
  aider-chat.withPlaywright
]
