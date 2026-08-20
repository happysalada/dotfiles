{ pkgs }:
with pkgs;
[
  # linux-only tools, kept out of the shared basic_cli_set
  clipboard-jh # `cb`, clipboard manager
  intentrace # clearer strace
  trippy # network diagnostic tool
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
