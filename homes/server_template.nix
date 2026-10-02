home-manager.nixosModules.home-manager {
  # `home-manager` config
  home-manager.useGlobalPkgs = true;
  home-manager.users.yt = ({
    home = {
      username = "yt";
      # Determines the Home Manager release this configuration is compatible
      # with: bump it to follow upstream's state-version changes. Updating Home
      # Manager itself does not require changing it.
      stateVersion = "22.05";
      homeDirectory = /home/yt;

      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      packages =
        with pkgs;
        [
          # network
          mtr # network traffic
          # tcptrack

          # shell stuff
          nodePackages.bash-language-server
          shellcheck

          remarshal
          comby
        ]
        ++ (import ../packages/basic_cli_set.nix { inherit pkgs; })
        ++ (import ../packages/dev/rust.nix { inherit pkgs; })
        ++ (import ../packages/dev/js.nix { inherit pkgs; })
        ++ (import ../packages/dev/nix.nix { inherit pkgs; });

      file.".cargo/config.toml".source = ../config/cargo.toml;
    };
    news.display = "silent";
    programs = import ../homes/common.nix { inherit pkgs; };
  });
}
