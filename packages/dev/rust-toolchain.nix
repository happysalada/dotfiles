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
      # llvm-cov and llvm-profdata, which cargo-llvm-cov shells out to. It
      # locates them under this toolchain's sysroot, so without the component
      # the command fails no matter that its own package is installed.
      "llvm-tools-preview"
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

  cargo-modules # the crate's real module tree, item visibility and orphaned
  # items, parsed by rust-analyzer rather than by text, so it resolves through
  # macros and generics that the same question in ast-grep cannot.

  cargo-hack # builds every feature combination, not just the default set. The
  # only thing that catches code added behind a #[cfg(feature = "...")] that a
  # plain `cargo check` never compiles.

  cargo-semver-checks # whether a change to a published crate is breaking,
  # before the version number is picked. Runs on the stable toolchain above -
  # the nightly rustdoc JSON its documentation calls for is not needed.

  cargo-deny # advisories, licenses, bans and sources in one check. Supersedes
  # cargo-audit, which covers the first of those alone.

  cargo-mutants # mutates the source and reports the mutations the tests still
  # pass, which is the difference between a test that asserts something and one
  # that merely runs the line.

  cargo-insta # reviews and accepts `insta` snapshots; without it a changed
  # snapshot is a file to hand-edit rather than a diff to confirm.

  cargo-llvm-cov # line and branch coverage. Needs llvm-tools-preview from the
  # toolchain above - package alone is not enough, see the note there.

  cargo-watch # rebuilds on save. For interactive use, not for an agent, which
  # runs `cargo check` once and reads the result.

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
