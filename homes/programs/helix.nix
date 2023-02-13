{
  enable = true;
  settings = {
    theme = "happysalada";
    editor = {
      idle-timeout = 100;
      lsp.display-messages = true;
      auto-save = true;
      bufferline = "always";
    };
    keys.normal = {
      space.space = "file_picker";
      space.w = ":w";
      space.q = ":q";
    };
  };
  
  languages = [
      {
        name = "nix";
        scope = "source.nix";
        injection-regex = "nix";
        file-types = ["nix"];
        comment-token = "#";
        language-server = { command = "nil"; };
        indent = { tab-width = 2; unit = "  "; };
        formatter = { command = "alejandra"; };
      }
    ];

  themes = {
    happysalada =
      let
        white = "#ffffff";
        lilac = "#dbbfef";
        lavender = "#a4a0e8";
        comet = "#5a5977";
        bossanova = "#452859";
        # midnight = "#3b224c";
        revolver = "#281733";

        silver = "#cccccc";
        sirocco = "#697C81";
        mint = "#9ff28f";
        honey = "#efba5d";

        apricot = "#f47868";
        lightning = "#ffcd1c";
        delta = "#6F44F0";

        indigo = "#6974FF";
        orange = "#fdba74";
        light_blue = "#9DB7FE";
        pastel_pink = "#f0abfc";
        # light_green = "#A6E22E";
        emerald = "#61C2A2";
        red = "#E06C75";
        # highlight_pink = "#991F4E";
        candy_pink = "#E673AA";
        purple = "#540099";
      in
      {
        attribute = pastel_pink;
        keyword = sirocco;
        "keyword.directive" = red; # -- preprocessor comments (#if in C)
        namespace = silver;
        punctuation = silver;
        "punctuation.delimiter" = silver;
        operator = silver;
        special = honey;
        property = white;
        variable = indigo;
        "variable.parameter" = { fg = pastel_pink; };
        "variable.builtin" = mint;
        type = emerald;
        "type.builtin" = emerald; # TODO: distinguish?
        constructor = indigo;
        function = light_blue;
        "function.macro" = candy_pink;
        "function.builtin" = white;
        tag = orange;
        comment = comet;
        constant = white;
        "constant.builtin" = white;
        string = sirocco;
        number = honey;
        escape = honey;
        # used for lifetimes
        label = candy_pink;

        # TODO: diferentiate doc comment
        # concat (ERROR) @error.syntax and "MISSING ;" selectors for errors

        "ui.background" = { bg = "#000000"; };
        "ui.linenr" = { fg = comet; };
        "ui.linenr.selected" = { fg = lilac; };
        "ui.statusline" = { fg = lilac; bg = revolver; };
        "ui.statusline.inactive" = { fg = lavender; bg = revolver; };
        "ui.popup" = { bg = revolver; };
        "ui.window" = { fg = bossanova; };
        "ui.help" = { bg = "#7958DC"; fg = "#171452"; };

        "ui.text" = { fg = lavender; };
        "ui.text.focus" = { fg = white; };

        "ui.selection" = { bg = purple; };
        "ui.selection.primary" = { bg = purple; };
        # TODO: namespace ui.cursor as ui.selection.cursor?
        "ui.cursor.select" = { bg = bossanova; };
        "ui.cursor.insert" = { bg = white; };
        "ui.cursor.match" = { fg = "#212121"; bg = "#6C6999"; };
        "ui.cursor" = { modifiers = [ "reversed" ]; };
        "ui.highlight" = { bg = bossanova; };

        "ui.menu.selected" = { fg = revolver; bg = white; };

        "diff.plus" = "light-green";
        "diff.delta" = "light-blue";
        "diff.delta.moved" = "blue";
        "diff.minus" = "light-red";

        diagnostic = { modifiers = [ "underlined" ]; };

        warning = lightning;
        error = apricot;
        info = delta;
        hint = silver;
      };
  };
}
