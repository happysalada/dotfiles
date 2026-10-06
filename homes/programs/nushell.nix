{
  pkgs,
  config,
  lib,
  ...
}:
let
  # Only the commands carapace cannot complete. These define `extern`s, and
  # nushell prefers a known extern over the external completer, so anything
  # listed here shadows carapace - trading its live values (real branches, real
  # units) for a static flag list. `man` is here despite carapace shipping a man
  # completer, because that one shells out to `apropos` and needs a mandb index
  # this machine does not build (programs.man.generateCaches = false).
  #
  # NOTE: these are `use`d, which happens at PARSE time. A path that doesn't
  # exist aborts the whole of config.nu - silently taking starship, keybindings,
  # aliases and every custom command down with it. That is what the old
  # `tealdeer/tldr-completions.nu` entry was doing (upstream renamed the dir).
  completions = [
    "btm/btm-completions.nu"
    "man/man-completions.nu"
    "uv/uv-completions.nu"
    "zellij/zellij-completions.nu"
  ];

  useLines = builtins.concatStringsSep "\n" (
    map (c: "use ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/${c} *") completions
  );

  # home-manager's own integration regenerates this at every shell start;
  # building it once here keeps that off the startup path.
  intelliShellInit = pkgs.runCommand "intelli-shell-init.nu" { } ''
    # `init` insists on creating its data dir before printing anything, and
    # $HOME is not writable in the sandbox.
    export HOME="$PWD"
    ${config.programs.intelli-shell.package}/bin/intelli-shell init nushell > $out
  '';

  # mise's activation prints the environment it is generated in: $HOME decides
  # the shims dir it prepends, $PATH decides what it restores later. home-manager
  # generates it inside a build, where those are /homeless-shelter and stdenv's
  # PATH - every nushell then ran without the per-user profile, and with it atuin
  # and zoxide. common.nix turns that integration off; same command, real values.
  miseInit = pkgs.runCommand "mise-init.nu" { } ''
    # The login PATH from /etc/set-environment, in its order and complete. mise
    # records this list and restores it on every prompt, so anything left out is
    # missing from every nushell - /run/wrappers/bin above all, where the setuid
    # sudo lives, and without it sudo resolves to the non-setuid copy in the
    # system path and refuses to run.
    export PATH=/run/wrappers/bin:${config.home.homeDirectory}/.nix-profile/bin:/nix/profile/bin:${config.home.homeDirectory}/.local/state/nix/profile/bin:/etc/profiles/per-user/${config.home.username}/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin
    # mise warns it cannot create ~/.local/share/mise/migrations under a $HOME
    # that is read-only here; the activation it prints is the same either way.
    export HOME=${config.home.homeDirectory}
    ${config.programs.mise.package}/bin/mise activate nu > $out
  '';
in
{
  enable = true;
  package = pkgs.nushell;

  # Declarative plugin registry: home-manager builds plugin.msgpackz at build
  # time and links it into place, so there is no `plugin add` to run by hand and
  # nothing for the garbage collector to eat.
  #
  # Plugins are ABI-locked to the exact nushell version, and as of 0.115.0 these
  # four are the only nixpkgs ones built against it - skim, hcl, semver, highlight
  # and desktop_notifications are stale, net/units/dbus are marked broken.
  plugins = with pkgs.nushellPlugins; [
    formats # from/to ini, eml, vcf, ics, plist
    query # query json/xml/html with xpath + css selectors
    polars # dataframes; pairs well with qsv and tabiew
    gstat # git status as structured data
  ];

  envFile.text = ''
    # helix.nix's `defaultEditor` only writes EDITOR into hm-session-vars.sh, a
    # POSIX script nushell never sources - so yazi and friends fell through to
    # their `EDITOR-or-vi` default and opened vim.
    $env.EDITOR = "hx"
    $env.VISUAL = "hx"

    $env.NIXPKGS_ALLOW_UNFREE = 1

    # `crw search` from the shell. Without it crw falls back to its built-in
    # guess of 127.0.0.1:8080 and reports "could not connect to the backend".
    # The crw serve unit in homes/programs/crw.nix takes the same value.
    $env.CRW_SEARCH_BACKEND_URL = "http://127.0.0.1:8888"
  '';

  # Assigned leaf-by-leaf onto $env.config, so nushell's own defaults for
  # anything not named here stay intact. The old config replaced $env.config
  # wholesale with a snapshot of ~0.8x defaults, so every new upstream default
  # was silently discarded.
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
    gpf = "git push --force-with-lease";
    gl = "git log --pretty=oneline --abbrev-commit";
    gb = "git branch";
    gbd = "git branch --delete --force";
    c = "git checkout";
    gpp = "git pull --prune";
    gsi = "git stash --include-untracked";
    gsp = "git stash pop";
    gsa = "git stage --all";
    gu = "git reset --soft HEAD~1";
    grh = "git reset --hard";
    grm = "git rebase master";
    # misc
    st = "systemctl-tui";
    # codex for hyperresearch: `$deep-research` fetches sources, and the default
    # workspace-write sandbox in codex.nix has no network.
    codex-research = "codex -c sandbox_workspace_write.network_access=true";
    # GitHub hides "Releases only" watches from its API; this mines them out of
    # notification history and resets them. `list` first, then `reset --apply`.
    gh-release-unwatch = "nu ${./gh-release-unwatch.nu}";
  };

  extraConfig = ''
    ${useLines}

    # mise's activation is built in miseInit above rather than by home-manager,
    # whose copy bakes the build sandbox's HOME and PATH.
    source ${miseInit}

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
          # `$nu.scope` was removed in nushell 0.77; this is the modern form, and
          # the old config's use of it made these menus error on every use.
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

    ${lib.optionalString config.programs.intelli-shell.enable ''
      # Must be set before the source below, which reads it. Left unset,
      # intelli-shell binds ESC to "select all, delete" in vi_insert, and with
      # edit_mode = "vi" that turns leaving insert mode into wiping the line.
      $env.INTELLI_SKIP_ESC_BIND = "1"

      # ctrl-space -> search stored commands and tldr examples, ctrl-b to
      # bookmark one, ctrl-l to fill in variables, ctrl-x to fix a failed
      # command. Appends its own keybindings, so it composes with the block
      # above and with atuin's ctrl-r further down.
      source ${intelliShellInit}
    ''}

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

    # fetch a single branch from upstream. A bare `git fetch upstream` on a
    # repo like nixpkgs drags down every branch and tag for no benefit.
    def gfu [branch: string = "master"] {
      git fetch upstream $branch
    }

    # fast-forward the current branch onto upstream. --ff-only refuses loudly
    # instead of quietly creating a merge commit if you have local commits -
    # which is what you want when syncing a fork's master.
    def gmu [branch: string = "master"] {
      git fetch upstream $branch
      git merge --ff-only $"upstream/($branch)"
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

    # unreferenced store paths only - old generations are left to nix.gc (14d),
    # so a rollback target always survives
    def nixgc [] {
      nix store gc --verbose
      nix-collect-garbage
      sudo nix store gc --verbose
      sudo nix-collect-garbage
    }

    # deletes the branches already merged upstream
    def gbdm [] {
      git pull --prune
      git branch -vl | lines | split column " " BranchName Hash Status --collapse-empty | where Status == '[gone]' | each { |it| git branch -D $it.BranchName }
    }

    # build every machine config at once instead of one nixos-rebuild at a time.
    # `path:` reads the working tree, so untracked files are still visible.
    def nfb [dir: string = ".", ...rest] {
      nix-fast-build -f $"path:($dir | path expand)#nixosConfigurations" --no-link --select 'cfgs: builtins.mapAttrs (_: c: c.config.system.build.toplevel) cfgs' ...$rest
    }

    def nix_copy_inputs [to: string] {
      nix flake archive --json | from json | get inputs | transpose | each { |input| $input.column1.path | xargs nix copy --to $"ssh://($to)" }
    }

    # hold the laptop awake for the duration of one command. logind honours a
    # block lock on both paths that would otherwise cut a long job short:
    # `systemctl suspend` and closing the lid. The screen still blanks.
    def --wrapped keepawake [...cmd] {
      let why = ($cmd | str join " ")
      systemd-inhibit --what=sleep:handle-lid-switch --mode=block --who=keepawake --why $why ...$cmd
    }

    # citations alone can't rank a finance paper against a physics one. FWCI is
    # citations received over citations expected for the same year, type and
    # subfield, where 1.0 is world average - undefined below ~4 years old, the
    # window it is computed over, so it says nothing about a new preprint.
    # Lists every record because a paper's arXiv preprint and its published
    # version are separate rows and only the latter carries the citations;
    # mailto buys OpenAlex's faster "polite" pool.
    def fwci [title: string] {
      let q = ($title | url encode)
      http get $"https://api.openalex.org/works?filter=title.search:($q)&select=display_name,publication_year,type,cited_by_count,fwci,primary_location&per-page=10&mailto=openalex@megzari.com"
      | get results
      | select publication_year type cited_by_count fwci primary_location
      | update primary_location {|r| $r.primary_location.source?.display_name? }
      | rename year type cites fwci venue
      | sort-by -r cites
    }
  '';
}
