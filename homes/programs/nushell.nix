{ pkgs, ... }:
let
  # NOTE: these are `use`d, which happens at PARSE time. A path that doesn't
  # exist aborts the whole of config.nu - which silently takes starship,
  # keybindings, aliases and every custom command down with it. That's what the
  # old `tealdeer/tldr-completions.nu` entry was doing (upstream renamed the
  # directory to `tldr/`). Verified against nu_scripts 2026-07-19.
  completions = [
    "bat/bat-completions.nu"
    "btm/btm-completions.nu"
    "cargo/cargo-completions.nu"
    "curl/curl-completions.nu"
    "gh/gh-completions.nu"
    "git/git-completions.nu"
    "jj/jj-completions.nu"
    "man/man-completions.nu"
    "nix/nix-completions.nu"
    "rg/rg-completions.nu"
    "ssh/ssh-completions.nu"
    "tar/tar-completions.nu"
    "tldr/tldr-completions.nu"
    "uv/uv-completions.nu"
    "zellij/zellij-completions.nu"
    "zoxide/zoxide-completions.nu"
  ];


  useLines = builtins.concatStringsSep "\n" (
    map (c: "use ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/${c} *") completions
  );
in
{
  enable = true;
  package = pkgs.nushell;

  # Declarative plugin registry. home-manager builds plugin.msgpackz at build
  # time and links it into place, so there is no `plugin add` to run by hand and
  # nothing for the garbage collector to eat.
  #
  # Nushell plugins are ABI-locked to the exact nushell version. As of nushell
  # 0.115.0 these four are the only ones in nixpkgs built against it; skim
  # (0.114.0), hcl (0.114.1), semver (0.113.0), highlight and
  # desktop_notifications are all stale, and net/units/dbus are marked broken.
  # Re-test with `nu --plugin-config /tmp/t --commands 'plugin add <exe>'`
  # after a nixpkgs bump before adding any of them back.
  plugins = with pkgs.nushellPlugins; [
    formats # from/to ini, eml, vcf, ics, plist
    query # query json/xml/html with xpath + css selectors
    polars # dataframes; pairs well with qsv and tabiew
    gstat # git status as structured data
  ];

  envFile.text = ''
    $env.NIXPKGS_ALLOW_UNFREE = 1
  '';

  # Assigned leaf-by-leaf onto $env.config, so nushell's own defaults for
  # anything not named here stay intact. The old config replaced $env.config
  # wholesale with a snapshot of nushell ~0.8x defaults, which meant every new
  # upstream default was silently discarded.
  settings = {
    edit_mode = "vi";
    show_banner = false;
    buffer_editor = "hx";
    use_ansi_coloring = true;
    footer_mode = "auto";
    float_precision = 2;

    ls = {
      use_ls_colors = true;
      clickable_links = true;
    };

    rm.always_trash = false;

    table = {
      mode = "rounded";
      index_mode = "always";
      show_empty = true;
    };

    history = {
      max_size = 100000;
      sync_on_enter = true;
      # atuin is the real history store; sqlite is nushell's modern default
      file_format = "sqlite";
    };

    completions = {
      case_sensitive = false;
      quick = true;
      partial = true;
      algorithm = "fuzzy";
      external = {
        enable = true;
        max_results = 100;
      };
    };

    cursor_shape = {
      emacs = "line";
      vi_insert = "block";
      vi_normal = "underscore";
    };
  };

  shellAliases = {
    # nix
    nixroots = "nix-store --gc --print-roots";
    nci = "nix_copy_inputs";
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
  };

  extraConfig = ''
    ${useLines}

    # keybindings and menus are lists: append, never assign, or nushell's
    # defaults (and atuin's ctrl-r, sourced later) are lost
    $env.config.menus = ($env.config.menus | append [
      {
        name: commands_menu
        only_buffer_difference: false
        marker: "# "
        type: { layout: columnar, columns: 4, col_width: 20, col_padding: 2 }
        style: { text: green, selected_text: green_reverse, description_text: yellow }
        source: { |buffer, position|
          # `$nu.scope` was removed in nushell 0.77; this is the modern form.
          # The old config still used it, so these menus errored on every use.
          scope commands
          | where name =~ $buffer
          | each { |it| { value: $it.name, description: $it.description } }
        }
      }
      {
        name: vars_menu
        only_buffer_difference: true
        marker: "# "
        type: { layout: list, page_size: 10 }
        style: { text: green, selected_text: green_reverse, description_text: yellow }
        source: { |buffer, position|
          scope variables
          | where name =~ $buffer
          | sort-by name
          | each { |it| { value: $it.name, description: $it.type } }
        }
      }
    ])

    $env.config.keybindings = ($env.config.keybindings | append [
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
        name: unix-line-discard
        modifier: control
        keycode: char_u
        mode: [emacs, vi_normal, vi_insert]
        event: { until: [{ edit: cutfromlinestart }] }
      }
      {
        name: kill-line
        modifier: control
        keycode: char_k
        mode: [emacs, vi_normal, vi_insert]
        event: { until: [{ edit: cuttolineend }] }
      }
    ])

    # https://www.nushell.sh/book/coloring_and_theming.html
    $env.config.color_config = {
      separator: white
      leading_trailing_space_bg: { attr: n }
      header: green_bold
      empty: blue
      bool: {|| if $in { 'light_cyan' } else { 'light_gray' } }
      int: white
      filesize: {|e|
        if $e == 0b { 'white' } else if $e < 1mb { 'cyan' } else { 'blue' }
      }
      duration: white
      date: {|| (date now) - $in |
        if $in < 1hr { 'red3b'
        } else if $in < 6hr { 'orange3'
        } else if $in < 1day { 'yellow3b'
        } else if $in < 3day { 'chartreuse2b'
        } else if $in < 1wk { 'green3b'
        } else if $in < 6wk { 'darkturquoise'
        } else if $in < 52wk { 'deepskyblue3b'
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
      shape_garbage: { fg: "#FFFFFF" bg: "#FF0000" attr: b }
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

    # sudo version cleans system generations, non-sudo cleans home-manager
    def nixgc [] {
      nix store gc --verbose
      nix-collect-garbage -d
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
  '';
}
