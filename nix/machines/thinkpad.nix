{ config, pkgs, ... }:

{
  home = {
    packages = with pkgs; [
      xclip
      btop
      rnix-lsp
      nixpkgs-fmt
    ] ++
    (import ../packages/basic_cli_set.nix { inherit pkgs; }) ++
    (import ../packages/fonts.nix { inherit pkgs; }) ++
    (import ../packages/dev/rust.nix { inherit pkgs; });
    sessionVariables = {
      EDITOR = "hx";
    };
  };
  fonts.fontconfig.enable = true;
  targets.genericLinux.enable = true;
  news.display = "silent";
  programs = import ../homes/common.nix { inherit pkgs; } //
    import ../homes/linux.nix { inherit pkgs; } //
    import ./overrides;
}
