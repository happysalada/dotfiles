home-manager.nixosModules.home-manager {
  # `home-manager` config
  home-manager.useGlobalPkgs = true;
  home-manager.users.yt = ({
    home = {
      username = "yt";
      # This value determines the Home Manager release that your
      # configuration is compatible with. This helps avoid breakage
      # when a new Home Manager release introduces backwards
      # incompatible changes.
      #
      # You can update Home Manager without changing this value. See
      # the Home Manager release notes for a list of state version
      # changes in each release.
      stateVersion = "22.05";
      homeDirectory = /home/yt;

      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      packages = with pkgs; [
        # network
        mtr # network traffic
        # tcptrack

        # shell stuff
        nodePackages.bash-language-server
        shellcheck

        remarshal
        comby
      ] ++
      (import ../packages/basic_cli_set.nix { inherit pkgs; }) ++
      (import ../packages/dev/rust.nix { inherit pkgs; }) ++
      (import ../packages/dev/js.nix { inherit pkgs; }) ++
      (import ../packages/dev/nix.nix { inherit pkgs; });

      file.".cargo/config.toml".source = ../config/cargo.toml;
    };
    news.display = "silent";
    programs = import ../homes/common.nix { inherit pkgs; };
  });
}
