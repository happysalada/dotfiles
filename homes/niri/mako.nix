# Notification daemon for the niri session. home-manager registers this as a
# D-Bus activated service rather than a systemd unit, so it starts on the first
# notification and only when nothing else owns org.freedesktop.Notifications -
# which keeps it out of the way under GNOME.
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

    # urgency=critical notifications (low battery, failed units) stay until
    # dismissed and get a coloured border
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
