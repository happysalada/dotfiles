{
  enable = true;
  settings = {
    window.dimensions = {
      lines = 42;
      columns = 160;
    };
    scrolling.history = 100000;
    colors.primary.background = "0x000000";
    font.normal.family = "FiraCode Nerd Font";
    font.bold.family = "FiraCode Nerd Font";
    font.italic.family = "FiraCode Nerd Font";
    font.size = 24;
    key_bindings = [
      { key = "V"; mods = "Command"; action = "Paste"; }
      { key = "C"; mods = "Command"; action = "Copy"; }
      { key = "Left"; chars = "\\x1b[D"; mode = "~AppCursor"; }
      { key = "Left"; chars = "\\x1bOD"; mode = "AppCursor"; }
      { key = "Right"; chars = "\\x1b[C"; mode = "~AppCursor"; }
      { key = "Right"; chars = "\\x1bOC"; mode = "AppCursor"; }
      # Scrollback
      # toggle scrollback
      { key = "U"; mods = "Control"; chars = "\\x1b[1;3A"; }
      { key = "Up"; chars = "\\x1b[A"; mode = "~AppCursor"; }
      { key = "Up"; chars = "\\x1bOA"; mode = "AppCursor"; }
      { key = "Down"; chars = "\\x1b[B"; mode = "~AppCursor"; }
      { key = "Down"; chars = "\\x1bOB"; mode = "AppCursor"; }
      # split vertically
      { key = "D"; mods = "Command"; chars = "\\x06\\x76"; }
      # split horizontaly
      { key = "D"; mods = "Command|Shift"; chars = "\\x06\\x73"; }
      # close terminal
      { key = "W"; mods = "Command"; chars = "\\x06\\x78"; }
      # select left terminal
      { key = "N"; mods = "Command"; chars = "\\x06\\x68"; }
      # select bottom terminal
      { key = "E"; mods = "Command"; chars = "\\x06\\x6a"; }
      # select upper terminal
      { key = "U"; mods = "Command"; chars = "\\x06\\x6b"; }
      # select right terminal
      { key = "I"; mods = "Command"; chars = "\\x06\\x6c"; }
      # open new tab
      { key = "T"; mods = "Command"; chars = "\\x06\\x63"; }

    ];
  };
}
