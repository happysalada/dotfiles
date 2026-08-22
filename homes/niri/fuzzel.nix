# fuzzel is the wayland-native rofi replacement: same dmenu-style pipe
# interface (`fuzzel --dmenu`), same "type to filter, enter to run", but it
# speaks layer-shell so it renders correctly on niri. `Mod+D` opens it as an
# app launcher; `Mod+V` pipes clipboard history through `--dmenu`.
{ pkgs }:
{
  enable = true;

  settings = {
    main = {
      font = "FiraCode Nerd Font:size=13";
      terminal = "${pkgs.ghostty}/bin/ghostty -e";
      layer = "overlay";
      prompt = "'> '";
      width = 45;
      lines = 12;
      horizontal-pad = 20;
      vertical-pad = 14;
      inner-pad = 6;
      # fuzzy matching, so "fx" finds "Firefox"
      match-mode = "fuzzy";
      # most-recently-used ordering, which is what makes a launcher feel fast
      sort-result = "yes";
      show-actions = "yes";
      icon-theme = "Adwaita";
    };

    # carbon, same palette as ghostty/helix. fuzzel wants RRGGBBAA.
    colors = {
      background = "000000f2";
      text = "c8ccd4ff";
      match = "3ddbd9ff";
      selection = "161616ff";
      selection-text = "f4f4f4ff";
      selection-match = "3ddbd9ff";
      border = "262626ff";
    };

    border = {
      width = 1;
      radius = 6;
    };

    dmenu = {
      # clipboard entries are one line each; don't let a long entry wrap
      exit-immediately-if-empty = "yes";
    };
  };
}
