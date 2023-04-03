{ config, pkgs }:
{
  alacritty = import ./programs/alacritty.nix;
  fish = import ./programs/fish.nix;
  ssh = import ./programs/ssh.nix;
  helix = import ./programs/helix.nix;

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
        unbind = [{ "Ctrl" = "b"; }];
      };
    };
  };

  starship = {
    enable = true;
    enableFishIntegration = true;
    enableNushellIntegration = true;
    settings = {
      add_newline = false;
      package.disabled = true;
    };
  };

  broot = {
    enable = true;
    enableFishIntegration = true;
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
    enableFishIntegration = true;
    enableNushellIntegration = true;
  };

  atuin = {
    enable = true;
    enableFishIntegration = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;
    settings = {
      auto_sync = false;
      search_mode = "skim";
      show_preview = true;
    };
  };

  gitui.enable = true;

  # TODO check that the config and env are usable
  # conpilation fails on darwin
  nushell = {
    enable = true;
    configFile.text = ''
      let-env config = {
        edit_mode: vi
        show_banner: false
      }

      alias nixgc = nix store gc -v
      alias snixgc = sudo nix-collect-garbage -d
      alias nixroots = nix-store --gc --print-roots
      # git
      alias gps = git push --set-upstream origin HEAD
      alias gl = git log --pretty=oneline --abbrev-commit
      alias gbd = git branch --delete --force
      alias gc = git checkout
      alias gpp = git pull --prune
      alias gsi = git stash --include-untracked
      alias gsp = git stash pop
      alias gsa = git stage --all
      alias gfu = git fetch upstream
      alias gmu = git merge upstream/master master
      alias gb = git branch
      alias gpf = git push --force
      alias gu = git reset --soft HEAD~1
      alias grh = git reset --hard
      # misc
      alias l = (ls -a | select name size | sort-by size | reverse)
      alias b = broot -ghi
    '';

    envFile.text = ''
      let-env PATH = ($env.PATH |
        prepend "/run/current-system/sw/bin" |
        prepend "/Users/raphael/.nix-profile/bin")
      '';
    # envFile.source = config.age.secrets.ENV_NU.path;
  };
}
