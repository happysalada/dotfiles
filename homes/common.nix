{
  pkgs,
  config,
  lib,
}:
{
  alacritty = import ./programs/alacritty.nix;
  ssh = import ./programs/ssh.nix;
  helix = import ./programs/helix.nix { inherit pkgs; };
  nushell = import ./programs/nushell.nix { inherit pkgs config lib; };
  neovim = import ./programs/neovim.nix { inherit pkgs; };

  home-manager = {
    enable = true;
  };

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
          hide_session_name = true;
        };
      };
      keybinds = {
        unbind = {
          _args = [
            "Ctrl n"
            "Ctrl p"
            "Ctrl g"
            "Ctrl h"
            "Ctrl q"
          ];
        };
        normal = {
          unbind = {
            _args = [ "Ctrl b" ];
          };
        };
      };
      theme = "black";
      themes = {
        black = {
          fg = [
            169
            177
            214
          ];
          bg = [
            49
            46
            129
          ];
          black = [
            0
            0
            0
          ];
          red = [
            249
            51
            87
          ];
          green = [
            5
            150
            105
          ];
          yellow = [
            224
            175
            104
          ];
          blue = [
            122
            162
            247
          ];
          magenta = [
            187
            154
            247
          ];
          cyan = [
            42
            195
            222
          ];
          white = [
            192
            202
            245
          ];
          orange = [
            255
            158
            100
          ];
        };
      };
    };
  };

  starship = {
    enable = true;
    enableNushellIntegration = true;
    settings = {
      add_newline = false;
      package.disabled = true;
    };
  };

  broot = {
    enable = false; # compilation failure on darwin
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
    enableNushellIntegration = true;
  };

  atuin = {
    enable = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;
    settings = {
      auto_sync = true;
      sync_frequency = "5m";
      sync_address = "https://atuin.megzari.com";
      search_mode = "skim";
      show_preview = true;
      update_check = false;
      enter_accept = true;
    };
  };

  gitui.enable = true;

  yazi = {
    enable = true;
    enableNushellIntegration = true;
    settings = {
      manager = {
        show_hidden = true;
        show_symlink = true;
        sort_dir_first = true;
        sort_by = "size";
        sort_reverse = true;
        linemode = "size";
      };
    };
  };

  jujutsu = {
    enable = true;
    settings = {
      email = "raphael@megzari.com";
      name = "happysalada";
    };
  };

  # great tool to download videos
  yt-dlp.enable = true;

  carapace = {
    enable = true;
    enableNushellIntegration = true;
  };

  freetube = {
    # enable = true;
  };

  neomutt = {
    enable = true;
    vimKeys = true;
    # sidebar.enable = true;
  };
  vdirsyncer.enable = true; # contacts + calendar sync
  mbsync.enable = true; # main sync

  keychain = {
    enable = true;
    enableNushellIntegration = true;
    keys = [ "id_ed25519" ];
  };

  mise = {
    enable = true;
    globalConfig = {
      tools = {
        "ubi:tigerbeetle/tigerbeetle" = "latest";
      };
      settings = {
        experimental = true;
        pipx_uvx = true;
      };
    };
  };

  go.enable = true; # used mostly to install other things

  gpg.enable = true;

  # bitwarden cli client
  rbw = {
    enable = true;
    settings = {
      email = "raphael@megzari.com";
      lock_timeout = 120;
      pinentry = if pkgs.stdenv.isDarwin then pkgs.pinentry_mac else pkgs.pinentry;
      base_url = "https://vaultwarden.megzari.com";
    };
  };
}
