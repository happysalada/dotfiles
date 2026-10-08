# Cancels a Handy recording that has held the microphone for ten minutes.
#
# Handy cannot do this itself: the only duration-shaped setting in 0.9.8 is
# `model_unload_timeout`, and the feature request for a recording limit
# (cjpais/Handy#1416) has never been answered. That matters because
# `shortcut_activation` is `hold_or_toggle`, where a press shorter than
# `hold_threshold_ms` (300) *locks* the recording on until the next press - so a
# tap nobody follows up records until something else stops it, which is how a
# session ran for an hour here.
#
# `handy --cancel` is the only external hook Handy offers, the same path as the
# cancel shortcut (src-tauri/src/lib.rs forwards it over the single-instance
# DBus name to cancel_current_operation), and it is a no-op when nothing is
# recording - so arming it too eagerly costs at most the recording in progress.
#
# Nothing here asks Handy what it is doing: it watches PipeWire for Handy's
# capture stream, which with `always_on_microphone` off exists only while
# recording. That is also the stream that stayed open, spinning a core, when the
# app got stuck after an ALSA overrun. Always-on would invert the meaning (the
# stream is open permanently), so the setting is re-read each pass and the timer
# stands down while it is on.
#
# Watch it work with `handy-recording-timeout --limit 30sec` in a terminal, or
# read it afterwards with `journalctl --user -u handy-recording-timeout`.
{ pkgs, ... }:
let
  # writeNuBin, not writeNu: the latter writes the script at the store root,
  # where there is no bin/ to put on ExecStart.
  watch = pkgs.writers.writeNuBin "handy-recording-timeout" ''
    const POLL = 15sec
    # Long enough for the stream to close before the timer can re-arm against it.
    const SETTLE = 30sec

    # Is a Handy capture stream open right now?
    def capturing [dump: list] {
      $dump | any {|node|
        let props = ($node.info?.props? | default {})
        let named = ((($props."application.name"? | default "") + ($props."node.name"? | default "")) | str lowercase)
        (($props."media.class"? | default "") == "Stream/Input/Audio") and ($named | str contains "handy")
      }
    }

    # pw-dump dies with the pipewire it talks to; a pass that cannot see the
    # graph is not a recording in progress.
    def capturing-now [] {
      try { capturing (^${pkgs.pipewire}/bin/pw-dump | from json) } catch { false }
    }

    def always-on [] {
      try {
        let path = (
          ($env.XDG_DATA_HOME? | default ($nu.home-dir | path join ".local/share"))
          | path join "com.pais.handy/settings_store.json"
        )
        open $path | get --optional settings | get --optional always_on_microphone | default false
      } catch {
        # Unreadable means unknown, and the timeout is the point: arm anyway.
        false
      }
    }

    def main [--limit: duration = 10min] {
      # `mut x = null` is typed `nothing` in nu, and refuses a datetime later,
      # so the state is a pair: when this recording started, and whether one is
      # being timed at all.
      mut started = (date now)
      mut recording = false
      mut stood_down = false
      loop {
        if (always-on) {
          if not $stood_down {
            print "always_on_microphone is on; the microphone is open whether or not a recording is, standing down"
            $stood_down = true
          }
          $recording = false
        } else if (capturing-now) {
          $stood_down = false
          if not $recording {
            $started = (date now)
            $recording = true
          }
          let held = ((date now) - $started)
          if $held >= $limit {
            print $"cancelling a recording that has held the microphone for ($held)"
            let cancel = (^${pkgs.handy}/bin/handy --cancel | complete)
            if $cancel.exit_code != 0 {
              print $"handy --cancel exited ($cancel.exit_code): ($cancel.stderr | str trim)"
            }
            $recording = false
            sleep $SETTLE
            continue
          }
        } else {
          $stood_down = false
          $recording = false
        }
        sleep $POLL
      }
    }
  '';
in
{
  systemd.user.services.handy-recording-timeout = {
    Unit = {
      Description = "cancel a Handy recording that has held the microphone for ten minutes";

      # Handy's own autostart unit hangs off the same target, so the two start
      # and stop together - however Handy was started.
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${watch}/bin/handy-recording-timeout";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
