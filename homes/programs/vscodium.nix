{ pkgs, ... }:
{
  enable = true;
  package = pkgs.vscode;
  extensions = with pkgs.vscode-extensions; [
    vscodevim.vim
    serayuzgur.crates
    tamasfe.even-better-toml
    bbenoist.nix
    rust-lang.rust-analyzer
    vadimcn.vscode-lldb
    # jock.svg
    editorconfig.editorconfig
    esbenp.prettier-vscode
    emmanuelbeziat.vscode-great-icons
    davidanson.vscode-markdownlint
    svelte.svelte-vscode
    bradlc.vscode-tailwindcss
    kahole.magit
    bodil.file-browser
    vspacecode.vspacecode
    vspacecode.whichkey
    # tiehuis.zig
    github.copilot
  ];
  keybindings = [
    {
      "key" = "space";
      "command" = "vspacecode.space";
      "when" = "activeEditorGroupEmpty && focusedView == '' && !whichkeyActive && !inputFocus";
    }
    {
      "key" = "space";
      "command" = "vspacecode.space";
      "when" = "sideBarFocus && !inputFocus && !whichkeyActive";
    }
    {
      "key" = "tab";
      "command" = "extension.vim_tab";
      "when" = "editorFocus && vim.active && !inDebugRepl && vim.mode != 'Insert' && editorLangId != 'magit'";
    }
    {
      "key" = "tab";
      "command" = "-extension.vim_tab";
      "when" = "editorFocus && vim.active && !inDebugRepl && vim.mode != 'Insert'";
    }
    {
      "key" = "x";
      "command" = "magit.discard-at-point";
      "when" = "editorTextFocus && editorLangId == 'magit' && vim.mode =~ /^(?!SearchInProgressMode|CommandlineInProgress).*$/";
    }
    {
      "key" = "k";
      "command" = "-magit.discard-at-point";
    }
    {
      "key" = "-";
      "command" = "magit.reverse-at-point";
      "when" = "editorTextFocus && editorLangId == 'magit' && vim.mode =~ /^(?!SearchInProgressMode|CommandlineInProgress).*$/";
    }
    {
      "key" = "v";
      "command" = "-magit.reverse-at-point";
    }
    {
      "key" = "shift+-";
      "command" = "magit.reverting";
      "when" = "editorTextFocus && editorLangId == 'magit' && vim.mode =~ /^(?!SearchInProgressMode|CommandlineInProgress).*$/";
    }
    {
      "key" = "shift+v";
      "command" = "-magit.reverting";
    }
    {
      "key" = "shift+o";
      "command" = "magit.resetting";
      "when" = "editorTextFocus && editorLangId == 'magit' && vim.mode =~ /^(?!SearchInProgressMode|CommandlineInProgress).*$/";
    }
    {
      "key" = "shift+x";
      "command" = "-magit.resetting";
    }
    {
      "key" = "x";
      "command" = "-magit.reset-mixed";
    }
    {
      "key" = "ctrl+u x";
      "command" = "-magit.reset-hard";
    }
    {
      "key" = "y";
      "command" = "-magit.show-refs";
    }
    {
      "key" = "y";
      "command" = "vspacecode.showMagitRefMenu";
      "when" = "editorTextFocus && editorLangId == 'magit' && vim.mode == 'Normal'";
    }
    {
      "key" = "ctrl+j";
      "command" = "workbench.action.quickOpenSelectNext";
      "when" = "inQuickOpen";
    }
    {
      "key" = "ctrl+k";
      "command" = "workbench.action.quickOpenSelectPrevious";
      "when" = "inQuickOpen";
    }
    {
      "key" = "ctrl+j";
      "command" = "selectNextSuggestion";
      "when" = "suggestWidgetMultipleSuggestions && suggestWidgetVisible && textInputFocus";
    }
    {
      "key" = "ctrl+k";
      "command" = "selectPrevSuggestion";
      "when" = "suggestWidgetMultipleSuggestions && suggestWidgetVisible && textInputFocus";
    }
    {
      "key" = "ctrl+l";
      "command" = "acceptSelectedSuggestion";
      "when" = "suggestWidgetMultipleSuggestions && suggestWidgetVisible && textInputFocus";
    }
    {
      "key" = "ctrl+j";
      "command" = "showNextParameterHint";
      "when" = "editorFocus && parameterHintsMultipleSignatures && parameterHintsVisible";
    }
    {
      "key" = "ctrl+k";
      "command" = "showPrevParameterHint";
      "when" = "editorFocus && parameterHintsMultipleSignatures && parameterHintsVisible";
    }
    {
      "key" = "ctrl+h";
      "command" = "file-browser.stepOut";
      "when" = "inFileBrowser";
    }
    {
      "key" = "ctrl+l";
      "command" = "file-browser.stepIn";
      "when" = "inFileBrowser";
    }
  ];
  userSettings = {
    "files.autoSave" = "onFocusChange";
    "update.mode" = "none"; # updates are done by nix
    "explorer.confirmDelete" = false;
    "editor.tabSize" = 2;
    "editor.fontSize" = 20;
    "editor.lineNumbers" = "interval";
    "editor.cursorBlinking" = "solid";
    "editor.fontFamily" = "Fira Code";
    "editor.fontLigatures" = true;
    "editor.fontWeight" = "400";
    "editor.formatOnSave" = true;
    "editor.formatOnPaste" = true;
    "breadcrumbs.enabled" = true;
    # git
    "git.confirmSync" = false;
    "git.autofetch" = false;
    "magit.code-path" = "codium";
    # copilot
    "github.copilot.enable" = {
      "plaintext" = "true";
      "markdown" = "true";
    };
    # vim
    "vim.easymotion" = false;
    "vim.sneak" = true;
    "vim.leader" = ",";
    "vim.useSystemClipboard" = true;
    "vim.normalModeKeyBindingsNonRecursive" = [
      {
        "before" = [ "<space>" ];
        "commands" = [ "vspacecode.space" ];
      }
      {
        "before" = [ "," ];
        "commands" = [
          "vspacecode.space"
          {
            "command" = "whichkey.triggerKey";
            "args" = "m";
          }
        ];
      }
    ];
    "vim.visualModeKeyBindingsNonRecursive" = [
      {
        "before" = [ "<space>" ];
        "commands" = [ "vspacecode.space" ];
      }
      {
        "before" = [ "," ];
        "commands" = [
          "vspacecode.space"
          {
            "command" = "whichkey.triggerKey";
            "args" = "m";
          }
        ];
      }
    ];
    # rust
    "rust-analyzer.checkOnSave.command" = "clippy";
    "rust-analyzer.runnables.overrideCargo" = "$(which cargo)";
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
    "[javascript]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
    };
    "[typescript]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
    };
    "typescript.updateImportsOnFileMove.enabled" = "always";
    # svelte
    "[svelte]" = {
      "editor.defaultFormatter" = "svelte.svelte-vscode";
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
    # icons
    "workbench.iconTheme" = "vscode-great-icons";
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
            "scope" = [
              "entity.name.type.rust"
              "entity.name.type.class"
            ];
            "settings" = {
              "fontStyle" = "bold";
              "foreground" = "#f8f8f2ff";
            };
          }
          {
            "scope" = [
              "storage.class.std.rust"
              "entity.other.inherited-class"
            ];
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
            "scope" = [
              "meta.object-literal.key"
              "variable.object.property.tsx"
            ];
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
