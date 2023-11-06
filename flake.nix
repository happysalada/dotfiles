{
  description = "yt's darwin system";

  inputs = {
    # Package sets
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # nixpkgs.url = "github:nixos/nixpkgs/bff259efb29a9fe61375d5b49bec69d6ebf2cd71";
    # nixpkgs.url = "github:happysalada/nixpkgs/windmill_init_module";
    # nixpkgs.url = "github:nixos/nixpkgs";

    # Environment/system management
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    # home-manager.url = "github:happysalada/home-manager/nushell_let_env";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # nix
    flake-utils.url = "github:numtide/flake-utils";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.darwin.follows = "darwin";
    agenix.inputs.home-manager.follows = "home-manager";
    nixinate.url = "github:matthewcroughan/nixinate";
    nixinate.inputs.nixpkgs.follows = "nixpkgs";
    # deploy-rs.url = "github:serokell/deploy-rs";
    # deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    # deploy-rs.inputs.utils.follows = "flake-utils";

    # rust
    crane.url = "github:ipetkov/crane";
    crane.inputs.nixpkgs.follows = "nixpkgs";

    # surrealdb.url = "github:surrealdb/surrealdb";
    # surrealdb.inputs.nixpkgs.follows = "nixpkgs";
    # surrealdb.inputs.crane.follows = "crane";
    # surrealdb.inputs.flake-utils.follows = "flake-utils";

    # helix.url = "github:AlexanderDickie/helix/copilot";
    # helix.inputs.nixpkgs.follows = "nixpkgs";
    # copilot-lsp-src.url = "github:github/copilot.vim";
    # copilot-lsp-src.flake = false;
    # document-search.url = "github:happysalada/document-search";
    # document-search.inputs.nixpkgs.follows = "nixpkgs";
    # document-search.inputs.flake-utils.follows = "flake-utils";

    monorepo.url = "github:bitpeso/monorepo/nix_deploy";
    monorepo.inputs.nixpkgs.follows = "nixpkgs";
    monorepo.inputs.flake-utils.follows = "flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    darwin,
    home-manager,
    agenix,
    nixinate,
    monorepo,
    ...
  }: {
    apps = nixinate.nixinate.x86_64-darwin self;

    darwinConfigurations.mbp = darwin.lib.darwinSystem {
      system = "x86_64-darwin";
      modules = import ./machines/mbp.nix {inherit home-manager agenix; };
    };

    nixosConfigurations.bee = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = import ./machines/bee {inherit home-manager agenix;};
    };

    nixosConfigurations.hetz = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = import ./machines/hetz {inherit home-manager agenix monorepo;};
    };

    # This is highly advised, and will prevent many possible mistakes
    # checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

    # nixosConfigurations.hetzi = nixpkgs.lib.nixosSystem {
    #   system = "x86_64-linux";
    #   modules = import ./machines/hetzner_cloud/default.nix {inherit home-manager agenix rust-overlay;};
    # };

    # nixosConfigurations.htz = nixpkgs.lib.nixosSystem {
    #   system = "x86_64-linux";
    #   modules = import ./machines/hetzner_dedicated/default.nix {inherit home-manager agenix rust-overlay;};
    # };

    # homeConfigurations.thinkpad = home-manager.lib.homeManagerConfiguration {
    #   system = "x86_64-linux";
    #   homeDirectory = "/home/user";
    #   username = "user";
    #   configuration.imports = [./machines/thinkpad.nix];
    # };

    # darwinConfigurations.m1 = darwin.lib.darwinSystem {
    #   system = "aarch64-darwin";
    #   modules = import ./machines/m1.nix {inherit home-manager agenix rust-overlay;};
    # };
  };
}
