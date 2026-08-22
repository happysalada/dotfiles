# The niri session, as a home-manager module.
#
# It sits *alongside* GNOME rather than replacing it: GDM offers both, and
# nothing here runs inside the GNOME session. That separation is the reason
# waybar/swayidle/cliphist below are pinned to `niri.service` instead of the
# usual `graphical-session.target` - GNOME reaches that target too, and waybar
# would otherwise start (and immediately fail, since mutter has no layer-shell)
# on every GNOME login.
#
# mako needs no such treatment: home-manager wires it up as a D-Bus activated
# service, so it only ever starts when something asks for a notification and
# nothing else already owns org.freedesktop.Notifications. Under GNOME,
# gnome-shell owns that name and mako stays asleep.
{
  pkgs,
  config,
  lib,
  ...
}:
{
  home.packages = with pkgs; [
    # screenshot/annotate pipeline; niri's own `screenshot` action covers the
    # common case, these are for scripting and for `grim -g "$(slurp)"`
    grim
    slurp
    swappy

    # media keys in the niri config call these
    brightnessctl
    playerctl
    wireplumber # wpctl

    # X11 shim - niri from nixpkgs is built without built-in XWayland
    xwayland-satellite

    # authentication dialogs (gparted, gnome-disks, ...)
    polkit_gnome

    # what the GNOME session gives you for free and niri does not
    networkmanagerapplet # nm-applet, for the tray
    blueman # bluetooth tray applet
    pavucontrol # audio device picker
    wdisplays # arrange monitors when you dock

    adwaita-icon-theme
  ];

  # Without an explicit cursor theme, wayland clients fall back to a tiny X11
  # cursor under niri. This sets it for GTK, XWayland and the compositor at once.
  home.pointerCursor = {
    enable = true;
    package = pkgs.adwaita-icon-theme;
    name = "Adwaita";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  # niri hot-reloads this file on save, so most tweaks need no rebuild - but
  # the file is a read-only store symlink, so edit it here and `switch`.
  xdg.configFile."niri/config.kdl".text = import ./config.kdl.nix { inherit pkgs; };

  # ---------------------------------------------------------------------
  # launcher (the rofi replacement)
  # ---------------------------------------------------------------------
  programs.fuzzel = import ./fuzzel.nix { inherit pkgs; };

  # ---------------------------------------------------------------------
  # bar
  # ---------------------------------------------------------------------
  programs.waybar = import ./waybar.nix { inherit pkgs; } // {
    systemd = {
      enable = true;
      # see the header comment - not graphical-session.target
      targets = [ "niri.service" ];
    };
  };

  # ---------------------------------------------------------------------
  # notifications (D-Bus activated, see header)
  # ---------------------------------------------------------------------
  services.mako = import ./mako.nix { inherit pkgs; };

  # ---------------------------------------------------------------------
  # lock screen
  #
  # NOTE: swaylock authenticates through PAM, which means it needs
  # `security.pam.services.swaylock = { };` at the NixOS level. Without it the
  # lock screen accepts no password at all and you have to switch VTs.
  # ---------------------------------------------------------------------
  programs.swaylock = {
    enable = true;
    settings = {
      color = "000000";
      bs-hl-color = "ee5396";
      key-hl-color = "3ddbd9";
      inside-color = "00000000";
      inside-clear-color = "00000000";
      inside-ver-color = "00000000";
      inside-wrong-color = "00000000";
      ring-color = "262626";
      ring-clear-color = "fedc69";
      ring-ver-color = "78a9ff";
      ring-wrong-color = "ee5396";
      line-color = "00000000";
      line-clear-color = "00000000";
      line-ver-color = "00000000";
      line-wrong-color = "00000000";
      separator-color = "00000000";
      text-color = "c8ccd4";
      indicator-radius = 90;
      indicator-thickness = 6;
      # don't leak window contents behind the lock indicator
      ignore-empty-password = true;
      show-failed-attempts = true;
    };
  };

  # ---------------------------------------------------------------------
  # idle: dim -> lock -> screen off -> suspend
  #
  # The timeouts assume you are on AC as often as not; they are deliberately
  # conservative because the display is the biggest draw on this machine.
  # ---------------------------------------------------------------------
  services.swayidle = {
    enable = true;
    systemdTargets = [ "niri.service" ];
    events = {
      # lock before suspending, so resuming always lands on the lock screen
      before-sleep = "${lib.getExe pkgs.swaylock} -f";
      # `loginctl lock-session` routes here
      lock = "${lib.getExe pkgs.swaylock} -f";
    };
    timeouts = [
      {
        timeout = 300; # 5 min - dim, and let a keypress undo it
        command = "${lib.getExe pkgs.brightnessctl} -s set 10%";
        resumeCommand = "${lib.getExe pkgs.brightnessctl} -r";
      }
      {
        timeout = 600; # 10 min - lock
        command = "${lib.getExe pkgs.swaylock} -f";
      }
      {
        timeout = 660; # 11 min - screen off (locked one minute earlier)
        command = "${pkgs.niri}/bin/niri msg action power-off-monitors";
      }
      {
        timeout = 1800; # 30 min - suspend
        command = "${pkgs.systemd}/bin/systemctl suspend";
      }
    ];
  };

  # ---------------------------------------------------------------------
  # clipboard history, bound to Mod+V through fuzzel
  # ---------------------------------------------------------------------
  services.cliphist = {
    enable = true;
    systemdTargets = [ "niri.service" ];
    allowImages = true;
  };
}
