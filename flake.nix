{
  description = "yt's darwin system";

  inputs = {
    # Package sets
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # nixpkgs.url = "github:happysalada/nixpkgs/llama_cpp_fix_cuda_support";
    # nixpkgs.url = "github:happysalada/nixpkgs/aide_init_module";
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

    # copilot-lsp-src.url = "github:github/copilot.vim";
    # copilot-lsp-src.flake = false;
    # document-search.url = "github:happysalada/document-search";
    # document-search.inputs.nixpkgs.follows = "nixpkgs";
    # document-search.inputs.flake-utils.follows = "flake-utils";

    monorepo.url = "github:bitpeso/monorepo";
    monorepo.inputs.nixpkgs.follows = "nixpkgs";
    monorepo.inputs.flake-utils.follows = "flake-utils";

    lead.url = "github:happysalada/12-lead";
    lead.inputs.nixpkgs.follows = "nixpkgs";
    lead.inputs.flake-utils.follows = "flake-utils";

    designhub.url = "github:happysalada/designhub";
    designhub.inputs.nixpkgs.follows = "nixpkgs";
    designhub.inputs.flake-utils.follows = "flake-utils";

    megzari_com.url = "github:happysalada/svelte.megzari.com";
    megzari_com.inputs.nixpkgs.follows = "nixpkgs";
    megzari_com.inputs.flake-utils.follows = "flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    darwin,
    home-manager,
    agenix,
    nixinate,
    monorepo,
    lead,
    designhub,
    megzari_com,
    ...
  }: {
    apps = nixinate.nixinate.x86_64-darwin self;

    darwinConfigurations.mbp = darwin.lib.darwinSystem {
      system = "x86_64-darwin";
      modules = import ./machines/mbp.nix {inherit home-manager agenix; };
    };

    nixosConfigurations.bee = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = import ./machines/bee {inherit home-manager agenix megzari_com;};
    };

    nixosConfigurations.hetz = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = import ./machines/hetz {inherit home-manager agenix monorepo lead designhub;};
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
