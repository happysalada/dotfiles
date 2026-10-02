# Cargo's user-level config: cache the compile step, point the link step at mold.
# Being on PATH is not enough - rustc picks `cc` and its default ld unless told
# otherwise, and cargo ignores a compiler wrapper unless named here - so without
# this file sccache and mold are both installed and both unused (both from
# packages/dev/rust-toolchain.nix).
#
# The linker is scoped to the host triple deliberately: a bare [build] rustflags
# would follow every cross build too, and mold cannot link wasm32 or musl. Nor is
# it universal within the triple - a dependency whose own C library Zig builds
# (herdr's vendored libghostty-vt) comes out with relocations mold rejects and
# wants lld; a repo picks lld with the per-project override below.
{ ... }:
{
  home.file.".cargo/config.toml".text = ''
    # Generated from homes/programs/cargo.nix - do not edit in place.
    # This is a read-only store symlink. Edit the nix file and rebuild.
    #
    # Per-project .cargo/config.toml still wins over this, so a repo that needs
    # its own linker keeps it.

    # Compilation caching for every cargo build on this machine. sccache keys on
    # the compiler invocation, so an unchanged crate is a cache hit wherever it
    # is built - project, branch or target directory - which is the whole point
    # of setting it globally rather than once per repository.
    #
    # Deliberately NOT scoped to the host triple, unlike rustflags below: the
    # wrapper is safe for cross builds, the linker flags are not.
    [build]
    rustc-wrapper = "sccache"

    [target.x86_64-unknown-linux-gnu]
    linker = "clang"
    rustflags = [ "-C", "link-arg=-fuse-ld=mold" ]
  '';
}
