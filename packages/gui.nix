{ pkgs }:
with pkgs;
[
  # Dictation: hold a key, speak, and the text is pasted at the cursor. From the
  # llm-agents overlay rather than nixpkgs, which the overlay block in
  # machines/strix/default.nix binds and flake.nix explains why - the flake has
  # 0.9.8 where nixpkgs has 0.9.6, at the cost of llm-agents repacking
  # upstream's .deb while nixpkgs builds it from source.
  #
  # Nothing here configures it: it keeps its settings in its own app data
  # directory, written by its UI. Two of those matter on this machine. Keyboard
  # Implementation has to move off the default `tauri` to `handy_keys`, because
  # the default registers an X11 grab, which never fires under niri while a
  # native Wayland window is focused. Overlay Position wants None, since the
  # overlay takes focus and then stops the paste.
  handy

  # What Handy shells out to for the paste keystroke, so what has to be on PATH.
  # wtype is its first choice on Wayland and is reachable here: niri implements
  # the virtual-keyboard protocol it needs. ydotool comes from programs.ydotool
  # in machines/strix/default.nix, the compositor-agnostic fallback, and
  # wl-clipboard, the clipboard half of both paths, is already in
  # linux_cli_set.nix.
  wtype
]
