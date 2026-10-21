# rustic with the cache temp-file collision fixed: two threads writing the same
# pack's cache file raced on one `<id>-tmp-` name. Shared by rustic.nix and
# rustic-local.nix.
pkgs:
pkgs.rustic.overrideAttrs (old: {
  cargoDeps = pkgs.runCommand "rustic-cargo-deps-patched" { } ''
    cp -r ${old.cargoDeps} $out
    chmod -R u+w $out
    core=$(echo $out/source-registry-*/rustic_core-*)
    substituteInPlace "$core/src/backend/cache.rs" --replace-fail \
      'dir.join(id.to_hex().to_string() + "-tmp-")' \
      'dir.join(format!("{}-tmp-{:?}", id.to_hex().as_str(), std::thread::current().id()))'
  '';
})
