{ pkgs, ... }:
{
  programs.zed-editor = {
    enable = true;

    # Installed on first start rather than at build time. The nix extension is
    # the one thing Zed does not ship for this repo.
    extensions = [ "nix" ];

    # Zed's nix extension finds its server on PATH, and nothing named `nixd`
    # reaches PATH otherwise: helix.nix binds `${nixd}/bin/nixd` by store path,
    # so it never needed one. nixfmt, which the extension formats through, is
    # already in packages/dev/nix.nix.
    extraPackages = [ pkgs.nixd ];

    # The same `programs.mcp.servers` that homes/programs/ai-mcp.nix and
    # crw.nix declare and codex/opencode read back, handed to Zed as its
    # context_servers - one list, no second copy to keep in sync.
    enableMcpIntegration = true;

    # Merged into ~/.config/zed/settings.json on activation rather than linked
    # over it: mutableUserSettings defaults to true, so the editor keeps
    # writing that file. The merge is `$dynamic * $static`, so the keys below
    # are re-applied on every switch and everything else in the file is left
    # as the editor had it.
    #
    # `carbon`, the helix and ghostty theme, has no Zed equivalent, so no theme
    # is named here and Zed keeps its own default until one is chosen.
    userSettings = {
      buffer_font_family = "FiraCode Nerd Font";
      buffer_font_size = 16;
      ui_font_size = 16;

      # Helix mode, to match `EDITOR = "hx"`. Zed's own `helix_mode` implies
      # `vim_mode`, so declaring both would be redundant. Upstream still calls
      # it work in progress: not every Helix binding is implemented.
      helix_mode = true;

      # What homes/programs/vscodium.nix does with files.autoSave. Zed's other
      # options are "off", "on_window_change" and after_delay.
      autosave = "on_focus_change";

      # Both default to true.
      telemetry = {
        diagnostics = false;
        metrics = false;
      };

      # rust-analyzer itself needs nothing here: packages/dev/rust-toolchain.nix
      # puts the toolchain's own copy on PATH, built from the same tree as the
      # rustc. This only moves its diagnostics onto clippy, which is the loop
      # the repo's Rust notes and vscodium both use.
      lsp."rust-analyzer".initialization_options.check.command = "clippy";
    };
  };
}
