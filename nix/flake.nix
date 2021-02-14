{
  description = "yt's darwin system";

  inputs = {
    # Package sets
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable-darwin.url = "github:nixos/nixpkgs/nixpkgs-20.09-darwin";

    # Environment/system management
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Editor
    nix-doom-emacs.url = "github:vlaci/nix-doom-emacs";

    # Other sources
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
  };

  outputs = { self, nixpkgs, darwin, home-manager, nix-doom-emacs, ... }@inputs: {

    # My `nix-darwin` configs
    darwinConfigurations.raphael = darwin.lib.darwinSystem {
      modules = [
        ./darwin.nix
        # `home-manager` module
        home-manager.darwinModules.home-manager
        {
          # `home-manager` config
          # users.users.raphael.home = "/Users/raphael";
          home-manager.useGlobalPkgs = true;
          home-manager.users.raphael = import ./home.nix {inherit nix-doom-emacs;};
        }
      ];
    };
  };
}
