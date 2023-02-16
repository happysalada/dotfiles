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
    agenix.inputs.darwin.follows = "darwin";
    nix-update.url = "github:Mic92/nix-update";
    nix-update.inputs.nixpkgs.follows = "nixpkgs";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    nixinate.url = "github:matthewcroughan/nixinate";
    nixinate.inputs.nixpkgs.follows = "nixpkgs";
    nil.url = "github:oxalica/nil";
    nil.inputs.nixpkgs.follows = "nixpkgs";
    alejandra.url = "github:kamadorueda/alejandra";
    alejandra.inputs.nixpkgs.follows = "nixpkgs";

    # macrodata
    crane.url = "github:ipetkov/crane";
    crane.inputs.nixpkgs.follows = "nixpkgs";
    crane.inputs.rust-overlay.follows = "rust-overlay";

    macrodata.url = "git+file:///var/lib/gitea/repositories/yt/macrodata";
    macrodata.inputs.nixpkgs.follows = "nixpkgs";
    macrodata.inputs.crane.follows = "crane";
    macrodata.inputs.surrealdb.follows = "surrealdb";
    macrodata.inputs.rust-overlay.follows = "rust-overlay";

    surrealdb.url = "github:surrealdb/surrealdb";
    surrealdb.inputs.nixpkgs.follows = "nixpkgs";
    surrealdb.inputs.crane.follows = "crane";

    adafilter.url = "git+file:///var/lib/gitea/repositories/yt/adafilter";
    adafilter.inputs.nixpkgs.follows = "nixpkgs";
    adafilter.inputs.crane.follows = "crane";
    adafilter.inputs.rust-overlay.follows = "rust-overlay";
  };

  outputs = {
    self,
    nixpkgs,
    darwin,
    home-manager,
    nixpkgs-review,
    agenix,
    nix-update,
    rust-overlay,
    nixinate,
    nil,
    alejandra,
    macrodata,
    surrealdb,
    adafilter,
    ...
  }: {
    apps = nixinate.nixinate.x86_64-darwin self;

    darwinConfigurations.mbp = darwin.lib.darwinSystem {
      system = "x86_64-darwin";
      modules = import ./machines/mbp.nix {inherit home-manager nixpkgs-review agenix nix-update rust-overlay nil alejandra;};
    };

    darwinConfigurations.m1 = darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = import ./machines/m1.nix {inherit home-manager agenix rust-overlay;};
    };

    homeConfigurations.thinkpad = home-manager.lib.homeManagerConfiguration {
      system = "x86_64-linux";
      homeDirectory = "/home/user";
      username = "user";
      configuration.imports = [./machines/thinkpad.nix];
    };

    nixosConfigurations.hetzi = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = import ./machines/hetzner_cloud/default.nix {inherit home-manager agenix rust-overlay;};
    };

    nixosConfigurations.htz = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = import ./machines/hetzner_dedicated/default.nix {inherit home-manager agenix rust-overlay;};
    };

    nixosConfigurations.bee = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = import ./machines/bee/default.nix {inherit home-manager agenix rust-overlay nix-update macrodata surrealdb adafilter;};
    };
  };
}
