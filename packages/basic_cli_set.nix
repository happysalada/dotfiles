{ pkgs }:
with pkgs; [
  exa # better ls
  ripgrep # better grep
  tealdeer # terser man
  fd # improved find
  # procs # process monitor
  # tailscale # vpn management # not supported on macos
  smartmontools # ssd health monitoring
  bottom # a better top
  dua # a better du
  borgbackup # backup
  oil # better shell language for scripts
  gitAndTools.delta # better git diff
  sd # better sed
  choose # better cut & awk
  hyperfine # benchmarking tool
  xh # http client
  mosh # better ssh
  file # get informations about files
  moreutils # sponge
  zstd # fast compression
  jq # working with json
  # czkawka # finding and cleaning files # broken on darwin
  btop # top with cpufreq
  # sequoia # openpgp in rust # compilation fails
  ruplacer # sed with visual feedback
  ouch # painless (de)compression
  solo2-cli # updating solokeys
  sqlite
  ffmpeg
]
