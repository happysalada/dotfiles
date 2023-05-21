{ pkgs, config, lib }:
{
  alacritty = import ./programs/alacritty.nix;
  fish = import ./programs/fish.nix;
  ssh = import ./programs/ssh.nix;
  helix = import ./programs/helix.nix { inherit pkgs; };
  nushell = import ./programs/nushell.nix { inherit pkgs config lib; };
  # neovim = import ./programs/neovim.nix { inherit pkgs; };

  direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableNushellIntegration = true;
  };

  zellij = {
    enable = true;
    settings = {
      pane_frames = false;
      keybinds = {
        unbind = {
          _args = [ "Ctrl b" "Ctrl n" "Ctrl p" "Ctrl g" "Ctrl h" "Ctrl o" "Ctrl q" ];
        };
      };
    };
  };

  starship = {
    enable = true;
    # enableFishIntegration = true;
    enableNushellIntegration = true;
    settings = {
      add_newline = false;
      package.disabled = true;
    };
  };

  broot = {
    enable = true;
    # enableFishIntegration = true;
    settings.verbs = [
      {
        invocation = "edit";
        shortcut = "e";
        execution = "$EDITOR {file}";
      }
      {
        invocation = "create {subpath}";
        execution = "$EDITOR {directory}/{subpath}";
      }
    ];
  };

  zoxide = {
    enable = true;
    # enableFishIntegration = true;
    enableNushellIntegration = true;
  };

  atuin = {
    enable = true;
    # enableFishIntegration = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;
    settings = {
      auto_sync = true;
      sync_frequency = "5m";
      sync_address = "https://atuin.sassy.technology";
      search_mode = "skim";
      show_preview = true;
    };
  };

  gitui.enable = true;
}
