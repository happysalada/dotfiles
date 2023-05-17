{
  description = "yt's darwin system";

  inputs = {
    # Package sets
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # nixpkgs.url = "github:nixos/nixpkgs";
    # nixpkgs.url = "github:happysalada/nixpkgs/update_vector";

    # Environment/system management
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # nix
    flake-utils.url = "github:numtide/flake-utils";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.darwin.follows = "darwin";
    agenix.inputs.home-manager.follows = "home-manager";
    nixinate.url = "github:matthewcroughan/nixinate";
    nixinate.inputs.nixpkgs.follows = "nixpkgs";
    alejandra.url = "github:kamadorueda/alejandra";
    alejandra.inputs.nixpkgs.follows = "nixpkgs";
    nix-melt.url = "github:nix-community/nix-melt";
    nix-melt.inputs.nixpkgs.follows = "nixpkgs";
    nurl.url = "github:nix-community/nurl";
    nurl.inputs.nixpkgs.follows = "nixpkgs";

    # rust
    crane.url = "github:ipetkov/crane";
    crane.inputs.nixpkgs.follows = "nixpkgs";
    crane.inputs.rust-overlay.follows = "rust-overlay";
    crane.inputs.flake-utils.follows = "flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    rust-overlay.inputs.flake-utils.follows = "flake-utils";

    # surrealdb.url = "github:surrealdb/surrealdb";
    # surrealdb.inputs.nixpkgs.follows = "nixpkgs";
    # surrealdb.inputs.crane.follows = "crane";
    # surrealdb.inputs.flake-utils.follows = "flake-utils";

    # helix.url = "github:helix-editor/helix";
  };

  outputs = {
    self,
    nixpkgs,
    darwin,
    home-manager,
    agenix,
    rust-overlay,
    nixinate,
    alejandra,
    nix-melt,
    nurl,
    ...
  }: {
    apps = nixinate.nixinate.x86_64-darwin self;

    darwinConfigurations.mbp = darwin.lib.darwinSystem {
      system = "x86_64-darwin";
      modules = import ./machines/mbp.nix {inherit home-manager agenix rust-overlay alejandra nix-melt nurl; };
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
      modules = import ./machines/bee/default.nix {inherit home-manager agenix rust-overlay;};
    };
  };
}
