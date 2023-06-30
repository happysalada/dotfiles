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
      default_shell = "nu";
      default_layout = "compact";
      ui = {
          pane_frames = {
              rounded_corners = true;
              hide_session_name = true;
          };
      };
      keybinds = {
        unbind = {
          _args = [ "Ctrl b" "Ctrl n" "Ctrl p" "Ctrl g" "Ctrl h" "Ctrl o" "Ctrl q" ];
        };
      };
      theme = "black";
      themes = {
          black = {
              fg = [169 177 214];
              bg = [0 0 0];
              black = [0 0 0];
              red = [249 51 87];
              green = [158 206 106];
              yellow = [224 175 104];
              blue = [122 162 247];
              magenta = [187 154 247];
              cyan = [42 195 222];
              white = [192 202 245];
              orange = [255 158 100];
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
