{ pkgs }:
with pkgs; [
  sccache
  cargo-edit
  cargo-deps
  wasm-pack
  sqlx-cli
  cargo-audit
  cargo-outdated
  cargo-bloat
  cargo-cross
  cargo-sort
  rust-analyzer
  rust-bin.stable.latest.default
  worker-build
  wrangler
]
