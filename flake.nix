{
  description = "yt's nixos systems";

  inputs = {
    # Package sets
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # The agent CLIs, packaged together: claude-code, codex, opencode's v2 branch
    # (as `opencode2`), reasonix, openresearch, rtk, icm, nono and
    # terminal-browser. It follows nixpkgs so it is one revision everywhere, and
    # that costs nothing because their binary cache also carries the paths built
    # against nixpkgs-unstable's current HEAD - measured, not assumed: with this
    # pin all eight substitute. The substituter and the overlay that puts them in
    # `pkgs` are in machines/strix/default.nix; packages/ai.nix lists them.
    llm-agents.url = "github:numtide/llm-agents.nix";
    llm-agents.inputs.nixpkgs.follows = "nixpkgs";

    # Hardware quirks (asus battery, nvidia prime, intel cpu, ...)
    # Its nixpkgs input only feeds its own checks, not the modules exported
    # here - following the root one keeps a second full nixpkgs (350 MB) out of
    # the input graph.
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixos-hardware.inputs.nixpkgs.follows = "nixpkgs";

    # Environment/system management
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # nix
    flake-utils.url = "github:numtide/flake-utils";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    nixinate.url = "github:matthewcroughan/nixinate";
    nixinate.inputs.nixpkgs.follows = "nixpkgs";

    # The site on bee. devshell and nuenv come in only through it, and each
    # carries its own 2023-era input - a flake-utils and a 45 MB rust-overlay -
    # that feeds nothing but their own dev shells, so both follow the root ones.
    megzari_com.url = "github:happysalada/svelte.megzari.com";
    megzari_com.inputs.nixpkgs.follows = "nixpkgs";
    megzari_com.inputs.flake-utils.follows = "flake-utils";
    megzari_com.inputs.devshell.inputs.flake-utils.follows = "flake-utils";
    megzari_com.inputs.nuenv.inputs.rust-overlay.follows = "rust-overlay";

    # prebuilt nix-index database, weekly - `, <cmd>` and `nix-locate` work
    # without an hour-long local index run
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    # rust
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";

    # Logitech HID++ control for the MX Master 3S. Upstream owns the NixOS
    # module that installs the package, its udev rules and the agent unit, so
    # the module is the reason for the input - `pkgs.openlogi` in nixpkgs is
    # a few releases behind what these settings are written against. Both
    # follows are load-bearing: it builds with rust-overlay's stable.latest
    # because nixpkgs' rustc lags the workspace's rust-version, and its own
    # nixpkgs would otherwise be a second evaluation of the same tree.
    openlogi.url = "github:AprilNEA/OpenLogi";
    openlogi.inputs.nixpkgs.follows = "nixpkgs";
    openlogi.inputs.rust-overlay.follows = "rust-overlay";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-hardware,
      home-manager,
      agenix,
      nixinate,
      megzari_com,
      rust-overlay,
      nix-index-database,
      llm-agents,
      openlogi,
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
            llm-agents
            openlogi
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
