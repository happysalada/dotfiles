{
  description = "yt's darwin system";

  inputs = {
    # Package sets
    # nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs.url = "github:nixos/nixpkgs";

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
    nixos-hardware.url = "github:happysalada/nixos-hardware/add_p14s_intel";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs =
    { self
    , nixpkgs
    , darwin
    , home-manager
    , nixpkgs-review
    , agenix
    , nix-update
    , nixos-hardware
    , rust-overlay
    , ...
    }@inputs: {

      darwinConfigurations.mbp = darwin.lib.darwinSystem {
        system = "x86_64-darwin";
        modules = [
          ./darwin.nix
          agenix.nixosModules.age
          ({ ... }: {
            nixpkgs.overlays = [ rust-overlay.overlay ];
          })
          # `home-manager` module
          home-manager.darwinModules.home-manager
          {
            # `home-manager` config
            home-manager.useGlobalPkgs = true;
            home-manager.users.raphael = import ./home.nix { inherit nixpkgs-review agenix nix-update; username = "raphael"; };
          }

        ];
      };
      
      nixosConfigurations.thinkp = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./nixos.nix
          agenix.nixosModules.age
          # `home-manager` module
          home-manager.nixosModules.home-manager
          {
            # `home-manager` config
            home-manager.useGlobalPkgs = true;
            home-manager.users.yt = import ./home.nix { inherit nixpkgs-review agenix nix-update ; username = "yt"; };
          }
          nixos-hardware.nixosModules.lenovo-thinkpad-p14s-intel-gen2
        ];
      };
    };
}
