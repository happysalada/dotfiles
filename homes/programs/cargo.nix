# Cargo's user-level config: cache the compile step, point the link step at mold.
#
# Both settings exist because being on PATH is not enough on its own. rustc picks
# `cc` and whatever ld that driver defaults to unless told otherwise, and cargo
# will not use a compiler wrapper unless it is named here - so without this file
# sccache and mold are both installed and both unused.
#
# sccache and mold come from packages/dev/rust-toolchain.nix.
#
# The linker is scoped to the host triple deliberately. A bare [build] rustflags
# would follow every cross build too, and mold cannot link wasm32 or musl targets.
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
