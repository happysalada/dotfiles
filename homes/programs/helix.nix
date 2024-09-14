{ pkgs }:
{
  enable = true;
  defaultEditor = true;
  extraPackages = [ pkgs.marksman ];
  settings = {
    theme = "carbon";
    editor = {
      idle-timeout = 100;
      auto-save = true;
      bufferline = "always";
      soft-wrap.enable = true;
      lsp = {
        display-inlay-hints = true;
        display-messages = true;
        display-signature-help-docs = true;
      };
      jump-label-alphabet = "ntesiroalphduf,cyw.x";
    };
    keys.normal = {
      space.space = "file_picker";
      space.w = ":w";
      space.q = ":q";
    };
  };

  languages = {
    # the language servers fail on _latest
    language-server =
      with pkgs;
      with pkgs.nodePackages_latest;
      {
        typescript-language-server = {
          command = "${typescript-language-server}/bin/typescript-language-server";
          args = [ "--stdio" ];
        };
        svelteserver.command = "${svelte-language-server}/bin/svelteserver";
        tailwindcss-ls.command = "${tailwindcss-language-server}/bin/tailwindcss-language-server";
        # nixd = {
        #   command = "${nixd}/bin/nixd";
        # };
        # eslint = {
        #   command = "${eslint}/bin/eslint";
        #   args = [ "--stdin" ];
        # };
        copilot = {
          command = "${helix-gpt}/bin/helix-gpt";
          args = [
            "--handler"
            "copilot"
          ];
        };
        codeium = {
          command = "${helix-gpt}/bin/helix-gpt";
          args = [
            "--handler"
            "codeium"
          ];
        };
        # copilot = {
        #   command = "${copilot-lsp}/copilot";
        #   language-id = "copilot";
        #   args = ["--stdio"];
        # };
        nil.command = "${nil}/bin/nil";
        rust-analyzer.command = "${rust-analyzer-unwrapped}/bin/rust-analyzer";
      };
    language = [
      {
        name = "rust";
        language-servers = [
          "copilot"
          "codeium"
        ];
      }
      {
        name = "javascript";
        formatter = {
          command = "prettier";
          args = [
            "--parser"
            "typescript"
          ];
        };
        language-servers = [
          "typescript-language-server"
          "eslint"
          "copilot"
          "codeium"
        ];
        auto-format = true;
      }
      {
        name = "typescript";
        formatter = {
          command = "prettier";
          args = [
            "--parser"
            "typescript"
          ];
        };
        language-servers = [
          "eslint"
          "copilot"
          "codeium"
        ];
        auto-format = true;
      }
      {
        name = "svelte";
        formatter = {
          command = "prettier";
          args = [
            "--plugin"
            "prettier-plugin-svelte"
          ];
        };
        language-servers = [
          "tailwindcss-ls"
          "eslint"
          "copilot"
          "codeium"
        ];
        auto-format = true;
      }
      {
        name = "nix";
        auto-format = true;
        formatter = {
          command = "nixfmt";
          args = [ "--verify" ];
        };
        language-servers = [
          # "nixd"
          "nil"
          "copilot"
          "codeium"
        ];
      }
      {
        name = "python";
        language-servers = [
          "pylsp"
          "pyright"
          "copilot"
          "codeium"
        ];
        formatter = {
          command = "black";
          args = [
            "--quiet"
            "-"
          ];
        };
        auto-format = true;
      }
    ];
  };

  themes = {
    carbon = {
      "attribute" = "base12";

      "type" = {
        fg = "base09";
        modifiers = [ "italic" ];
      };
      "type.enum.variant" = "base08";

      "constructor" = "base12";

      "constant" = "base14";
      "constant.character" = "base07";
      "constant.character.escape" = "base12";

      "string" = "base14";
      "string.regexp" = "base12";
      "string.special" = "base11";
      "string.special.symbol" = "base10";

      "comment" = {
        fg = "base03";
        modifiers = [ "italic" ];
      };

      "variable" = "base04";
      "variable.parameter" = {
        fg = "base04";
        modifiers = [ "italic" ];
      };
      "variable.builtin" = "base04";
      "variable.other.member" = {
        fg = "base12";
        modifiers = [ "italic" ];
      };

      "label" = "base09"; # used for lifetimes

      "punctuation" = "cyan10";
      "punctuation.special" = "base08";
      "punctuation.bracket" = "cyan10";

      "keyword" = {
        fg = "base09";
        modifiers = [ "italic" ];
      };
      "keyword.control.conditional" = {
        fg = "base09";
        modifiers = [ "italic" ];
      };
      "keyword.function" = {
        fg = "aqua";
        modifiers = [ "italic" ];
      };

      "operator" = "base09";

      "function" = {
        fg = "base12";
        modifiers = [ "italic" ];
      };
      "function.macro" = {
        fg = "base07";
        modifiers = [ "italic" ];
      };

      "tag" = "base11";

      "namespace" = {
        fg = "aqua";
        modifiers = [ "italic" ];
      };

      "special" = "base11"; # fuzzy highlight

      "markup.heading.marker" = {
        fg = "base15";
        modifiers = [ "bold" ];
      };
      "markup.heading.1" = "base10";
      "markup.heading.2" = "base12";
      "markup.heading.3" = "base13";
      "markup.heading.4" = "base14";
      "markup.heading.5" = "base07";
      "markup.heading.6" = "base08";
      "markup.list" = "base09";
      "markup.bold" = {
        modifiers = [ "bold" ];
      };
      "markup.italic" = {
        modifiers = [ "italic" ];
      };
      "markup.link.url" = {
        fg = "base11";
        modifiers = [
          "italic"
          "underlined"
        ];
      };
      "markup.link.text" = "base12";
      "markup.raw" = "base13";

      "diff.plus" = "base13";
      "diff.minus" = "base10";
      "diff.delta" = "base09";

      # User Interface
      # --------------
      "ui.background" = {
        fg = "base04";
        bg = "black";
      };

      "ui.linenr" = {
        fg = "base02";
      };
      "ui.linenr.selected" = {
        fg = "base04";
      };

      "ui.statusline" = {
        fg = "blue60";
        bg = "black";
      };
      "ui.statusline.inactive" = {
        fg = "base03";
        bg = "base01";
      };
      "ui.statusline.normal" = {
        fg = "base00";
        bg = "base09";
        modifiers = [ "bold" ];
      };
      "ui.statusline.insert" = {
        fg = "base00";
        bg = "base13";
        modifiers = [ "bold" ];
      };
      "ui.statusline.select" = {
        fg = "base00";
        bg = "base12";
        modifiers = [ "bold" ];
      };

      "ui.popup" = {
        fg = "base04";
        bg = "base01";
      };
      "ui.window" = {
        fg = "base01";
      };
      "ui.help" = {
        fg = "base03";
        bg = "base01";
      };

      "ui.bufferline" = {
        fg = "base03";
        bg = "base01";
      };
      "ui.bufferline.active" = {
        fg = "base09";
        bg = "base00";
        underline = {
          color = "base09";
          style = "none";
        };
      };
      "ui.bufferline.background" = {
        bg = "base01";
      };

      "ui.text" = "base04";
      "ui.text.focus" = {
        fg = "base04";
        bg = "base01";
        modifiers = [ "bold" ];
      };
      "ui.text.inactive" = {
        fg = "base03";
      };

      "ui.virtual" = "base02";
      "ui.virtual.ruler" = {
        bg = "base01";
      };
      "ui.virtual.indent-guide" = "base01";
      "ui.virtual.inlay-hint" = {
        fg = "base03";
        bg = "base00";
      };
      "ui.virtual.jump-label" = {
        fg = "base07";
        modifiers = [ "bold" ];
      };

      "ui.selection" = {
        bg = "base02";
      };

      "ui.cursor" = {
        fg = "base00";
        bg = "base08";
      };
      "ui.cursor.primary" = {
        fg = "base00";
        bg = "base08";
      };
      "ui.cursor.match" = {
        fg = "base15";
        modifiers = [ "bold" ];
      };

      "ui.cursor.primary.normal" = {
        fg = "base00";
        bg = "green";
      };
      "ui.cursor.primary.insert" = {
        fg = "base00";
        bg = "base13";
      };
      "ui.cursor.primary.select" = {
        fg = "base00";
        bg = "base08";
      };

      "ui.cursor.normal" = {
        fg = "base00";
        bg = "base11";
      };
      "ui.cursor.insert" = {
        fg = "base00";
        bg = "base13";
      };
      "ui.cursor.select" = {
        fg = "base00";
        bg = "base08";
      };

      "ui.cursorline.primary" = {
        bg = "base01";
      };

      "ui.highlight" = {
        bg = "base02";
        modifiers = [ "bold" ];
      };

      "ui.menu" = {
        fg = "white30";
        bg = "base01";
      };
      "ui.menu.selected" = {
        fg = "white30";
        bg = "base02";
        modifiers = [ "bold" ];
      };

      "diagnostic.error" = {
        underline = {
          color = "base10";
          style = "curl";
        };
      };
      "diagnostic.warning" = {
        underline = {
          color = "base14";
          style = "curl";
        };
      };
      "diagnostic.info" = {
        underline = {
          color = "base09";
          style = "curl";
        };
      };
      "diagnostic.hint" = {
        underline = {
          color = "base08";
          style = "curl";
        };
      };

      error = "base10";
      warning = "base14";
      info = "base09";
      hint = "base08";

      palette = {
        black = "#000000";
        white = "#FFFFFF";
        base00 = "#161616";
        base01 = "#262626";
        base02 = "#393939";
        base03 = "#525252";
        base04 = "#c8ccd4";
        base05 = "#d6cedd";
        base06 = "#fdfcfd";
        base07 = "#08bdba";
        base08 = "#3ddbd9";
        base09 = "#78a9ff";
        base10 = "#ee5396";
        base11 = "#78a8ff";
        base12 = "#ff7eb6";
        base13 = "#42be65";
        base14 = "#be95ff";
        base15 = "#82cfff";
        green = "#19b06a";
        aqua = "#00dfdb";
        yellow = "#fedc69";
        blue60 = "#0043ce";
        white10 = "#f4f4f4";
        white20 = "#e0e0e0";
        white30 = "#a8a8a8";
        cyan10 = "#6bcafe";
        cyan20 = "#32afff";
      };
    };
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
        "variable.parameter" = {
          fg = pastel_pink;
        };
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

        "ui.background" = {
          bg = "#000000";
        };
        "ui.linenr" = {
          fg = comet;
        };
        "ui.linenr.selected" = {
          fg = lilac;
        };
        "ui.statusline" = {
          fg = lilac;
          bg = revolver;
        };
        "ui.statusline.inactive" = {
          fg = lavender;
          bg = revolver;
        };
        "ui.popup" = {
          bg = revolver;
        };
        "ui.window" = {
          fg = bossanova;
        };
        "ui.help" = {
          bg = "#7958DC";
          fg = "#171452";
        };

        "ui.text" = {
          fg = lavender;
        };
        "ui.text.focus" = {
          fg = white;
        };

        "ui.selection" = {
          bg = purple;
        };
        "ui.selection.primary" = {
          bg = purple;
        };
        # TODO: namespace ui.cursor as ui.selection.cursor?
        "ui.cursor.select" = {
          bg = bossanova;
        };
        "ui.cursor.insert" = {
          bg = white;
        };
        "ui.cursor.match" = {
          fg = "#212121";
          bg = "#6C6999";
        };
        "ui.cursor" = {
          modifiers = [ "reversed" ];
        };
        "ui.highlight" = {
          bg = bossanova;
        };

        "ui.menu.selected" = {
          fg = revolver;
          bg = white;
        };

        "ui.virtual.jump-label" = {
          fg = purple;
          bg = candy_pink;
        };

        "diff.plus" = "light-green";
        "diff.delta" = "light-blue";
        "diff.delta.moved" = "blue";
        "diff.minus" = "light-red";

        diagnostic = {
          modifiers = [ "underlined" ];
        };

        warning = lightning;
        error = apricot;
        info = delta;
        hint = silver;
      };
  };
}
