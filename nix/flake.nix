{
  description = "yt's darwin system";

  inputs = {
    # Package sets
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Environment/system management
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # nix
    nixpkgs-review.url = "github:Mic92/nixpkgs-review";
    nixpkgs-review.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    nix-update.url = "github:Mic92/nix-update";
    nix-update.inputs.nixpkgs.follows = "nixpkgs";

    # tools
    helix = { url = "/Users/raphael/Projects/helix"; };

    # Other sources
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
  };

  outputs =
    { self
    , nixpkgs
    , darwin
    , home-manager
    , flake-compat
    , nixpkgs-review
    , agenix
    , nix-update
    , helix
    , ...
    }@inputs: {

      # My `nix-darwin` configs
      darwinConfigurations.raphael = darwin.lib.darwinSystem {
        system = "x86_64-darwin";
        modules = [
          ./darwin.nix
          agenix.nixosModules.age
          # `home-manager` module
          home-manager.darwinModules.home-manager
          {
            # `home-manager` config
            home-manager.useGlobalPkgs = true;
            home-manager.users.raphael = import ./home.nix {
              inherit nixpkgs-review agenix nix-update helix;
            };
          }
        ];
      };
    };
}
