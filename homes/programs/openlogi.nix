# Seeds ~/.config/openlogi/config.toml once, then leaves it to the app.
#
# It cannot be a home.file entry: the GUI persists by renaming a temp file over
# the path (crates/openlogi-core/src/config/file.rs), which replaces a store
# symlink rather than writing through it. With home-manager.backupFileExtension
# set, the following activation would move that real file to config.toml.hm-bak
# and restore the symlink - so every in-app change would revert on the next
# rebuild, silently. Copying only when the file is absent keeps the app the
# source of truth after the first save, and this file as the starting point.
#
# The package, its udev rules and the agent unit come from the NixOS side
# (machines/strix, openlogi.nixosModules.default).
{ config, lib, pkgs, ... }:
let
  # The app resolves $XDG_CONFIG_HOME itself, so this must be that path rather
  # than a literal ~/.config, or the seed lands where nothing reads it.
  configPath = "${config.xdg.configHome}/openlogi/config.toml";
in
{
  home.activation.openlogiSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e ${configPath} ]; then
      run ${pkgs.coreutils}/bin/install -Dm600 ${../../config/openlogi.toml} ${configPath}
    fi
  '';
}
