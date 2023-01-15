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
  rust-analyzer-unwrapped
  (rust-bin.stable.latest.default.override {
    extensions = [ "rust-src" ]; 
  })
  worker-build
  lldb_13
]
