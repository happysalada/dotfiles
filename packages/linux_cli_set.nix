{ pkgs }:
with pkgs;
[
  # linux-only tools, kept out of the shared basic_cli_set
  # clipboard-jh (`cb`) removed 2026-08-30. Its daemon polled the wayland
  # clipboard every 2s, and each poll meant mapping a 1x1 surface that took
  # keyboard focus - which dismissed every open popup, in every app, about
  # as fast as one could be clicked. cliphist in homes/niri/default.nix
  # already owns clipboard history, bound to Mod+V.
  libnotify # `notify-send`; -A makes the notification clickable (see ~/.claude/hooks)
  intentrace # clearer strace
  trippy # network diagnostic tool
  rustnet # per-connection/per-process network monitor TUI
  # GUI (ships a .desktop, ~124MiB closure) - deliberately here rather than
  # in basic_cli_set.nix, which bee and hetz also import
  sniffnet # packet analysis
  mosh # better ssh
  wireguard-tools

  # wayland bits
  wl-clipboard # wl-copy / wl-paste

  # yazi previewers lean on these
  p7zip # 7zz, used by yazi's built-in archive previewer + extractor
  ffmpeg # video thumbnails
  imagemagick # image formats yazi can't decode natively
  poppler-utils # pdf previews
]
