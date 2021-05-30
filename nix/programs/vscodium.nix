{ pkgs, ... }:
{
  enable = true;
  package = pkgs.vscodium;
  extensions = with pkgs.vscode-extensions; [
    vscodevim.vim
    serayuzgur.crates
    tamasfe.even-better-toml
    bbenoist.Nix
    matklad.rust-analyzer
    jock.svg
    editorconfig.editorconfig
    coenraads.bracket-pair-colorizer-2
    esbenp.prettier-vscode
  ];
  userSettings = {
    "files.autoSave" = "onFocusChange";
    "explorer.confirmDelete" = false;
    "editor.tabSize" = 2;
    "editor.fontSize" = 18;
    "editor.lineNumbers" = "interval";
    "editor.cursorBlinking" = "solid";
    "editor.fontFamily" = "Fira Code";
    "editor.fontLigatures" = true;
    "editor.fontWeight" = "400";
    "editor.formatOnSave" = true;
    "editor.formatOnPaste" = true;
    "breadcrumbs.enabled" = true;
    # vim
    "vim.easymotion" = false;
    "vim.sneak" = true;
    "vim.leader" = ",";
    "vim.useSystemClipboard" = true;
    # rust
    "rust-analyzer.checkOnSave.command" = "clippy";
    "[rust]" = {
      "editor.defaultFormatter" = "matklad.rust-analyzer";
    };
    # prettier
    "[json]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
    };
    "[html]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
    };
    "[css]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
    };
    # color
    "workbench.colorTheme" = "Default High Contrast";
    "workbench.colorCustomizations" = {
      "[Default High Contrast]" = {
        "editor.lineHighlightBackground" = "#000";
        "editor.lineHighlightBorder" = "#000";
        "contrastBorder" = "#000";
        "contrastActiveBorder" = "#BD93F9";
        "focusBorder" = "#ff79c6ff";
      };
    };
    "editor.tokenColorCustomizations" = {
      "[Default High Contrast]" = {
        "functions" = "#BD93F9";
        "strings" = "#e9f284ff";
        "numbers" = "#F99157";
        "textMateRules" = [
          {
            "scope" = [ "comment.documentation.heredoc.elixir" ];
            "settings" = {
              "foreground" = "#6273a49d";
            };
          }
          {
            "scope" = [ "keyword.operator.new" ];
            "settings" = {
              "fontStyle" = "";
            };
          }
          {
            "scope" = [
              "keyword.control.elixir"
              "keyword.control.module.elixir"
              "punctuation.section.embedded.begin.tsx"
              "punctuation.section.embedded.end.tsx"
              "comment.block.documentation storage.type.class"
              "storage.type.function.arrow.js"
              "punctuation.definition.block.js"
              "punctuation.definition.block.jsx"
              "punctuation.definition.block.ts"
              "punctuation.definition.block.tsx"
              "punctuation.definition.binding-pattern.object.js"
              "punctuation.definition.binding-pattern.object.jsx"
              "punctuation.definition.binding-pattern.object.ts"
              "punctuation.definition.binding-pattern.object.tsx"
            ];
            "settings" = {
              "foreground" = "#FF79C6";
            };
          }
          {
            "scope" = [ "comment.unused.elixir" ];
            "settings" = {
              "foreground" = "#97989a";
            };
          }
          {
            "scope" = [
              "support.class"
              "support.variable"
              "variable.other.constant"
              "meta.export variable.other.readwrite"
            ];
            "settings" = {
              "fontStyle" = "";
              "foreground" = "#f8f8f2ff";
            };
          }
          {
            "scope" = [ "support.class" ];
            "settings" = {
              "fontStyle" = "bold";
            };
          }
          {
            "scope" = [ "entity.name.type.rust" "entity.name.type.class" ];
            "settings" = {
              "fontStyle" = "bold";
              "foreground" = "#f8f8f2ff";
            };
          }
          {
            "scope" = [ "storage.class.std.rust" "entity.other.inherited-class" ];
            "settings" = {
              "fontStyle" = "italic bold";
              "foreground" = "#f8f8f2ff";
            };
          }
          {
            "scope" = [
              "entity.name.type"
              "meta.brace.round.js"
              "meta.brace.round.jsx"
              "meta.brace.round.ts"
              "meta.brace.round.tsx"
              "storage.type.function"
              "punctuation.definition.parameters"
              "meta.function-call.generic"
              "punctuation.definition.arguments.begin"
              "punctuation.definition.arguments.end"
            ];
            "settings" = {
              "foreground" = "#bd93f9ff";
              "fontStyle" = "";
            };
          }
          {
            "scope" = [ "meta.object-literal.key" ];
            "settings" = {
              "fontStyle" = "italic";
            };
          }
          {
            "scope" = [ "meta.object-literal.key" "variable.object.property.tsx" ];
            "settings" = {
              "fontStyle" = "italic";
            };
          }
          {
            "scope" = [
              "entity.other.attribute-name"
              "support.type.object.module.js"
              "meta.object-literal.key entity.name.function.js"
            ];
            "settings" = {
              "foreground" = "#c6f56aff";
            };
          }
          {
            "scope" = [ "punctuation.separator.key-value" ];
            "settings" = {
              "fontStyle" = "";
            };
          }
          {
            "scope" = [
              "entity.name.type.module.elixir"
              "variable.other.constant.elixir"
              "variable.parameter"
              "comment.block.documentation variable"
            ];
            "settings" = {
              "foreground" = "#8be9fdff";
            };
          }
          {
            "scope" = [
              "constant"
              "meta.type_params.rust"
              "storage.type.core.rust"
              "punctuation.definition.typeparameters.begin"
              "punctuation.definition.typeparameters.end"
            ];
            "settings" = {
              "foreground" = "#F99157";
            };
          }
          {
            "scope" = [ "variable.language" ];
            "settings" = {
              "foreground" = "#ff79c6ff";
            };
          }
          {
            "scope" = [
              "string.regexp"
              "meta.group.regexp"
              "keyword.operator.or.regexp"
              "keyword.control.anchor.regexp"
              "punctuation.definition.group.regexp"
              "constant.character.escape.backslash.regexp"
            ];
            "settings" = {
              "foreground" = "#ff5555ff";
            };
          }
          {
            "scope" = [
              "entity.name.tag"
              "punctuation.definition.tag.begin"
              "punctuation.definition.tag.end"
              "support.class.component.tsx"
            ];
            "settings" = {
              "foreground" = "#c6f56aff";
            };
          }
          {
            "scope" = [
              "support.class.component.js"
              "support.class.component.js.jsx"
            ];
            "settings" = {
              "foreground" = "#c6f56aff";
            };
          }
          {
            "scope" = [ "meta.type.parameters.tsx support.type.primitive.tsx" ];
            "settings" = {
              "foreground" = "#FFB86C";
            };
          }
        ];
      };
    };
  };
}
