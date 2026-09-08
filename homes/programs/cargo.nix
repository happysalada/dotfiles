# Cargo's user-level config, which exists to point the link step at mold.
#
# clang and mold come from packages/dev/rust-toolchain.nix; being on PATH is
# not enough on its own. rustc picks `cc` and whatever ld that driver defaults
# to unless told otherwise, so without this file mold is installed and unused.
#
# Scoped to the host triple deliberately. A bare [build] rustflags would follow
# every cross build too, and mold cannot link wasm32 or musl targets.
{ ... }:
{
  home.file.".cargo/config.toml".text = ''
    # Generated from homes/programs/cargo.nix - do not edit in place.
    # This is a read-only store symlink. Edit the nix file and rebuild.
    #
    # Per-project .cargo/config.toml still wins over this, so a repo that needs
    # its own linker keeps it.

    [target.x86_64-unknown-linux-gnu]
    linker = "clang"
    rustflags = [ "-C", "link-arg=-fuse-ld=mold" ]
  '';
}
