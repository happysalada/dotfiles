{ pkgs }:
with pkgs;
[
  ripgrep # better grep
  tealdeer # terser man
  fd # improved find
  procs # process monitor
  smartmontools # ssd health monitoring
  bottom # a better top
  dua # a better du
  restic # backup
  # oil # better shell language for scripts
  delta # better git diff
  sd # better sed
  choose # better cut & awk
  # hyperfine # benchmarking tool
  xh # http client
  # file # get informations about files
  # moreutils # sponge
  # zstd # fast compression
  (symlinkJoin {
    name = "jaq-with-jq-alias-${jaq.version}";
    paths = [ jaq ];
    postBuild = ''
      ln -s jaq "$out/bin/jq"
    '';
  }) # jq-compatible Rust implementation, also exposed under the familiar name
  jsongrep # `jg`, search structured data without jq filters
  ast-grep # `sg`, structural/AST search+rewrite where ripgrep's regex runs out
  # sequoia-sq # openpgp in rust
  # ruplacer # sed with visual feedback
  ouch # painless (de)compression
  solo2-cli # updating solokeys
  # sqlite
  uutils-coreutils
  skim # search mode for atuin
  fzf # zoxide's `zi` interactive picker shells out to fzf specifically
  pueue
  # awscli2 # used to get logs out of r2
  # rustypaste # file sharing service
  killport # kill a service on a port
  igrep
  gh
  jjui
  prek # pre-commit in rust; runs this repo's .pre-commit-config.yaml
  bat
  termscp
  numbat # over libqalculate
  qsv # data wrangling
  tabiew # tui viewer for csv/parquet/json, sql over files
  ripgrep-all # ripgrep for pdf and all docs
  systemctl-tui # browse/control systemd units and their logs
  # epy # ebook cli reader
]
