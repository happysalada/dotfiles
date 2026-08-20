{ pkgs }:
{
  enable = true;

  # ghostty ships its own shell integration; nushell isn't one of the shells it
  # can auto-inject into, so this is mostly here for the odd bash subshell.
  enableBashIntegration = true;

  installBatSyntax = true;

  settings = {
    font-family = "FiraCode Nerd Font";
    # 2560x1600 on an 18" panel. Bump/drop this if gnome ends up scaling.
    font-size = 14;
    font-thicken = true;

    # maximized, not fullscreen - keeps the gnome top bar and window controls
    maximize = true;
    fullscreen = false;

    theme = "carbon";
    background-opacity = 1.0;

    # matches the black background used in helix/zellij
    background = "#000000";

    cursor-style = "block";
    cursor-style-blink = false;

    # ghostty counts scrollback in bytes, not lines
    scrollback-limit = 100000000; # 100 MB

    window-padding-x = 8;
    window-padding-y = 8;
    window-inherit-font-size = true;

    # zellij handles multiplexing, so don't double up on confirmation dialogs
    confirm-close-surface = false;

    copy-on-select = "clipboard";
    mouse-hide-while-typing = true;

    # one process for all windows, so super+t spawning `ghostty` is instant
    gtk-single-instance = true;
    gtk-tabs-location = "top";

    keybind = [
      # zellij owns ctrl+ combos, keep terminal-level bindings on ctrl+shift
      "ctrl+shift+c=copy_to_clipboard"
      "ctrl+shift+v=paste_from_clipboard"
      "ctrl+shift+n=new_window"
      "ctrl+shift+equal=increase_font_size:1"
      "ctrl+shift+minus=decrease_font_size:1"
      "ctrl+shift+zero=reset_font_size"
    ];
  };

  themes = {
    # ported from the `carbon` helix theme in ./helix.nix so the editor and the
    # terminal agree on colours
    carbon = {
      background = "#000000";
      foreground = "#c8ccd4";
      cursor-color = "#3ddbd9";
      selection-background = "#393939";
      selection-foreground = "#c8ccd4";
      palette = [
        "0=#161616"
        "1=#ee5396"
        "2=#42be65"
        "3=#fedc69"
        "4=#78a9ff"
        "5=#be95ff"
        "6=#3ddbd9"
        "7=#c8ccd4"
        "8=#525252"
        "9=#ff7eb6"
        "10=#19b06a"
        "11=#fedc69"
        "12=#82cfff"
        "13=#ff7eb6"
        "14=#00dfdb"
        "15=#f4f4f4"
      ];
    };
  };
}
