{
  pkgs,
  config,
  lib,
}:
{
  ssh = import ./programs/ssh.nix { inherit lib; };
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
    enable = true;
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
    # atuin's `init nu` emits its ctrl-r and up-arrow keybindings as two
    # separate `$env.config = ($env.config | upsert keybindings ...)`
    # statements, and the second silently discards the first - leaving ctrl-r
    # on nushell's builtin history_menu. Emitting only one statement avoids
    # the clobber entirely. Reproduced on stock nushell 0.115.0 + atuin
    # 18.19.0; this is upstream atuin, not home-manager.
    flags = [ "--disable-up-arrow" ];

    # daemon-fuzzy does its matching in the daemon. It also decouples history
    # writes from shell latency. home-manager sets up the systemd user
    # service + socket and flips settings.daemon.enabled for us.
    daemon.enable = true;
    enable = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;
    settings = {
      auto_sync = true;
      sync_frequency = "5m";
      sync_address = "https://atuin.megzari.com";
      # `skim` was removed upstream. atuin points you at daemon-fuzzy as the
      # closest equivalent; it needs the daemon (enabled below).
      search_mode = "daemon-fuzzy";
      show_preview = true;
      update_check = false;
      enter_accept = true;
    };
  };

  gitui.enable = true;

  yazi = import ./programs/yazi.nix { inherit pkgs; };

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
        # "pipx:OpenBB-finance/OpenBB#subdirectory=cli" = "latest";
      };
      settings = {
        experimental = true;
        # renamed upstream from the flat `pipx_uvx` key
        pipx.uvx = true;
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
      pinentry = pkgs.pinentry-gnome3;
      base_url = "https://vaultwarden.megzari.com";
    };
  };

}
