
{
    enable = true;
    settings = {
      window.dimensions = {
        lines = 42;
        columns = 130;
      };
      colors.primary.background= "0x000000";
      font.normal.family = "Fira Code";
      font.bold.family = "Fira Code";
      font.italic.family = "Fira Code";
      font.size = 20;
      key_bindings = [
        { key= "V";     mods= "Command";  action= "Paste";             }
        { key= "C";     mods= "Command";  action= "Copy";              }
        { key= "Left";                    chars= "\\x1b[D";   mode= "~AppCursor";  }
        { key= "Left";                    chars= "\\x1bOD";   mode= "AppCursor";   }
        { key= "Right";                   chars= "\\x1b[C";   mode= "~AppCursor";  }
        { key= "Right";                   chars= "\\x1bOC";   mode= "AppCursor";   }
        # Scrollback
        { key= "U";     mods= "Control";  chars= "\\x1b[1;3A";                }
        { key= "Up";                      chars= "\\x1b[A";   mode= "~AppCursor";  }
        { key= "Up";                      chars= "\\x1bOA";   mode= "AppCursor";   }
        { key= "Down";                    chars= "\\x1b[B";   mode= "~AppCursor";  }
        { key= "Down";                    chars= "\\x1bOB";   mode= "AppCursor";   }
        { key= "D";     mods= "Command";  chars= "\\x06\\x76"; }
        { key= "D";     mods= "Command|Shift";  chars= "\\x06\\x73"; }
        { key= "W";     mods= "Command";  chars= "\\x06\\x78"; }
        { key= "N";     mods= "Command";  chars= "\\x06\\x68"; }
        { key= "E";     mods= "Command";  chars= "\\x06\\x6a"; }
        { key= "U";     mods= "Command";  chars= "\\x06\\x6b"; }
        { key= "I";     mods= "Command";  chars= "\\x06\\x6c"; }
        { key= "T";     mods= "Command";  chars= "\\x06\\x63"; }

      ];
    };
}
