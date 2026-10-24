{ pkgs }:
with pkgs;
[
  # linux-only tools, kept out of the shared basic_cli_set
  # clipboard-jh (`cb`) is gone: its daemon polled the wayland clipboard every
  # 2s, and each poll mapped a 1x1 surface that took keyboard focus, dismissing
  # every open popup in every app. cliphist in homes/niri/default.nix already
  # owns clipboard history, bound to Mod+V.
  libnotify # `notify-send`; -A makes the notification clickable (see ~/.claude/hooks)
  intentrace # clearer strace
  trippy # network diagnostic tool
  rustnet # per-connection/per-process network monitor TUI
  bandwhich # bytes/s per process and per remote host, plus live DNS; needs root to capture
  # GUI (ships a .desktop, ~124MiB closure) - deliberately here rather than
  # in basic_cli_set.nix, which bee and hetz also import
  sniffnet # packet analysis
  mosh # better ssh
  wireguard-tools

  # disk / io monitoring; both want root to attribute io to other users' processes
  # iotop's C rewrite, a strict superset of the python 0.6 option set (adds
  # --fullcmdline, column hide/show, --filter, a GRAPH column). The package ships
  # only `iotop-c`, so alias the familiar name the way jaq does for jq.
  (symlinkJoin {
    name = "iotop-c-with-iotop-alias-${iotop-c.version}";
    paths = [ iotop-c ];
    postBuild = ''
      ln -s iotop-c "$out/bin/iotop"
    '';
  })
  atop # sampled system + per-process stats; the replayable history needs its own
  # write unit, and nixpkgs ships no `services.atop` to add one for us

  # wayland bits
  wl-clipboard # wl-copy / wl-paste

  # yazi previewers lean on these
  p7zip # 7zz, used by yazi's built-in archive previewer + extractor
  ffmpeg # video thumbnails
  imagemagick # image formats yazi can't decode natively
  poppler-utils # pdf previews
]
