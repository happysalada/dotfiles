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
    # Nothing expires, by default or on request: a toast that vanished while you
    # were looking at another pane is one you never saw, and 0 is mako's "no
    # timeout". ignore-timeout is what applies that to the expire time an
    # application asks for as well, so a plain `notify-send -t 3000` sticks too
    # and only a click or Mod+Shift+N clears it.
    default-timeout = 0;
    ignore-timeout = true;
    anchor = "top-right";
    layer = "overlay";
    max-visible = 5;
    icons = true;
    max-icon-size = 48;

    # urgency=critical (low battery, failed units): coloured border. No timeout
    # of its own any more - the default above is already "until dismissed".
    "urgency=critical" = {
      border-color = "#ee5396";
    };

    "urgency=low" = {
      text-color = "#8d8d8d";
    };
  };
}
