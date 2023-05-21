{ pkgs }:
with pkgs; [
  # exa # better ls
  ripgrep # better grep
  tealdeer # terser man
  fd # improved find
  # procs # process monitor
  # tailscale # vpn management # not supported on macos
  smartmontools # ssd health monitoring
  bottom # a better top
  dua # a better du
  borgbackup # backup
  # oil # better shell language for scripts
  gitAndTools.delta # better git diff
  # sd # better sed
  # choose # better cut & awk
  # hyperfine # benchmarking tool
  # xh # http client
  mosh # better ssh
  # file # get informations about files
  # moreutils # sponge
  # zstd # fast compression
  # jq # working with json
  # btop # top with cpufreq
  # sequoia # openpgp in rust
  # ruplacer # sed with visual feedback
  ouch # painless (de)compression
  solo2-cli # updating solokeys
  # sqlite
  # ffmpeg
  uutils-coreutils
  shell_gpt
  gptcommit
  skim # search mode for atuin
  pueue
  # sniffnet # packet analysis
  awscli2 # used to get logs out of r2
  # wireguard-tools # for wireguard
  # trippy # network diagnostic tool
  # rustypaste # file sharing service
]
