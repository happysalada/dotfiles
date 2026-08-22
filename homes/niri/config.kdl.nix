# niri's config is KDL, and niri validates it itself - so this is a text
# template rather than a nix attrset. `niri validate -c <file>` checks it, and
# niri also hot-reloads the file on save, so most edits need no rebuild.
{ pkgs }:
let
  terminal = "${pkgs.ghostty}/bin/ghostty";
  launcher = "${pkgs.fuzzel}/bin/fuzzel";
  brightness = "${pkgs.brightnessctl}/bin/brightnessctl";
  volume = "${pkgs.wireplumber}/bin/wpctl";
  player = "${pkgs.playerctl}/bin/playerctl";
  lock = "${pkgs.swaylock}/bin/swaylock";
  cliphist = "${pkgs.cliphist}/bin/cliphist";
  makoctl = "${pkgs.mako}/bin/makoctl";
  wlcopy = "${pkgs.wl-clipboard}/bin/wl-copy";
in
''
  // ---------------------------------------------------------------------
  // input
  // ---------------------------------------------------------------------
  input {
      keyboard {
          xkb {
              layout "us"
          }
          // Faster than both GNOME's and niri's defaults, for helix/vim-style
          // movement. repeat-delay is the hold time in ms before repeating
          // starts; repeat-rate is in Hz, so *bigger* is faster here - the
          // inverse of GNOME's repeat-interval. Kept in step with the dconf
          // values in machines/strix/default.nix (20ms interval = 50/s).
          repeat-delay 200
          repeat-rate 50
      }

      touchpad {
          tap
          dwt                       // disable-while-typing
          natural-scroll
          scroll-method "two-finger"
          accel-profile "adaptive"
          // macOS-style secondary click. `tap` + the default
          // tap-button-map already make a *two-finger tap* a right click;
          // clickfinger extends the same rule to physically pressing the
          // pad down (two fingers = right, three = middle) instead of
          // libinput's default bottom-right-corner "button areas".
          tap-button-map "left-right-middle"
          click-method "clickfinger"
      }

      mouse {
          accel-profile "flat"
      }

      // Focus follows the mouse only when the pointer actually moves onto a
      // window - scrolling the layout underneath the cursor does not steal
      // focus. Drop this block if you prefer click-to-focus.
      focus-follows-mouse max-scroll-amount="0%"
  }

  // ---------------------------------------------------------------------
  // output
  //
  // Internal panel is 2560x1600 on 380x240mm, i.e. 171 PPI. At scale 1.0
  // (what GNOME was doing) everything renders at ~56% of its intended
  // physical size. 1.5 gives a 1706x1066 logical desktop at ~84% of standard
  // apparent size, which still leaves a half-width column wide enough for
  // ~100 columns of ghostty. Going further costs window space: at 2.0 a
  // half-screen terminal drops under 80 columns, so bump
  // default-column-width too if you ever do. niri scales fractionally
  // natively; only XWayland clients go soft.
  // ---------------------------------------------------------------------
  output "eDP-1" {
      scale 1.5
      transform "normal"
      position x=0 y=0
      // mode is left unset so niri picks the panel's highest refresh rate
  }

  // ---------------------------------------------------------------------
  // layout
  //
  // niri is a *scrollable* tiler: each workspace is an infinite horizontal
  // strip of columns, and a column holds one or more stacked windows. Nothing
  // ever resizes to make room - the strip just scrolls.
  // ---------------------------------------------------------------------
  layout {
      gaps 8
      background-color "#000000"

      // don't recentre the view on every focus change; only scroll when the
      // focused column would otherwise be off-screen
      center-focused-column "never"

      // Mod+R cycles through these
      preset-column-widths {
          proportion 0.33333
          proportion 0.5
          proportion 0.66667
      }

      // Mod+Shift+R cycles these (height, for stacked windows in a column)
      preset-window-heights {
          proportion 0.33333
          proportion 0.5
          proportion 0.66667
      }

      default-column-width { proportion 0.5; }

      focus-ring {
          width 2
          active-color "#3ddbd9"    // carbon cyan, same as the helix cursor
          inactive-color "#262626"
      }

      // focus-ring already marks the focused window; a border on every window
      // is just noise at these gaps
      border {
          off
      }

      // waybar reserves its own space via layer-shell exclusive zones, so no
      // manual struts are needed here
      struts { }
  }

  // ---------------------------------------------------------------------
  // startup
  // ---------------------------------------------------------------------

  // The nixpkgs niri module builds without built-in XWayland, so X11 clients
  // need this shim. It owns :0 and niri hands X11 windows to it transparently.
  spawn-at-startup "${pkgs.xwayland-satellite}/bin/xwayland-satellite"

  // GNOME's session starts a polkit agent for you; niri does not, and without
  // one anything that needs root (gnome-disks, gparted, nm-connection-editor's
  // system connections) silently fails instead of prompting.
  spawn-at-startup "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"

  environment {
      DISPLAY ":0"
      // makes GTK/Qt apps pick the wayland backends rather than falling
      // through to XWayland
      GDK_BACKEND "wayland,x11"
      QT_QPA_PLATFORM "wayland;xcb"
      MOZ_ENABLE_WAYLAND "1"
  }

  // let apps draw their own decorations only when they insist on it
  prefer-no-csd

  screenshot-path "~/Pictures/Screenshots/%Y-%m-%d %H-%M-%S.png"

  hotkey-overlay {
      // the cheat-sheet is on Mod+Shift+/ instead
      skip-at-startup
  }

  // ---------------------------------------------------------------------
  // window rules
  // ---------------------------------------------------------------------
  window-rule {
      // rounded corners everywhere, and clip the content to match
      geometry-corner-radius 6
      clip-to-geometry true
  }

  window-rule {
      // dialogs and popups float instead of taking a column
      match is-floating=true
      geometry-corner-radius 10
      clip-to-geometry true
  }

  window-rule {
      // password prompts should never be captured by a screencast
      match app-id=r#"^org\.keepassxc\.KeePassXC$"#
      match app-id=r#"^org\.gnome\.Seahorse\.Application$"#
      match title="^.*Bitwarden.*$"
      block-out-from "screencast"
  }

  layer-rule {
      // don't let the bar or the launcher show up in screen recordings
      match namespace="^notifications$"
      block-out-from "screencast"
  }

  // ---------------------------------------------------------------------
  // binds
  //
  // Mod is Super. `niri msg action <name>` runs any of these from a shell,
  // which is handy for figuring out what an action actually does.
  // ---------------------------------------------------------------------
  binds {
      // ---- help ----
      Mod+Shift+Slash { show-hotkey-overlay; }

      // ---- launching ----
      Mod+T hotkey-overlay-title="Terminal" { spawn "${terminal}"; }
      Mod+D hotkey-overlay-title="Launcher" { spawn "${launcher}"; }
      Mod+Space hotkey-overlay-title="Launcher" { spawn "${launcher}"; }
      Mod+V hotkey-overlay-title="Clipboard history" {
          spawn "sh" "-c" "${cliphist} list | ${launcher} --dmenu | ${cliphist} decode | ${wlcopy}";
      }
      Mod+Alt+L hotkey-overlay-title="Lock the screen" { spawn "${lock}"; }

      // ---- window management ----
      Mod+Q { close-window; }
      Mod+F { maximize-column; }
      Mod+Shift+F { fullscreen-window; }
      Mod+C { center-column; }
      // Mod+W was `toggle-column-tabbed-display` (windows in a column become
      // tabs, one visible at a time). Unbound on purpose - it is easy to hit
      // by accident and the single-window case looks almost identical to
      // normal, so it reads as "my window vanished" rather than as a mode.
      // `niri msg action set-column-display normal` unsticks a column that
      // did get tabbed; there is no global switch to turn the feature off.
      Mod+Shift+Space { toggle-window-floating; }
      Mod+Shift+T { switch-focus-between-floating-and-tiling; }

      // ---- focus: left/right moves along the strip ----
      Mod+Left  { focus-column-left; }
      Mod+Right { focus-column-right; }
      Mod+H     { focus-column-left; }
      Mod+L     { focus-column-right; }
      Mod+K     { focus-window-up; }
      Mod+J     { focus-window-down; }
      Mod+Home  { focus-column-first; }
      Mod+End   { focus-column-last; }

      // ---- move the focused column along the strip ----
      Mod+Ctrl+Left  { move-column-left; }
      Mod+Ctrl+Right { move-column-right; }
      Mod+Ctrl+H     { move-column-left; }
      Mod+Ctrl+L     { move-column-right; }
      Mod+Ctrl+Up    { move-window-up; }
      Mod+Ctrl+Down  { move-window-down; }
      Mod+Ctrl+Home  { move-column-to-first; }
      Mod+Ctrl+End   { move-column-to-last; }

      // Mod+Shift+arrow is "move the column somewhere": left/right slide it
      // along this workspace's strip, up/down throw it to the workspace above
      // or below (those two live in the workspace section further down).
      // Aliases for the Mod+Ctrl binds above, which stay as they were.
      Mod+Shift+Left  { move-column-left; }
      Mod+Shift+Right { move-column-right; }

      // ---- columns: pull a window in, push one out ----
      Mod+BracketLeft  { consume-or-expel-window-left; }
      Mod+BracketRight { consume-or-expel-window-right; }
      Mod+Comma        { consume-window-into-column; }
      Mod+Period       { expel-window-from-column; }

      // ---- sizing ----
      Mod+R       { switch-preset-column-width; }
      Mod+Shift+R { switch-preset-window-height; }
      Mod+Minus   { set-column-width "-10%"; }
      Mod+Equal   { set-column-width "+10%"; }
      Mod+Shift+Minus { set-window-height "-10%"; }
      Mod+Shift+Equal { set-window-height "+10%"; }

      // ---- workspaces are a *vertical* stack, unlike gnome's horizontal one ----
      Mod+Up             { focus-workspace-up; }
      Mod+Down           { focus-workspace-down; }
      Mod+Page_Up        { focus-workspace-up; }
      Mod+Page_Down      { focus-workspace-down; }
      Mod+U              { focus-workspace-up; }
      Mod+I              { focus-workspace-down; }
      Mod+Shift+Up       { move-column-to-workspace-up; }
      Mod+Shift+Down     { move-column-to-workspace-down; }
      Mod+Shift+Page_Up  { move-column-to-workspace-up; }
      Mod+Shift+Page_Down { move-column-to-workspace-down; }
      Mod+Shift+U        { move-column-to-workspace-up; }
      Mod+Shift+I        { move-column-to-workspace-down; }

      Mod+1 { focus-workspace 1; }
      Mod+2 { focus-workspace 2; }
      Mod+3 { focus-workspace 3; }
      Mod+4 { focus-workspace 4; }
      Mod+5 { focus-workspace 5; }
      Mod+6 { focus-workspace 6; }
      Mod+7 { focus-workspace 7; }
      Mod+8 { focus-workspace 8; }
      Mod+9 { focus-workspace 9; }

      Mod+Shift+1 { move-column-to-workspace 1; }
      Mod+Shift+2 { move-column-to-workspace 2; }
      Mod+Shift+3 { move-column-to-workspace 3; }
      Mod+Shift+4 { move-column-to-workspace 4; }
      Mod+Shift+5 { move-column-to-workspace 5; }
      Mod+Shift+6 { move-column-to-workspace 6; }
      Mod+Shift+7 { move-column-to-workspace 7; }
      Mod+Shift+8 { move-column-to-workspace 8; }
      Mod+Shift+9 { move-column-to-workspace 9; }

      // ---- mouse wheel over the layout ----
      Mod+WheelScrollDown      cooldown-ms=150 { focus-workspace-down; }
      Mod+WheelScrollUp        cooldown-ms=150 { focus-workspace-up; }
      Mod+WheelScrollRight     { focus-column-right; }
      Mod+WheelScrollLeft      { focus-column-left; }

      // ---- notifications ----
      // `makoctl invoke` fires the default action on the most recent
      // notification. The claude Stop hook (~/.claude/hooks) attaches a Focus
      // action, so this jumps straight to the window + zellij pane that
      // finished - no mouse, no hunting for which pane it was.
      Mod+N       { spawn "${makoctl}" "invoke"; }
      Mod+Shift+N { spawn "${makoctl}" "dismiss"; }

      // ---- screenshots ----
      Print            { screenshot; }
      Ctrl+Print       { screenshot-screen; }
      Alt+Print        { screenshot-window; }

      // ---- media / brightness (allow-when-locked so they work at the lock screen) ----
      XF86AudioRaiseVolume allow-when-locked=true { spawn "${volume}" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+" "--limit" "1.0"; }
      XF86AudioLowerVolume allow-when-locked=true { spawn "${volume}" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
      XF86AudioMute        allow-when-locked=true { spawn "${volume}" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
      XF86AudioMicMute     allow-when-locked=true { spawn "${volume}" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }
      XF86AudioPlay        allow-when-locked=true { spawn "${player}" "play-pause"; }
      XF86AudioNext        allow-when-locked=true { spawn "${player}" "next"; }
      XF86AudioPrev        allow-when-locked=true { spawn "${player}" "previous"; }
      XF86MonBrightnessUp   allow-when-locked=true { spawn "${brightness}" "set" "5%+"; }
      XF86MonBrightnessDown allow-when-locked=true { spawn "${brightness}" "set" "5%-"; }

      // ---- session ----
      Mod+Shift+E { quit; }
      Mod+Shift+P { power-off-monitors; }
      Mod+Escape  { toggle-keyboard-shortcuts-inhibit; }
  }
''
