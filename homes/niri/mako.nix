# Notification daemon for the niri session. home-manager registers it as a
# D-Bus activated service, so it starts on the first notification and only when
# nothing else owns org.freedesktop.Notifications - idle under GNOME otherwise.
{ pkgs }:
{
  enable = true;

  settings = {
    font = "FiraCode Nerd Font 11";
    background-color = "#000000f2";
    text-color = "#c8ccd4";
    border-color = "#262626";
    progress-color = "over #3ddbd9";
    border-size = 1;
    border-radius = 6;
    padding = "12";
    margin = "10";
    width = 380;
    height = 160;
    default-timeout = 6000;
    ignore-timeout = false;
    anchor = "top-right";
    layer = "overlay";
    max-visible = 5;
    icons = true;
    max-icon-size = 48;

    # urgency=critical (low battery, failed units): stay until dismissed, coloured border
    "urgency=critical" = {
      border-color = "#ee5396";
      default-timeout = 0;
    };

    "urgency=low" = {
      text-color = "#8d8d8d";
      default-timeout = 3000;
    };
  };
}
