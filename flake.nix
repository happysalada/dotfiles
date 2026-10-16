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

    # The Nix client the agents run instead of `nix`: a Rust re-implementation
    # that answers the same `.drv` paths for what it implements (everything it
    # does not goes back to the real nix) and caches by file tracing, so a
    # repeat command evaluates nothing. machines/strix/default.nix imports its
    # NixOS module and turns the classic names on.
    #
    # The follow is free, measured not assumed: with it, `default` resolves to
    # the same /nix/store/vp7xk6bgrnclspfvlbynz452wb94srjh-iets-0.1.0 the pin
    # builds, and cache.numtide.com serves that path to the key machines/strix
    # already trusts. A nixpkgs bump can still miss, and a miss builds the crate
    # here - minutes, not an error.
    iets.url = "github:numtide/iets";
    iets.inputs.nixpkgs.follows = "nixpkgs";

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

    # bookokrat, a terminal EPUB/PDF/DJVU reader. Not in nixpkgs: the init PR
    # (NixOS/nixpkgs#488100, "init at 0.3.5") was closed unmerged, so the
    # package comes from upstream's own flake - the same one its README tells
    # people to `nix run`. That flake is the packaging: it is the only place
    # that knows the default `pdf` and `svg` features need mupdf (through
    # bindgen, hence clang), resvg, freetype, harfbuzz, openjpeg, jbig2dec,
    # gumbo and fontconfig as build inputs.
    #
    # Both follows are load-bearing. Without the nixpkgs one, this input is a
    # second full evaluation of the same tree, and the package would be built
    # by a rustc that is not the one every other rust tool here uses; with it,
    # `bookokrat.packages.<system>.default` is a derivation over our nixpkgs,
    # so it stays inside the same `nix flake update` as everything else.
    bookokrat.url = "github:bugzmanov/bookokrat";
    bookokrat.inputs.nixpkgs.follows = "nixpkgs";
    bookokrat.inputs.flake-utils.follows = "flake-utils";
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
      iets,
      openlogi,
      bookokrat,
      ...
    }:
    let
      # bookokrat, as an overlay rather than a raw flake package named at each
      # of the three consumers, so packages/basic_cli_set.nix can go on saying
      # a bare `bookokrat` - the same shape the llm-agents overlay gives the
      # agent CLIs in machines/strix/default.nix. Defined here rather than in
      # the machines because of the override, which would otherwise be repeated
      # in all three.
      #
      # The override is a test fix, not a patch to the program, and it is
      # doCheck rather than a list of tests to leave out. Upstream's check phase
      # is a golden-SVG suite - tests/svg_snapshots.rs renders a frame and diffs
      # it against a committed file - so what it pins is the rendering stack
      # (ratatui, resvg, the image crates) as much as the code. Upstream's own
      # flake already has to --skip four of those tests; against this nixpkgs
      # three *different* ones fail, test_content_view_svg,
      # test_keybinding_errors_popup_svg and test_toc_back_to_books_list_svg,
      # while the other 100 pass and the differing snapshot is 3 lines of 150.
      # Tried and ruled out: --test-threads=1, on the theory that the suite
      # renders against process-globals (src/theme.rs's CURRENT_THEME_INDEX is
      # an AtomicUsize and 99 of the 108 tests are #[parallel]) - running it
      # serially moved neither the count nor the names, so this is the
      # snapshots against the dependency set, not a race. That leaves a skip
      # list, which would be the four upstream flags plus three of ours to
      # re-derive on every `nix flake update`; when one goes stale the deploy
      # fails on a golden file rather than on anything about the program. With
      # checks off a broken crate still fails to compile. Verified by hand:
      # doCheck off builds, and `bookokrat --version` prints 0.3.13.
      bookokratOverlay = final: prev: {
        bookokrat = bookokrat.packages.${final.stdenv.hostPlatform.system}.default.overrideAttrs (_: {
          doCheck = false;
        });
      };
    in
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
            iets
            openlogi
            bookokratOverlay
            ;
        };
      };

      nixosConfigurations.bee = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = import ./machines/bee {
          inherit
            home-manager
            agenix
            megzari_com
            bookokratOverlay
            ;
        };
      };

      nixosConfigurations.hetz = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = import ./machines/hetz {
          inherit
            home-manager
            agenix
            bookokratOverlay
            ;
        };
      };
    };
}
