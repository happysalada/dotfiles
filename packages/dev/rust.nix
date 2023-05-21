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
  (rust-bin.stable.latest.default.override {
    extensions = [ "rust-src" ]; 
  })
  # both of the following are required for cloudflare workers
  worker-build
  nodePackages_latest.wrangler
  # compilation related
  llvmPackages_latest.clang
  llvmPackages_latest.lld
]
