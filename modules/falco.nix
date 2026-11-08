# Falco with the stock rules. Alerts land in the journal (`journalctl -u falco`)
# and falco-notify turns each one into a desktop toast, so a hit is seen without
# anyone reading the log.
{ pkgs, ... }:
let
  notifier = pkgs.writers.writeNu "falco-notify" ''
    # Follows falco's journal and toasts every alert line it prints.
    def main [] {
      $env.XDG_RUNTIME_DIR = $"/run/user/(^id -u | str trim)"
      $env.DBUS_SESSION_BUS_ADDRESS = $"unix:path=($env.XDG_RUNTIME_DIR)/bus"

      ^journalctl -u falco -f -n 0 -o cat
      | lines
      | parse --regex '^[\d:.]+: (?<priority>Warning|Error|Critical|Alert|Emergency) (?<text>.*)$'
      | each {|alert| toast $alert }
      null
    }

    # Falco prints "<summary> | <fields>"; the fields name the process and file.
    def toast [alert: record] {
      let parts = $alert.text | split row " | "
      let urgency = if $alert.priority == "Warning" { "normal" } else { "critical" }
      try {
        ^notify-send -a falco -u $urgency $"falco: ($parts.0)" ($parts | get 1? | default "" | str substring 0..<400)
      }
    }
  '';
in
{
  services.falco = {
    enable = true;
    # Below Warning is baseline chatter, not something to be told about.
    settings.priority = "warning";

    rules."50-local" = [
      {
        # swaylock reads its PAM stack on every lock, userborn /etc/shadow on every
        # switch. The wrapper's process name is truncated to 15 characters.
        macro = "user_known_read_sensitive_files_activities";
        condition = ''proc.name in (".swaylock-wrapp", userborn)'';
        override.condition = "replace";
      }
    ];
  };

  systemd.services.falco-notify = {
    description = "Desktop notification for each Falco alert";
    wantedBy = [ "multi-user.target" ];
    after = [ "falco.service" ];
    path = [ pkgs.systemd pkgs.libnotify ];
    serviceConfig = {
      ExecStart = notifier;
      User = "yt";
      SupplementaryGroups = [ "systemd-journal" ];
      Restart = "always";
      RestartSec = "10s";
    };
  };
}
