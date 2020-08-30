{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.programs.doom;

  formatModules = mods:
    concatStringsSep "\n  " (mapAttrsToList (formatModule) mods);

  formatModuleWithOpts = name: features:
    let
      fts = mapAttrsToList (k: v: if v then " +${k}" else "") features;
      args = [ name ] ++ fts;
    in "(${concatStrings args})";

  formatModule = name: opts:
    let
      comment = if opts.enabled then "" else ";; ";
      body = if opts.features != { } then
        formatModuleWithOpts name opts.features
      else
        name;
    in "${comment}${body}";

  enabled = description: features: {
    enabled = mkOption {
      type = types.bool;
      inherit description;
      default = true;
    };
    inherit features;
  };

  disabled = description: features: {
    enabled = mkOption {
      type = types.bool;
      inherit description;
      default = false;
    };
    inherit features;
  };

  feature = default: description:
    mkOption {
      type = types.bool;
      inherit default description;
    };

in {
  options.programs.doom = {
    enable = mkEnableOption "Doom Emacs";

    modules = {

      input = {
        chinese = disabled "Chinese input support" { };
        japanese = disabled "Japenese input support" { };
      };

      completion = {
        company = enabled "the ultimate code completion backend" { };
        helm = disabled "the *other* search engine for love and life" { };
        ido = disabled "the other *other* search engine..." { };
        ivy = enabled "a search engine for love and life" {
          fuzzy = feature false null;
          prescient = feature false null;
        };
      };

      ui = {
        deft = disabled "notational velocity for Emacs" { };
        doom = enabled "what makes DOOM look the way it does" { };
        doom-dashboard = enabled "a nifty splash screen for Emacs" { };
        doom-quit = enabled "DOOM quit-message prompts when you quit Emacs" { };
        fill-column = disabled "a `fill-column' indicator" { };
        hl-todo =
          enabled "highlight TODO/FIXME/NOTE/DEPRECATED/HACK/REVIEW" { };
        hydra = disabled null { };
        indent-guides = disabled "highlighted indent columns" { };
        modeline = enabled "snazzy, Atom-inspired modeline, plus API" { };
        nav-flash = enabled "blink the current line after jumping" { };
        neotree = disabled "a project drawer, like NERDTree for vim" { };
        ophints = enabled "highlight the region an operation acts on" { };
        popup = enabled "tame sudden yet inevitable temporary windows" {
          all = feature true "catch all popups that start with an asterisk";
          defaults = feature true "default popup rules";
        };
        pretty-code = disabled "replace bits of code with pretty symbols" {
          fira = feature false null;
          iosevka = feature false null;
          hasklig = feature false null;
          pragmata-pro = feature false null;
        };
        tabs = disabled "an tab bar for Emacs" { };
        treemacs = disabled "a project drawer, like neotree but cooler" { };
        unicode = disabled "extended unicode support for various languages" { };
        vc-gutter = enabled "vcs diff in the fringe" { };
        vi-tilde-fringe = enabled "fringe tildes to mark beyond EOB" { };
        window-select = enabled "visually switch windows" { };
        workspaces =
          enabled "tab emulation, persistence & separate workspaces" { };
      };

      editor = {
        evil = enabled "come to the dark side, we have cookies" {
          everywhere = feature true null;
        };
        file-templates = enabled "auto-snippets for empty files" { };
        fold = enabled "(nigh) universal code folding" { };
        format =
          disabled "automated prettiness" { onsave = feature true null; };
        god = disabled "run Emacs commands without modifier keys" { };
        lispy = disabled "vim for lisp, for people who don't like vim" { };
        multiple-cursors = enabled "editing in many places at once" { };
        objed = disabled "text object editing for the innocent" { };
        parinfer = disabled "turn lisp into python, sort of" { };
        rotate-text =
          enabled "cycle region at point between text candidates" { };
        snippets = enabled "my elves. They type so I don't have to" { };
        word-wrap = disabled "soft wrapping with language-aware indent" { };
      };

      emacs = {
        dired = enabled "making dired pretty [functional]" { };
        electric = enabled "smarter, keyword-based electric-indent" { };
        ibuffer = enabled "interactive buffer management" { };
        vc = enabled "version-control and Emacs, sitting in a tree" { };
      };

      term = {
        eshell = enabled "a consistent, cross-platform shell (WIP)" { };
        shell = disabled "a terminal REPL for Emacs" { };
        term = disabled "terminals in Emacs" { };
        vterm = disabled "another terminals in Emacs" { };
      };

      tools = {
        ansible = disabled null { };
        debugger =
          disabled "FIXME stepping through code, to help you add bugs" { };
        direnv = disabled null { };
        docker = disabled null { };
        editorconfig =
          disabled "let someone else argue about tabs vs spaces" { };
        ein = disabled "tame Jupyter notebooks with emacs" { };
        eval = (enabled "run code, run also, repls") {
          overlay = feature true null;
        };
        flycheck = enabled "tasing you for every semicolon you forget" { };
        flyspell = disabled "tasing you for misspelling mispelling" { };
        gist = disabled "interacting with github gists" { };
        lookup = enabled "helps you navigate your code and documentation" {
          docsets = feature true "...or in Dash docsets locally";
        };
        lsp = disabled null { };
        macos = enabled "MacOS-specific commands" { };
        magit = enabled "a git porcelain for Emacs" { };
        make = disabled "run make tasks from Emacs" { };
        pass = disabled "password manager for nerds" { };
        pdf = disabled "pdf enhancements" { };
        prodigy =
          disabled "FIXME managing external services & code builders" { };
        rgb = disabled "creating color strings" { };
        terraform = disabled "infrastructure as code" { };
        tmux = disabled "an API for interacting with tmux" { };
        upload = disabled "map local to remote projects via ssh/ftp" { };
        wakatime = disabled null { };
      };

      lang = {
        agda = disabled "types of types of types of types..." { };
        assembly = disabled "assembly for fun or debugging" { };
        cc = disabled "C/C++/Obj-C madness" { };
        clojure = disabled "java with a lisp" { };
        common-lisp =
          disabled "if you've seen one lisp, you've seen them all" { };
        coq = disabled "proofs-as-programs" { };
        crystal = disabled "ruby at the speed of c" { };
        csharp = disabled "unity, .NET, and mono shenanigans" { };
        data = enabled "config/data formats" { };
        elixir = disabled "erlang done right" { };
        elm = disabled "care for a cup of TEA?" { };
        emacs-lisp = enabled "drown in parentheses" { };
        erlang = disabled "an elegant language for a more civilized age" { };
        ess = disabled "emacs speaks statistics" { };
        faust = disabled "dsp, but you get to keep your soul" { };
        fsharp = disabled "ML stands for Microsoft's Language" { };
        go = disabled "the hipster dialect" { };
        haskell = disabled "a language that's lazier than I am" {
          intero = feature true null;
        };
        hy = disabled "readability of scheme w/ speed of python" { };
        idris = disabled "idris" { };
        java = disabled "the poster child for carpal tunnel syndrome" {
          meghanaga = feature true null;
        };
        javascript = disabled "all(hope(abandon(ye(who(enter(here))))))" { };
        julia = disabled "a better, faster MATLAB" { };
        kotlin = disabled "a better, slicker Java(Script)" { };
        latex = disabled "writing papers in Emacs has never been so fun" { };
        lean = disabled "lean" { };
        ledger = disabled "an accounting system in Emacs" { };
        lua = disabled "one-based indices? one-based indices" { };
        markdown = enabled "writing docs for people to ignore" { };
        nim = disabled "python + lisp at the speed of c" { };
        nix = enabled ''I hereby declare "nix geht mehr!"'' { };
        ocaml = disabled "an objective camel" { };
        org = enabled "organize your plain life in plain text" {
          dragndrop = feature true "drag & drop files/images into org buffers";
          hugo = feature false "use Emacs for hugo blogging";
          ipython = feature true "ipython/jupyter support for babel";
          pandoc = feature true "export-with-pandoc support";
          pomodoro = feature false "be fruitful with the tomato technique";
          present = feature true "using org-mode for presentations";
        };
        perl = disabled "write code no one else can comprehend" { };
        php = disabled "perl's insecure younger brother" { };
        plantuml = disabled "diagrams for confusing people more" { };
        purescript = disabled "javascript, but functional" { };
        python = disabled "beautiful is better than ugly" { };
        qt = disabled "the 'cutest' gui framework ever" { };
        racket = disabled "a DSL for DSLs" { };
        rest = disabled "Emacs as a REST client" { };
        rst = disabled "ReST in peace" { };
        ruby =
          disabled ''1.step {|i| p "Ruby is #{i.even? ? 'love' : 'life'}"}''
          { };
        rust = disabled "Fe2O3.unwrap().unwrap().unwrap().unwrap()" { };
        scala = disabled "java, but good" { };
        scheme = disabled "a fully conniving family of lisps" { };
        sh = enabled "she sells {ba,z,fi}sh shells on the C xor" { };
        solidity = disabled "do you need a blockchain? No." { };
        swift = disabled "who asked for emoji variables?" { };
        terra = disabled "Earth and Moon in alignment for performance." { };
        web = disabled "the tubes" { };
      };

      email = {
        mu4e = disabled null { gmail = feature true null; };
        notmuch = disabled null { };
        wanderlust = disabled null { gmail = feature true null; };
      };

      app = {
        calendar = disabled null { };
        irc = disabled "how neckbeards socialize" { };
        rss = disabled "emacs as an RSS reader" { org = feature true null; };
        twitter = disabled "twitter client https://twitter.com/vnought" { };
        write = disabled "emacs for writers (fiction, notes, papers, etc.)" { };
      };

      config = {
        literate = disabled null { };
        default = enabled null {
          bindings = feature true null;
          smartparens = feature true null;
        };
      };

    };

    packages = mkOption { type = types.str; };
    config = mkOption { type = types.str; };
  };

  config = mkIf cfg.enable {
    home.file.".doom.d/init.el".text = ''
      (doom!
        :input
        ${formatModules cfg.modules.input}
        :completion
        ${formatModules cfg.modules.completion}
        :ui
        ${formatModules cfg.modules.ui}
        :editor
        ${formatModules cfg.modules.editor}
        :emacs
        ${formatModules cfg.modules.emacs}
        :term
        ${formatModules cfg.modules.term}
        :tools
        ${formatModules cfg.modules.tools}
        :lang
        ${formatModules cfg.modules.lang}
        :email
        ${formatModules cfg.modules.email}
        :app
        ${formatModules cfg.modules.app}
        :config
        ${formatModules cfg.modules.config}
        )
    '';
    home.file.".doom.d/packages.el".text = cfg.packages;
    home.file.".doom.d/config.el".text = cfg.config;
  };
}