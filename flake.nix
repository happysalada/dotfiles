{
  description = "yt's nixos systems";

  inputs = {
    # Package sets
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    opencode-v2.url = "github:anomalyco/opencode/v2";
    opencode-v2.inputs.nixpkgs.follows = "nixpkgs";

    # Hardware quirks (asus battery, nvidia prime, intel cpu, ...)
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    # Environment/system management
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # nix
    flake-utils.url = "github:numtide/flake-utils";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    nixinate.url = "github:matthewcroughan/nixinate";
    nixinate.inputs.nixpkgs.follows = "nixpkgs";

    megzari_com.url = "github:happysalada/svelte.megzari.com";
    megzari_com.inputs.nixpkgs.follows = "nixpkgs";
    megzari_com.inputs.flake-utils.follows = "flake-utils";

    # prebuilt nix-index database, weekly - `, <cmd>` and `nix-locate` work
    # without an hour-long local index run
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    # rust
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      opencode-v2,
      nixos-hardware,
      home-manager,
      agenix,
      nixinate,
      megzari_com,
      rust-overlay,
      nix-index-database,
      ...
    }:
    {
      # deploys are now driven from the linux workstation rather than the mbp
      apps = nixinate.nixinate.x86_64-linux self;

      nixosConfigurations.strix = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = import ./machines/strix {
          inherit
            home-manager
            agenix
            nixos-hardware
            rust-overlay
            nix-index-database
            opencode-v2
            ;
        };
      };

      nixosConfigurations.bee = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = import ./machines/bee { inherit home-manager agenix megzari_com; };
      };

      nixosConfigurations.hetz = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = import ./machines/hetz { inherit home-manager agenix; };
      };
    };
}
