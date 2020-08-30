{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    rustc cargo rustfmt rustPackages.clippy
    cargo-watch
    cargo-edit

    openssl
  ];
  RUST_BACKTRACE = 1;
}