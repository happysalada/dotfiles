# terminal-browser's render settings, declared rather than left to
# `terminal-browser config set`.
#
# Nothing upstream writes this file - home-manager has no module for it and
# llm-agents ships packages only - so it is rendered here. Keys are flat and
# dotted, the same shape `config set` produces; anything left out falls back to
# its default.
#
# The path is then a store symlink, so `config set` fails rather than writing,
# and a change belongs in this file.
#
# All three steer it off the slow path. Behind zellij - which implements the
# kitty graphics protocol itself, so the engine never gets a confirmation about
# file or shared-memory frames - it falls back to base64 whole frames inline.
{ ... }:
{
  xdg.configFile."terminal-browser/settings.json".text = builtins.toJSON {
    "render.presenter" = "patched"; # changed regions, not whole frames
    "render.transport" = "file"; # frames through a file the terminal re-reads
    "render.fps" = "30"; # not "display", which is one frame per panel refresh
  };
}
