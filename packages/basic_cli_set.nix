{ pkgs }:
with pkgs;
[
  ripgrep # better grep
  tealdeer # terser man
  fd # improved find
  # procs # process monitor
  # tailscale # vpn management # not supported on macos
  smartmontools # ssd health monitoring
  bottom # a better top
  dua # a better du
  restic # backup
  # oil # better shell language for scripts
  gitAndTools.delta # better git diff
  # sd # better sed
  # choose # better cut & awk
  # hyperfine # benchmarking tool
  # xh # http client
  # mosh # better ssh
  # file # get informations about files
  # moreutils # sponge
  # zstd # fast compression
  jaq # jq built in rust
  # btop # top with cpufreq
  # sequoia-sq # openpgp in rust
  # ruplacer # sed with visual feedback
  ouch # painless (de)compression
  solo2-cli # updating solokeys
  # sqlite
  # ffmpeg
  uutils-coreutils
  # shell_gpt
  # gptcommit
  skim # search mode for atuin
  pueue
  # sniffnet # packet analysis
  # awscli2 # used to get logs out of r2
  # wireguard-tools # for wireguard
  # trippy # network diagnostic tool
  # rustypaste # file sharing service
  killport # kill a service on a port
  # clipboard-jh # fails to build on macos
  igrep
  # ast-grep
  gh
  bat
  termscp
  numbat # over libqalculate
  qsv # data wrangling
  ripgrep-all # ripgrep for pdf and all docs
  # intentrace # clearer strace # not available on macos
  # epy # ebook cli reader
]
