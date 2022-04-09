{ pkgs }:
{
  alacritty = import ./programs/alacritty.nix;
  git = import ./programs/git.nix { inherit pkgs; };
  fish = import ./programs/fish.nix;
  ssh = import ./programs/ssh.nix;
  helix = import ./programs/helix.nix;

  direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  zellij = {
    enable = true;
    settings = {
      pane_frames = false;
      keybinds = {
        unbind = [{"Ctrl" = "b";}];
      };
    };
  };

  starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = false;
      package.disabled = true;
    };
  };

  nix-index = {
    enable = true;
    enableFishIntegration = true;
  };

  broot = {
    enable = true;
    enableFishIntegration = true;
    verbs = [
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
    enableFishIntegration = true;
  };

  skim = {
    enable = true;
    enableFishIntegration = true;
  };

  gitui = {
    enable = true;
  };
}
