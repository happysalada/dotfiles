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
  hyperfine # benchmarking tool
  xh # http client
  file # get informations about files
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
  unzip # what scripts and agents call, whatever ouch can do
  zip
  b3sum # blake3 sums, when that is the hash a project publishes
  tree
  solo2-cli # updating solokeys
  sqlite
  uutils-coreutils
  skim # search mode for atuin
  fzf # zoxide's `zi` interactive picker shells out to fzf specifically
  # the client only - strix gets pueued and ~/.config/pueue/pueue.yml from
  # homes/programs/pueue.nix; bee and hetz are not driving queues from a
  # desktop, so they need nothing beyond the CLI.
  pueue
  # awscli2 # used to get logs out of r2
  # rustypaste # file sharing service
  killport # kill a service on a port
  igrep
  # gh moved to `programs.gh` (homes/programs/gh.nix) so its config.yml stops
  # being an imperative file on every host that has it. That module is wired on
  # strix only as of now, so this list deliberately leaves the CLI out: a host
  # that wants it adds the same import rather than getting the bare binary back.
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
