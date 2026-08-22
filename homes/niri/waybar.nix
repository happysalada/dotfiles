# Status bar for the niri session.
#
# waybar speaks layer-shell and reserves its own exclusive zone, which is why
# niri's `struts` block is left empty - the bar tells the compositor how much
# room it needs.
{ pkgs }:
{
  enable = true;

  settings.main = {
    layer = "top";
    position = "top";
    height = 30;
    spacing = 6;

    modules-left = [
      "niri/workspaces"
      "niri/window"
    ];
    modules-center = [ "clock" ];
    modules-right = [
      "custom/dgpu"
      "cpu"
      "temperature"
      "pulseaudio"
      "backlight"
      "network"
      "bluetooth"
      "battery"
      "tray"
    ];

    "niri/workspaces" = {
      format = "{index}";
      # niri workspaces are a vertical stack per output and are dynamic, so
      # this list grows and shrinks as you use them
      on-click = "activate";
    };

    "niri/window" = {
      format = "{}";
      max-length = 60;
      separate-outputs = true;
    };

    clock = {
      format = "{:%a %d %b  %H:%M}";
      tooltip-format = "<tt><small>{calendar}</small></tt>";
      calendar = {
        mode = "month";
        format = {
          today = "<span color='#3ddbd9'><b>{}</b></span>";
        };
      };
    };

    # This machine runs the 4090 in PRIME offload with fine-grained runtime D3,
    # so the dGPU should read `suspended` almost all the time. Seeing it stuck
    # on `active` while nothing is rendering means something is holding it awake
    # and the battery is paying for it.
    "custom/dgpu" = {
      exec = pkgs.writeShellScript "waybar-dgpu" ''
        state=$(cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status 2>/dev/null || echo unknown)
        case "$state" in
          suspended) printf '{"text":"󰤄 dGPU","class":"asleep","tooltip":"RTX 4090: suspended (D3cold)"}\n' ;;
          active)    printf '{"text":"󱤓 dGPU","class":"awake","tooltip":"RTX 4090: active - drawing power"}\n' ;;
          *)         printf '{"text":"󰤮 dGPU","class":"unknown","tooltip":"RTX 4090: %s"}\n' "$state" ;;
        esac
      '';
      return-type = "json";
      interval = 10;
      on-click = "${pkgs.ghostty}/bin/ghostty -e ${pkgs.nvtopPackages.full}/bin/nvtop";
    };

    cpu = {
      format = "󰻠 {usage}%";
      interval = 5;
      # bottom, not btop: it is already in basic_cli_set.nix and nushell.nix
      # carries its completions, so btop was a second process viewer earning
      # its keep only from this one click.
      on-click = "${pkgs.ghostty}/bin/ghostty -e ${pkgs.bottom}/bin/btm";
    };

    temperature = {
      critical-threshold = 85;
      format = "{icon} {temperatureC}°C";
      format-icons = [
        ""
        ""
        ""
      ];
      interval = 5;
    };

    pulseaudio = {
      format = "{icon} {volume}%";
      format-muted = "󰝟 muted";
      format-icons.default = [
        "󰕿"
        "󰖀"
        "󰕾"
      ];
      on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
      scroll-step = 5;
    };

    backlight = {
      format = "󰃞 {percent}%";
      scroll-step = 5;
    };

    network = {
      format-wifi = "󰖩 {essid}";
      format-ethernet = "󰈀 wired";
      format-disconnected = "󰖪 offline";
      tooltip-format = "{ifname}: {ipaddr}/{cidr}";
      on-click = "${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
    };

    bluetooth = {
      format = "󰂯";
      format-disabled = "";
      format-connected = "󰂱 {num_connections}";
      tooltip-format-connected = "{device_enumerate}";
      on-click = "${pkgs.blueman}/bin/blueman-manager";
    };

    # asusd stops charging at 80%, so "full" here means 80 and the battery will
    # normally sit just under it while plugged in
    battery = {
      states = {
        warning = 25;
        critical = 10;
      };
      format = "{icon} {capacity}%";
      format-charging = "󰂄 {capacity}%";
      format-plugged = "󰚥 {capacity}%";
      format-icons = [
        "󰁺"
        "󰁻"
        "󰁽"
        "󰁿"
        "󰂁"
        "󰂂"
        "󰁹"
      ];
      tooltip-format = "{timeTo}  ({power}W)";
    };

    tray = {
      spacing = 10;
      icon-size = 18;
    };
  };

  # carbon: black bar, grey text, cyan accents - same palette as ghostty,
  # helix and fuzzel
  style = ''
    * {
      font-family: "FiraCode Nerd Font";
      font-size: 13px;
      border: none;
      border-radius: 0;
      min-height: 0;
    }

    window#waybar {
      background-color: #000000;
      color: #c8ccd4;
      border-bottom: 1px solid #262626;
    }

    #workspaces button {
      padding: 0 8px;
      color: #525252;
      background: transparent;
    }

    #workspaces button.focused,
    #workspaces button.active {
      color: #000000;
      background-color: #3ddbd9;
    }

    #workspaces button.urgent {
      color: #000000;
      background-color: #ee5396;
    }

    #window {
      padding: 0 10px;
      color: #8d8d8d;
    }

    #clock,
    #cpu,
    #temperature,
    #pulseaudio,
    #backlight,
    #network,
    #bluetooth,
    #battery,
    #custom-dgpu,
    #tray {
      padding: 0 10px;
    }

    #clock {
      color: #f4f4f4;
      font-weight: bold;
    }

    /* the dGPU indicator earns its place by being loud when it matters */
    #custom-dgpu.asleep  { color: #525252; }
    #custom-dgpu.awake   { color: #fedc69; }
    #custom-dgpu.unknown { color: #ee5396; }

    #temperature.critical,
    #battery.critical {
      color: #000000;
      background-color: #ee5396;
    }

    #battery.warning {
      color: #fedc69;
    }

    #battery.charging,
    #battery.plugged {
      color: #42be65;
    }

    #network.disconnected {
      color: #ee5396;
    }

    tooltip {
      background-color: #000000;
      border: 1px solid #262626;
    }

    tooltip label {
      color: #c8ccd4;
    }
  '';
}
