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
  cargo-sweep
  cargo-cache
  rust-analyzer-unwrapped
  (rust-bin.stable.latest.default.override {
    extensions = [ "rust-src" ]; 
  })
  worker-build
  llvmPackages_latest.clang
  llvmPackages_latest.lldb
]
