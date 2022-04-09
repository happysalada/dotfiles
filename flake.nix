{
  description = "yt's darwin system";

  inputs = {
    # Package sets
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # nixpkgs.url = "github:nixos/nixpkgs";

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
    rust-overlay.url = "github:oxalica/rust-overlay";
    nixinate.url = "github:matthewcroughan/nixinate";
    nixinate.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { self
    , nixpkgs
    , darwin
    , home-manager
    , nixpkgs-review
    , agenix
    , nix-update
    , rust-overlay
    , nixinate
    }@inputs: {
      apps = nixinate.nixinate.x86_64-darwin self;

      darwinConfigurations.mbp = darwin.lib.darwinSystem {
        system = "x86_64-darwin";
        modules = import ./machines/mbp.nix { inherit home-manager nixpkgs-review agenix nix-update rust-overlay; };
      };

      darwinConfigurations.m1 = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = import ./machines/m1.nix { inherit home-manager agenix rust-overlay; };
      };

      homeConfigurations.thinkpad = home-manager.lib.homeManagerConfiguration {
        system = "x86_64-linux";
        homeDirectory = "/home/user";
        username = "user";
        configuration.imports = [ ./machines/thinkpad.nix ];
      };


      nixosConfigurations.hetzi = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = import ./machines/hetzner_cloud/default.nix { inherit home-manager agenix; };
      };
    };
}
