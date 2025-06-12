{
  pkgs,
  ...
}:
{
  enable = true;
  package = pkgs.nushell;

  envFile.text = ''
    $env.EDITOR = "hx"
    $env.NIXPKGS_ALLOW_UNFREE = 1
    $env.LANG = "en_US.UTF-8";
    # Fix numpy runs and various python packages
    # depending on libstdc++.so:6
    $env.LD_LIBRARY_PATH = "${pkgs.gcc.cc.lib}/lib"
  '';
  environmentVariables = {
    # OPENAI_API_KEY = lib.mkIf pkgs.stdenv.isDarwin "(open $'(getconf DARWIN_USER_TEMP_DIR)/agenix/OPENAI_API_KEY')";
    # no ssh keys created yet on the linux server
    # "(open $'($env.XDG_RUNTIME_DIR)/agenix/OPENAI_API_KEY')"
  };
  shellAliases = {
    # nix
    nixroots = "nix-store --gc --print-roots";
    # git
    gp = "git push";
    gpf = "git push --force";
    gl = "git log --pretty=oneline --abbrev-commit";
    gb = "git branch";
    gbd = "git branch --delete --force";
    c = "git checkout";
    gpp = "git pull --prune";
    gsi = "git stash --include-untracked";
    gsp = "git stash pop";
    gsa = "git stage --all";
    gfu = "git fetch upstream";
    gmu = "git merge upstream/master master";
    gu = "git reset --soft HEAD~1";
    grh = "git reset --hard";
    grm = "git rebase master";
    # misc
    b = "broot -ghi";
    # nix
    nci = "nix_copy_inputs";
    # himalaya
    h = "himalaya";
    hmr = "himalaya message read";
    hmd = "himalaya message delete";
    has = "himalaya account sync";
  };

  extraConfig = ''
    $env.config = ($env.config | merge {
      edit_mode: vi
      show_banner: false
    });

    # plugin add ${pkgs.nushellPlugins.net}/bin/nu_plugin_net

    # maybe useful functions
    # use ${pkgs.nu_scripts}/share/nu_scripts/modules/formats/to-number-format.nu *
    # use ${pkgs.nu_scripts}/share/nu_scripts/sourced/api_wrappers/wolframalpha.nu *
    # use ${pkgs.nu_scripts}/share/nu_scripts/modules/background_task/job.nu *
    # use ${pkgs.nu_scripts}/share/nu_scripts/modules/network/ssh.nu *

    # completions
    use ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/git/git-completions.nu *
    use ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/btm/btm-completions.nu *
    use ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/cargo/cargo-completions.nu *
    use ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/nix/nix-completions.nu *
    use ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/tealdeer/tldr-completions.nu *
    use ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/zellij/zellij-completions.nu *
    use ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/rg/rg-completions.nu *
    use ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/ssh/ssh-completions.nu *

    def gcb [name: string] {
      git checkout -b $name
    }

    def gc [name: string] {
      git checkout $name
    }

    def l [directory: string = "."] {
      ls -a $directory | select name size | sort-by name
    }

    def cl [directory: string] {
      cd $directory
      l
    }

    def ggc [] {
      git reflog expire --all --expire=now
      git gc --prune=now --aggressive
    }

    # sudo version is to clean nix-darwin old generations
    # non sudo is to clean home-manager
    def nixgc [] {
      nix store gc --verbose
      nix-collect-garbage -d
      # Sudo is required too
      sudo nix store gc --verbose
      sudo nix-collect-garbage -d
    }

    # deletes the branches already merged upstream
    def gbdm [] {
      git pull --prune
      git branch -vl | lines | split column " " BranchName Hash Status --collapse-empty | where Status == '[gone]' | each { |it| git branch -D $it.BranchName }
    }

    def nix_copy_inputs [to: string] {
      nix flake archive --json | from json | get inputs | transpose | each { |input| $input.column1.path | xargs nix copy --to $"ssh://($to)" }
    }

    # Define a function to fetch secrets using systemd-credentials
    def fetch_secrets [secrets_json: string] {
        # Parse the input configuration
        let secrets_config = ($secrets_json | from json)
        let secrets_list = $secrets_config.secrets

        # Initialize an empty table to hold the results
        mut results = {}

        # Iterate over each secret in the list
        for $secret in $secrets_list {
            # Run systemd-credentials and capture both stdout and stderr
            let output = (do { ^systemd-creds cat $"($secret)_FILE" } | complete)

            # Append the result row to the results table
            $results = ($results | insert $"($secret)" { value: ($output.stdout | str trim), error: $output.stderr})
        }

        # Output the results table as JSON
        $results | to json
    }

    # let mise_path = $nu.default-config-dir | path join mise.nu
    # ^mise activate nu | save $mise_path --force

    # use mise.nu
  '';

  configFile.text = ''
    # For more information on defining custom themes, see
    # https://www.nushell.sh/book/coloring_and_theming.html
    # And here is the theme collection
    # https://github.com/nushell/nu_scripts/tree/main/themes
    let dark_theme = {
        # color for nushell primitives
        separator: white
        leading_trailing_space_bg: { attr: n } # no fg, no bg, attr none effectively turns this off
        header: green_bold
        empty: blue
        # Closures can be used to choose colors for specific values.
        # The value (in this case, a bool) is piped into the closure.
        bool: {|| if $in { 'light_cyan' } else { 'light_gray' } }
        int: white
        filesize: {|e|
          if $e == 0b {
            'white'
          } else if $e < 1mb {
            'cyan'
          } else { 'blue' }
        }
        duration: white
        date: {|| (date now) - $in |
          if $in < 1hr {
            'red3b'
          } else if $in < 6hr {
            'orange3'
          } else if $in < 1day {
            'yellow3b'
          } else if $in < 3day {
            'chartreuse2b'
          } else if $in < 1wk {
            'green3b'
          } else if $in < 6wk {
            'darkturquoise'
          } else if $in < 52wk {
            'deepskyblue3b'
          } else { 'dark_gray' }
        }
        range: white
        float: white
        string: white
        nothing: white
        binary: white
        cellpath: white
        row_index: green_bold
        record: white
        list: white
        block: white
        hints: dark_gray

        shape_and: purple_bold
        shape_binary: purple_bold
        shape_block: blue_bold
        shape_bool: light_cyan
        shape_custom: green
        shape_datetime: cyan_bold
        shape_directory: cyan
        shape_external: cyan
        shape_externalarg: green_bold
        shape_filepath: cyan
        shape_flag: blue_bold
        shape_float: purple_bold
        # shapes are used to change the cli syntax highlighting
        shape_garbage: { fg: "#FFFFFF" bg: "#FF0000" attr: b}
        shape_globpattern: cyan_bold
        shape_int: purple_bold
        shape_internalcall: cyan_bold
        shape_list: cyan_bold
        shape_literal: blue
        shape_match_pattern: green
        shape_matching_brackets: { attr: u }
        shape_nothing: light_cyan
        shape_operator: yellow
        shape_or: purple_bold
        shape_pipe: purple_bold
        shape_range: yellow_bold
        shape_record: cyan_bold
        shape_redirection: purple_bold
        shape_signature: green_bold
        shape_string: green
        shape_string_interpolation: cyan_bold
        shape_table: blue_bold
        shape_variable: purple
    }

    # External completer example
    # let carapace_completer = {|spans|
    #     carapace $spans.0 nushell $spans | from json
    # }


    # The default config record. This is where much of your global configuration is setup.
    $env.config = {
      # true or false to enable or disable the welcome banner at startup
      show_banner: true
      ls: {
        use_ls_colors: true # use the LS_COLORS environment variable to colorize output
        clickable_links: true # enable or disable clickable links. Your terminal has to support links.
      }
      rm: {
        always_trash: false # always act as if -t was given. Can be overridden with -p
      }
      table: {
        mode: rounded # basic, compact, compact_double, light, thin, with_love, rounded, reinforced, heavy, none, other
        index_mode: always # "always" show indexes, "never" show indexes, "auto" = show indexes when a table has "index" column
        show_empty: true # show 'empty list' and 'empty record' placeholders for command output
        trim: {
          methodology: wrapping # wrapping or truncating
          wrapping_try_keep_words: true # A strategy used by the 'wrapping' methodology
          truncating_suffix: "..." # A suffix used by the 'truncating' methodology
        }
      }

      explore: {
        help_banner: true
        exit_esc: true

        command_bar_text: '#C4C9C6'
        # command_bar: {fg: '#C4C9C6' bg: '#223311' }

        status_bar_background: {fg: '#1D1F21' bg: '#C4C9C6' }
        # status_bar_text: {fg: '#C4C9C6' bg: '#223311' }

        highlight: {bg: 'yellow' fg: 'black' }

        status: {
          # warn: {bg: 'yellow', fg: 'blue'}
          # error: {bg: 'yellow', fg: 'blue'}
          # info: {bg: 'yellow', fg: 'blue'}
        }

        try: {
          # border_color: 'red'
          # highlighted_color: 'blue'

          # reactive: false
        }

        table: {
          split_line: '#404040'

          cursor: true

          line_index: true
          line_shift: true
          line_head_top: true
          line_head_bottom: true

          show_head: true
          show_index: true

          # selected_cell: {fg: 'white', bg: '#777777'}
          # selected_row: {fg: 'yellow', bg: '#C1C2A3'}
          # selected_column: blue

          # padding_column_right: 2
          # padding_column_left: 2

          # padding_index_left: 2
          # padding_index_right: 1
        }

        config: {
          cursor_color: {bg: 'yellow' fg: 'black' }

          # border_color: white
          # list_color: green
        }
      }

      history: {
        max_size: 10000 # Session has to be reloaded for this to take effect
        sync_on_enter: true # Enable to share history between multiple sessions, else you have to close the session to write history to file
        file_format: "plaintext" # "sqlite" or "plaintext"
      }
      completions: {
        case_sensitive: false # set to true to enable case-sensitive completions
        quick: true  # set this to false to prevent auto-selecting completions when only one remains
        partial: true  # set this to false to prevent partial filling of the prompt
        algorithm: "prefix"  # prefix or fuzzy
        external: {
          enable: true # set to false to prevent nushell looking into $env.PATH to find more suggestions, `false` recommended for WSL users as this look up my be very slow
          max_results: 100 # setting it lower can improve completion performance at the cost of omitting some options
          completer: null # check 'carapace_completer' above as an example
        }
      }
      filesize: {
        unit: "metric" # metric / binary
      }
      cursor_shape: {
        emacs: line # block, underscore, line (line is the default)
        vi_insert: block # block, underscore, line (block is the default)
        vi_normal: underscore # block, underscore, line  (underscore is the default)
      }
      color_config: $dark_theme   # if you want a light theme, replace `$dark_theme` to `$light_theme`
      footer_mode: "auto" # always, never, number_of_rows, auto
      float_precision: 2 # the precision for displaying floats in tables
      buffer_editor: "hx" # command that will be used to edit the current line buffer with ctrl+o, if unset fallback to $env.EDITOR and $env.VISUAL
      use_ansi_coloring: true
      edit_mode: vi # emacs, vi
      # shell_integration: true # enables terminal markers and a workaround to arrow keys stop working issue
      render_right_prompt_on_last_line: false # true or false to enable or disable right prompt to be rendered on last line of the prompt.

      hooks: {
        pre_prompt: [{||
          null  # replace with source code to run before the prompt is shown
        }]
        pre_execution: [{||
          null  # replace with source code to run before the repl input is run
        }]
        env_change: {
          PWD: [{|before, after|
            null  # replace with source code to run if the PWD environment is different since the last repl input
          }]
        }
        display_output: {||
          if (term size).columns >= 100 { table -e } else { table }
        }
        command_not_found: {||
          null  # replace with source code to return an error message when a command is not found
        }
      }
      menus: [
          # Configuration for default nushell menus
          # Note the lack of source parameter
          {
            name: completion_menu
            only_buffer_difference: false
            marker: "| "
            type: {
                layout: columnar
                columns: 4
                col_width: 20   # Optional value. If missing all the screen width is used to calculate column width
                col_padding: 2
            }
            style: {
                text: green
                selected_text: green_reverse
                description_text: yellow
            }
          }
          {
            name: history_menu
            only_buffer_difference: true
            marker: "? "
            type: {
                layout: list
                page_size: 10
            }
            style: {
                text: green
                selected_text: green_reverse
                description_text: yellow
            }
          }
          {
            name: help_menu
            only_buffer_difference: true
            marker: "? "
            type: {
                layout: description
                columns: 4
                col_width: 20   # Optional value. If missing all the screen width is used to calculate column width
                col_padding: 2
                selection_rows: 4
                description_rows: 10
            }
            style: {
                text: green
                selected_text: green_reverse
                description_text: yellow
            }
          }
          # Example of extra menus created using a nushell source
          # Use the source field to create a list of records that populates
          # the menu
          {
            name: commands_menu
            only_buffer_difference: false
            marker: "# "
            type: {
                layout: columnar
                columns: 4
                col_width: 20
                col_padding: 2
            }
            style: {
                text: green
                selected_text: green_reverse
                description_text: yellow
            }
            source: { |buffer, position|
                $nu.scope.commands
                | where name =~ $buffer
                | each { |it| {value: $it.name description: $it.usage} }
            }
          }
          {
            name: vars_menu
            only_buffer_difference: true
            marker: "# "
            type: {
                layout: list
                page_size: 10
            }
            style: {
                text: green
                selected_text: green_reverse
                description_text: yellow
            }
            source: { |buffer, position|
                $nu.scope.vars
                | where name =~ $buffer
                | sort-by name
                | each { |it| {value: $it.name description: $it.type} }
            }
          }
          {
            name: commands_with_description
            only_buffer_difference: true
            marker: "# "
            type: {
                layout: description
                columns: 4
                col_width: 20
                col_padding: 2
                selection_rows: 4
                description_rows: 10
            }
            style: {
                text: green
                selected_text: green_reverse
                description_text: yellow
            }
            source: { |buffer, position|
                $nu.scope.commands
                | where name =~ $buffer
                | each { |it| {value: $it.name description: $it.usage} }
            }
          }
      ]
      keybindings: [
        {
          name: completion_menu
          modifier: none
          keycode: tab
          mode: [emacs vi_normal vi_insert]
          event: {
            until: [
              { send: menu name: completion_menu }
              { send: menunext }
            ]
          }
        }
        {
          name: completion_previous
          modifier: shift
          keycode: backtab
          mode: [emacs, vi_normal, vi_insert] # Note: You can add the same keybinding to all modes by using a list
          event: { send: menuprevious }
        }
        {
          name: history_menu
          modifier: control
          keycode: char_r
          mode: vi_normal
          event: { send: menu name: history_menu }
        }
        {
          name: next_page
          modifier: control
          keycode: char_x
          mode: vi_normal
          event: { send: menupagenext }
        }
        {
          name: undo_or_previous_page
          modifier: control
          keycode: char_z
          mode: vi_normal
          event: {
            until: [
              { send: menupageprevious }
              { edit: undo }
            ]
           }
        }
        {
          name: yank
          modifier: control
          keycode: char_y
          mode: vi_normal
          event: {
            until: [
              {edit: pastecutbufferafter}
            ]
          }
        }
        {
          name: unix-line-discard
          modifier: control
          keycode: char_u
          mode: [emacs, vi_normal, vi_insert]
          event: {
            until: [
              {edit: cutfromlinestart}
            ]
          }
        }
        {
          name: kill-line
          modifier: control
          keycode: char_k
          mode: [emacs, vi_normal, vi_insert]
          event: {
            until: [
              {edit: cuttolineend}
            ]
          }
        }
        # Keybindings used to trigger the user defined menus
        {
          name: commands_menu
          modifier: control
          keycode: char_t
          mode: [emacs, vi_normal, vi_insert]
          event: { send: menu name: commands_menu }
        }
        {
          name: vars_menu
          modifier: alt
          keycode: char_o
          mode: [emacs, vi_normal, vi_insert]
          event: { send: menu name: vars_menu }
        }
        {
          name: commands_with_description
          modifier: control
          keycode: char_s
          mode: [emacs, vi_normal, vi_insert]
          event: { send: menu name: commands_with_description }
        }
      ]
    }
  '';
}
