# reasonix - the DeepSeek-native terminal agent, wired to the same shared sources
# the other three clients read (ai-mcp, ai-context, ai-agents, ai-skills, plus
# the CLI tools in packages/ai.nix).
#
# Everything it generates is read-only, so `reasonix setup`, `reasonix mcp add`,
# the desktop settings page and `reasonix subagent create` all fail and every
# change comes through here plus a rebuild. Rendered twice, for the two homes:
# ~/.reasonix for `reasonix` and ~/.reasonix-nono for `nono-reasonix`, which
# differ in `sandbox.bash` alone.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  # Subagent roles, shared with claude-code, codex and opencode.
  aiAgents = import ./ai-agents.nix { inherit lib pkgs; };

  # A fourth rendering of ai-context.nix rather than a symlink to one of the
  # others: reasonix loads global instructions out of its own home directory,
  # whichever of REASONIX.md, AGENTS.md or CLAUDE.md it finds there.
  aiContext = import ./ai-context.nix { inherit lib; };

  # The same skill set the other three get, from the same single source.
  aiSkills = import ./ai-skills.nix { inherit pkgs; };

  # Claude Code's `allowed-tools` vocabulary is not a known tool identity in
  # reasonix, which warns about each name and ignores the list - hence the
  # translated copies under ~/.reasonix/skills. An unmapped name is passed
  # through with a build warning rather than dropped, so a source bump surfaces
  # here, in the file that has to be edited.
  toolNames = {
    Read = "read_file";
    Write = "write_file";
    Edit = "edit_file";
    Bash = "bash";
    Glob = "glob";
    Grep = "grep";
  };

  translateToolName =
    name:
    toolNames.${name}
      or (lib.warn "reasonix: no reasonix identity for allowed-tools ${name}; passing it through unmapped" name);

  # `Read Write Edit Bash` becomes the flow list `[read_file, write_file,
  # edit_file, bash]` that reasonix's own profile editor writes. The value
  # arrives space- or comma-separated and sometimes quoted, so the quotes come
  # off only after the whitespace following the colon - a leading space would
  # leave the opening quote attached to the first name. The separator appears in
  # builtins.split's output as an empty list between the names.
  translateAllowedTools =
    line:
    let
      value = lib.trim (builtins.head (builtins.match "allowed-tools:[[:space:]]*(.*)" line));
      names = lib.filter (name: name != "") (
        lib.filter builtins.isString (
          builtins.split "[,[:space:]]+" (lib.removeSuffix "\"" (lib.removePrefix "\"" value))
        )
      );
    in
    "allowed-tools: [${lib.concatStringsSep ", " (map translateToolName names)}]";

  # A skill lands in ~/.reasonix/skills as itself unless it needs that rewrite, in
  # which case the whole directory is copied so scripts/ and references/ come
  # along. Skills that come from a package rather than a source tree (revdiff,
  # hyperresearch's deep-research and terminal-browser) are read out of their
  # built store paths, so this evaluation depends on them.
  renderSkill =
    name: src:
    if !(lib.hasInfix "allowed-tools:" (builtins.readFile "${src}/SKILL.md")) then
      src
    else
      pkgs.runCommand "reasonix-skill-${name}" { } ''
        mkdir -p $out
        cp -r --no-preserve=mode,ownership ${src}/. $out/
        cp --no-preserve=mode ${
          pkgs.writeText "SKILL.md" (
            lib.concatStringsSep "\n" (
              map (line: if lib.hasPrefix "allowed-tools:" line then translateAllowedTools line else line) (
                lib.splitString "\n" (builtins.readFile "${src}/SKILL.md")
              )
            )
          )
        } $out/SKILL.md
      '';

  # The MCP registry in reasonix's `[[plugins]]` dialect - Home Manager renders
  # the other three but not this one. Reading programs.mcp.servers back rather
  # than relisting the servers means anything registered with the tool-agnostic
  # programs.mcp reaches reasonix with nothing to keep in sync.
  #
  # `url` is remote (Streamable HTTP, which those three speak) and `command` a
  # subprocess. Empty args/env are dropped because they are the zero values in
  # TOML, and stdio is the default `type`, so it stays implicit.
  plugins = lib.mapAttrsToList (
    name: server:
    {
      inherit name;
    }
    // (
      if server.url != null then
        {
          type = "http";
          inherit (server) url;
        }
        // lib.optionalAttrs (server.headers != { }) { inherit (server) headers; }
      else
        {
          inherit (server) command;
        }
        // lib.optionalAttrs (server.args != [ ]) { inherit (server) args; }
        // lib.optionalAttrs (server.env != { }) { inherit (server) env; }
    )
  ) (lib.filterAttrs (_: server: server.enabled != false) config.programs.mcp.servers);

  # The same seven language servers, at the same store paths with the same
  # arguments as claude-code.nix's lspServers, so the agent and the editor can
  # never disagree about a version. Keeping typescript-language-server on a store
  # path is also what stops reasonix offering its `npm i -g` fallback, which on
  # NixOS would land a second copy outside the store.
  lspServers = with pkgs; {
    nixd = {
      command = "${nixd}/bin/nixd";
      extensions = [ ".nix" ];
    };
    rust-analyzer = {
      command = "${rust-analyzer-unwrapped}/bin/rust-analyzer";
      extensions = [ ".rs" ];
    };
    ty = {
      command = "${ty}/bin/ty";
      args = [ "server" ];
      extensions = [ ".py" ];
    };
    typescript-language-server = {
      command = "${typescript-language-server}/bin/typescript-language-server";
      args = [ "--stdio" ];
      extensions = [
        ".ts"
        ".tsx"
        ".js"
        ".jsx"
      ];
    };
    svelteserver = {
      command = "${svelte-language-server}/bin/svelteserver";
      args = [ "--stdio" ];
      extensions = [ ".svelte" ];
    };
    # nushell is the scripting language here, and ships its own server.
    nu = {
      command = "${nushell}/bin/nu";
      args = [ "--lsp" ];
      extensions = [ ".nu" ];
    };
    taplo = {
      command = "${taplo}/bin/taplo";
      args = [
        "lsp"
        "stdio"
      ];
      extensions = [ ".toml" ];
    };
  };

  # Carried over verbatim from the `reasonix setup` scaffold this replaces, so the
  # desktop app keeps the preferences it was configured with. Two values are
  # deliberately not what the scaffold wrote: check_updates is off because the
  # store path is read-only, so an update can only be a nag (bump the llm-agents
  # input instead), and the telemetry/metrics pair is off to match the CLI
  # metrics setting below and the REASONIX_TELEMETRY=0 the wrapper sets.
  desktop = {
    layout_style = "workbench";
    theme = "auto";
    terminal_theme = "auto";
    close_behavior = "background";
    status_bar_style = "icon";
    status_bar_style_initialized = true;
    status_bar_items = [
      "model"
      "workspace"
      "git_branch"
      "cache"
      "cache_avg"
      "session_tokens"
      "turn_tokens"
      "turn_tps"
      "turn_output_tokens"
      "turn_cache_tokens"
      "turn_cost"
      "session_turns"
      "context"
      "compact"
      "cost"
      "balance"
    ];
    default_tool_approval_mode = "workspace-write";
    check_updates = false;
    telemetry = false;
    metrics = false;
    expand_thinking = false;
    display_mode = "standard";
  };

  # DeepSeek direct, one entry per model, which is what /model switches between.
  # The key itself is never here: agenix decrypts DEEPSEEK_API_KEY to
  # ~/.reasonix/.env and `api_key_env` names it. Prices are per 1M tokens and only
  # feed the cost readout; balance_url is what the status bar's balance item reads.
  deepseek = name: model: price: {
    inherit name model;
    kind = "openai";
    base_url = "https://api.deepseek.com";
    api_key_env = "DEEPSEEK_API_KEY";
    balance_url = "https://api.deepseek.com/user/balance";
    context_window = 1000000;
    inherit price;
    billing_currency = "USD";
    thinking = "enabled";
    web_search = true;
    # Every effort a subagent carries has to be one of these or reasonix only
    # warns and drops it - see the efforts table in ai-agents.nix.
    supported_efforts = [
      "disabled"
      "low"
      "high"
      "max"
    ];
    default_effort = "high";
  };

  settings = {
    # 12 is the schema marker for diagnostics; an old version ignores it.
    config_version = 12;
    default_model = "deepseek-flash";
    credentials_store = "auto";

    ui = {
      theme = "auto";
      show_turn_usage = true;
    };

    inherit desktop;

    notifications = {
      enabled = false;
      turn_done = true;
      approval_request = true;
      ask_request = true;
    };

    # `auto`, the default, turns metrics on whenever the terminal is interactive,
    # which is how this tool is used here. The wrapper in machines/strix/default.nix
    # sets REASONIX_TELEMETRY=0; this is the same switch for other launches.
    telemetry.cli_metrics = "off";

    # Inert while proxy_mode is auto/env - carried because they were active in
    # the scaffold, so switching to `custom` does not need a second visit here.
    network = {
      proxy_mode = "auto";
      proxy.type = "socks5";
    };

    environment = {
      enabled = true;
      offline = false;
    };

    agent = {
      temperature = 0.0;
      # The only automatic compaction trigger: near this fraction of the
      # provider's context window.
      compact_ratio = 0.8;
      # subagent_model / subagent_effort stay unset, so a subagent naming neither -
      # the four built-ins - inherits default_model. The roles in
      # ~/.reasonix/skills carry their own model and effort, which outranks both.
    };

    providers = [
      (deepseek "deepseek-flash" "deepseek-flash" {
        cache_hit = 0.006;
        input = 0.3;
        output = 1.2;
        currency = "$";
      })
      (deepseek "deepseek-pro" "deepseek-v4-pro" {
        cache_hit = 0.044;
        input = 1.32;
        output = 3.96;
        currency = "$";
      })
    ];

    tools = {
      # Empty means every built-in tool is enabled.
      enabled = [ ];
      bash_timeout_seconds = 120;
      mcp_startup_timeout_seconds = 30;
      mcp_call_timeout_seconds = 300;
      background_jobs.stalled_warning_seconds = 900;
    };

    lsp = {
      enabled = true;
      servers = lspServers;
    };

    # Off: crw is the browser on this machine, already wired above, and it is the
    # one sharing a renderer between sessions.
    browser.enabled = false;

    # The ~/.claude/skills copy - the one the other three clients need, carrying
    # Claude Code's tool names - is excluded, because reading both roots would
    # leave two definitions of every skill, one of them the source of the doctor
    # warnings the translated copies exist to remove. Only the home root: a
    # project's `.claude/skills`, which `hyperresearch install` writes, still loads.
    skills.excluded_paths = [ "~/.claude/skills" ];

    # The Git section of ai-context.nix, enforced rather than merely asked for -
    # the same denies claude-code.nix, codex.nix and opencode.nix carry. `:*` is
    # reasonix's command-prefix form, and a prefix rule refuses a later command
    # that introduces a shell operator, so `Bash(git push:*)` does not also cover
    # `git push && rm -rf .`. The legacy `Bash(git push*)` spelling still loads.
    #
    # Not airtight, same as the other three: the pattern is a literal prefix, so
    # `git -c user.name=x commit` slips past, and the prose in ai-context.nix is
    # still what carries the rule. mode stays "ask" - `reasonix run` and
    # `reasonix -p` cannot prompt, so an unmatched command there fails closed
    # rather than running, which is why the headless lanes (orx, hyperresearch)
    # still belong to codex and claude-code. Their blanket approvals would be
    # mode = "allow"; the denies below still win in that mode.
    permissions = {
      mode = "ask";
      deny = [
        "Bash(git add:*)"
        "Bash(git commit:*)"
        "Bash(git push:*)"
        "Bash(git reset:*)"
        "Bash(git restore:*)"
        "Bash(git stash:*)"
      ];
      # `git checkout -b` is fine when asked for, `git checkout -- path` destroys
      # work. One prefix cannot tell them apart, so this one prompts.
      ask = [ "Bash(git checkout:*)" ];
    };

    # The .env block opencode.nix carries as read."*.env" and claude-code.nix as
    # Read(**/.env), done the way reasonix implements it: the read tools hide .env,
    # .git-credentials, key files and ~/.ssh rather than a path glob matching
    # them. Broader than the other two, and as its own config comment warns, able
    # to get in the way of a legitimate read of one of those files.
    secrets.protect_sensitive_files = true;

    # The bot gateway (QQ, Feishu, WeChat) stays off, and the rest of its settings
    # are left at reasonix's defaults rather than carried over as a wall of empty
    # allowlists.
    bot.enabled = false;

    sandbox = {
      # bubblewrap jail for every bash call, with egress allowed so `nix build`
      # and crw still work. Writers are confined to the workspace root; add
      # `allow_write` here if a writer has to reach further.
      bash = "enforce";
      network = true;
    };
  }
  // lib.optionalAttrs (plugins != [ ]) { inherit plugins; };

  # The ~/.reasonix-nono copy of `settings`, identical but for one value, which is
  # the entire reason that home exists. nono's Landlock ruleset grants /proc/<pid>
  # read-only and bubblewrap has to write /proc/self/uid_map, so `bash = "enforce"`
  # cannot start inside a nono session: it fails with "bwrap: setting up uid map:
  # Permission denied", and reasonix then refuses to run bash rather than falling
  # back. Pointing REASONIX_HOME here is what leaves plain `reasonix` with the
  # jail it has always had.
  sandboxed = settings // {
    sandbox = settings.sandbox // {
      bash = "off";
    };
  };

  instructions = pkgs.writeText "REASONIX.md" (aiContext.mkContext { tool = "reasonix"; });

  # The global Skill root is also reasonix's profile root, which is why the roles
  # land beside the skills - see the reasonix renderer in ai-agents.nix. Rendered
  # twice, once per home.
  renderHome =
    dir: cfg:
    {
      "${dir}/config.toml".source = (pkgs.formats.toml { }).generate "reasonix-config" cfg;
    }
    // lib.mapAttrs' (
      name: text: lib.nameValuePair "${dir}/skills/${name}/SKILL.md" { inherit text; }
    ) (aiAgents.mkAgents { tool = "reasonix"; })
    // lib.mapAttrs' (
      name: src: lib.nameValuePair "${dir}/skills/${name}" { source = renderSkill name src; }
    ) aiSkills;
in
{
  home.file = renderHome ".reasonix" settings // renderHome ".reasonix-nono" sandboxed;

  # The instructions file cannot be a home.file entry: that symlinks it into the
  # store, and reasonix ignores an instruction document whose symlink resolves
  # outside its own home ("rejected instruction document ... outside boundary").
  # A symlink to a file inside ~/.reasonix loads and a store symlink does not -
  # measured, not assumed. So these are installed as real files at the same 444
  # the store would give them, and rewritten on every activation. Both homes,
  # because "its own home" is now whichever REASONIX_HOME names.
  #
  # Nothing else here has that problem: the config loads from a store symlink,
  # and so do the skill directories.
  home.activation.reasonixInstructions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD install -m 444 -D $VERBOSE_ARG ${instructions} "$HOME/.reasonix/REASONIX.md"
    $DRY_RUN_CMD install -m 444 -D $VERBOSE_ARG ${instructions} "$HOME/.reasonix-nono/REASONIX.md"
  '';
}
