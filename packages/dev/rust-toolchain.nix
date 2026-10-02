# The Rust toolchain, from rust-overlay rather than nixpkgs.
#
# Two reasons not to use nixpkgs' rustc here. It trails stable by a release or
# two (1.97.1 against upstream's 1.98.0), and its `rust-analyzer` is a
# separately-versioned nixpkgs package rather than the analyzer built from that
# rustc's tree - when the two drift you get phantom "unresolved import" errors
# on code that compiles. rust-overlay takes both from static.rust-lang.org, so
# they are always the same release.
#
# `stable.latest` resolves against the rust-overlay flake input, so bumping the
# toolchain is `nix flake update rust-overlay`, not an edit here.
#
# Workstation only. The overlay is applied in machines/strix/default.nix, and
# without it `rust-bin` does not exist and this file fails to evaluate - which
# is why the servers keep importing the empty ./rust.nix instead.
#
# Nothing below is compiled locally: rust-overlay unpacks upstream's release
# tarballs, and the cargo tools come from cache.nixos.org.
{ pkgs }:
with pkgs;
[
  (rust-bin.stable.latest.default.override {
    extensions = [
      # the language server, built from the same tree as this rustc
      "rust-analyzer"
      # std's sources. rust-analyzer cannot resolve anything in std without
      # them, so every std symbol reads as an error and completion is dead.
      "rust-src"
    ];
  })

  # ---- what an agent reaches for beyond the toolchain ----
  #
  # `cargo check`, `clippy` and `rustfmt` ship with the toolchain above and are
  # the tight loop. These four answer what that loop cannot.

  cargo-nextest # test runner with a stable, machine-readable summary. The
  # built-in harness interleaves output from parallel threads, which is exactly
  # the shape of text that is expensive to read and easy to misattribute.

  cargo-expand # shows what a derive or macro_rules! actually expanded to -
  # the only reliable way to settle that, short of reading the macro's source.

  cargo-machete # dependencies still declared in Cargo.toml but no longer used,
  # a common leftover once a module gets refactored away.

  # cargo-semver-checks # whether a change to a published crate is breaking,
  # before the version number is picked.

  # ---- the compile step ----
  #
  # Compilation caching. Without it, every `cargo clean`, every fresh clone and
  # every wiped target/ recompiles the whole dependency graph, which is the
  # single largest cost in the edit-build-run loop on a machine this fast.
  #
  # Selected in homes/programs/cargo.nix via [build] rustc-wrapper - being on
  # PATH alone changes nothing, the same trap as mold below.
  sccache

  # ---- the link step ----
  #
  # rustc emits object files and then shells out to a C compiler to link them,
  # so with no cc on PATH every build dies at "linker `cc` not found" - the
  # rust-overlay toolchain above ships no C toolchain of its own. clang is the
  # smaller of the two candidates and needs no libstdc++ for Rust's purposes.
  clang

  # The default ld is single-threaded and dominates the edit-build-run loop on
  # a crate graph this size. mold is selected in homes/programs/cargo.nix -
  # having it on PATH alone changes nothing.
  mold

  # mold is not a universal linker, and the exception is worth having on PATH.
  # A dependency whose build compiles its C library with Zig - herdr's vendored
  # libghostty-vt is one - produces relocations in zig's own compiler_rt.o that
  # mold refuses outright ("undefined symbol:" with no name at all), where lld
  # links the same objects and keeps the .eh_frame_hdr table that turning the
  # header off instead would throw away.
  #
  # Nothing selects this globally: homes/programs/cargo.nix still points every
  # host build at mold, which is the faster linker for the ordinary case. A repo
  # that trips the above overrides link-arg in its own .cargo/config.toml, which
  # wins over the user-level file exactly as that comment says, or per run with
  # RUSTFLAGS="-C link-arg=-fuse-ld=lld". Both need nothing but lld on PATH -
  # clang is the driver and finds ld.lld there.
  lld
]
