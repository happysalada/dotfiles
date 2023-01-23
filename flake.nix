{
  description = "yt's darwin system";

  inputs = {
    # Package sets
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # nixpkgs.url = "github:nixos/nixpkgs";
    # nixpkgs.url = "github:happysalada/nixpkgs/surrealdb_add_package_option";

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
    nil.url = "github:oxalica/nil";
    nil.inputs.nixpkgs.follows = "nixpkgs";
    
    # macrodata
    crane.url = "github:ipetkov/crane";
    crane.inputs.nixpkgs.follows = "nixpkgs";

    macrodata.url = "git+file:///var/lib/gitea/repositories/yt/macrodata";
    macrodata.inputs.nixpkgs.follows = "nixpkgs";
    macrodata.inputs.crane.follows = "crane";

    surrealdb.url = "github:surrealdb/surrealdb";
    # surrealdb.inputs.nixpkgs.follows = "nixpkgs";
    surrealdb.inputs.crane.follows = "crane";

    mediaSummary.url = "git+file:///var/lib/gitea/repositories/yt/media_summary";
    mediaSummary.inputs.nixpkgs.follows = "nixpkgs";
    mediaSummary.inputs.crane.follows = "crane";
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
    , nil
    , macrodata
    , surrealdb
    , mediaSummary
    , ...
    }: {
      apps = nixinate.nixinate.x86_64-darwin self;

      darwinConfigurations.mbp = darwin.lib.darwinSystem {
        system = "x86_64-darwin";
        modules = import ./machines/mbp.nix { inherit home-manager nixpkgs-review agenix nix-update rust-overlay nil; };
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
        modules = import ./machines/hetzner_cloud/default.nix { inherit home-manager agenix rust-overlay; };
      };

      nixosConfigurations.htz = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = import ./machines/hetzner_dedicated/default.nix { inherit home-manager agenix rust-overlay; };
      };
      
      nixosConfigurations.bee = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = import ./machines/bee/default.nix { inherit home-manager agenix rust-overlay nix-update macrodata surrealdb mediaSummary; };
      };
    };
}
