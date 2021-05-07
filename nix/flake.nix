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

    # nix
    nixpkgs-update.url = "github:ryantm/nixpkgs-update";
    nixpkgs-review.url = "github:Mic92/nixpkgs-review";
    nixpkgs-review.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    # Other sources
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
  };

  outputs =
    { self
    , nixpkgs
    , darwin
    , home-manager
    , flake-compat
    , nixpkgs-update
    , nixpkgs-review
    , agenix
    , ...
    }@inputs: {

      # My `nix-darwin` configs
      darwinConfigurations.raphael = darwin.lib.darwinSystem {
        modules = [
          ./darwin.nix
          agenix.nixosModules.age
          # `home-manager` module
          home-manager.darwinModules.home-manager
          {
            # `home-manager` config
            home-manager.useGlobalPkgs = true;
            home-manager.users.raphael = import ./home.nix {
              inherit nixpkgs-update nixpkgs-review agenix;
            };
          }
        ];
      };
    };
}
