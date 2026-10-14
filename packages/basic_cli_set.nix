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
  openssl # the CLI (rand, x509, s_client); the lib is already a transitive dep of half the closure
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
  ripgrep-all # ripgrep for pdf and all docs
  systemctl-tui # browse/control systemd units and their logs

  # Secrets, one CLI over many providers (age identity files, the keyring, cloud
  # stores). Nothing is configured here: the providers and their values live in a
  # per-project fnox.toml, which `fnox init` writes. Its age provider reads an
  # identity file itself, so `age`/`rage` is only needed to *create* one.
  fnox

  # For fnox's age provider, and only for making that identity file: fnox
  # encrypts and decrypts in-process - it vendors the age crate - and merely
  # tells you to `age-keygen -o ...`. rage will not do: it ships `rage-keygen`,
  # and this is the package that provides the name fnox prints.
  age

  # nixpkgs has no bookokrat (its init PR, NixOS/nixpkgs#488100, was closed
  # unmerged), so the package comes from upstream's own flake through the
  # overlay in each machine's nixpkgs.overlays. It replaces the commented-out
  # `epy` this list used to carry.
  bookokrat # terminal EPUB/PDF/DJVU reader
]
