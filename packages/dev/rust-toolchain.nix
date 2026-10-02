# The Rust toolchain, from rust-overlay rather than nixpkgs.
#
# nixpkgs' rustc trails stable and ships a separately-versioned `rust-analyzer`,
# which drifts from the rustc tree and reports phantom "unresolved import" errors
# on code that compiles; rust-overlay takes both from static.rust-lang.org, so
# they cannot drift. Bump it with `nix flake update rust-overlay`, not an edit
# here. Workstation only: without the overlay `rust-bin` does not exist, which is
# why the servers import the empty ./rust.nix instead.
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
  # `cargo check`, `clippy` and `rustfmt` ship above and are the tight loop;
  # these answer what it cannot.

  cargo-nextest # test runner with a stable, machine-readable summary. The
  # built-in harness interleaves parallel threads' output, which is easy to
  # misattribute.

  cargo-expand # shows what a derive or macro_rules! actually expanded to -
  # the only reliable way to settle it, short of reading the macro's source.

  cargo-machete # dependencies still declared in Cargo.toml but no longer used,
  # a common leftover once a module gets refactored away.

  # cargo-semver-checks # whether a change to a published crate is breaking,
  # before the version number is picked.

  # Compilation caching - without it every `cargo clean`, fresh clone and wiped
  # target/ recompiles the whole dependency graph. Selected in
  # homes/programs/cargo.nix via [build] rustc-wrapper; on PATH alone it does
  # nothing, the same trap as mold below.
  sccache

  # ---- the link step ----
  #
  # rustc shells out to a C compiler to link, so with no cc on PATH every build
  # dies at "linker `cc` not found"; the toolchain above ships no C toolchain.
  # clang is the smaller candidate and needs no libstdc++ for Rust's purposes.
  clang

  # The default ld is single-threaded and dominates the edit-build-run loop here.
  # mold is selected in homes/programs/cargo.nix; on PATH alone it does nothing.
  mold

  # mold is not universal: a dependency whose build compiles its C library with
  # Zig - herdr's vendored libghostty-vt is one - produces relocations in zig's
  # compiler_rt.o that mold refuses outright ("undefined symbol:" with no name),
  # where lld links the same objects and keeps the .eh_frame_hdr table. Nothing
  # selects this globally; a repo that trips it overrides link-arg in its own
  # .cargo/config.toml or RUSTFLAGS="-C link-arg=-fuse-ld=lld", both needing
  # only lld on PATH (clang is the driver and finds ld.lld there).
  lld
]
