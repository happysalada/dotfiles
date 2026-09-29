# reasonix - the DeepSeek-native terminal agent, wired to the same tooling the
# other three clients get instead of being left as a bare binary on PATH.
#
# Everything shared comes through the source that already owns it: MCP servers
# read back out of programs.mcp.servers (the five in ai-mcp.nix, plus crw, which
# registers itself beside the port its unit listens on), global instructions and
# subagent roles rendered from ai-context.nix and ai-agents.nix, the skill set
# from ai-skills.nix, and the CLI tools on PATH from packages/ai.nix.
#
# Not shared: hooks. reasonix defines its own hook events, none are wired here,
# and neither `rtk hook` nor `icm hook` has a reasonix backend - so no output
# compression and no icm wake-up pack in a reasonix session. The Git rules
# survive as permission.deny below and the .env block as `secrets`.
#
# NOTE: this file generates three things under ~/.reasonix. Two are store
# symlinks - config.toml and the skill directories - and the third, the
# instructions file, has to be copied by an activation instead, because reasonix
# ignores an instruction document whose symlink resolves outside its own home.
# Either way they are read-only, so `reasonix setup`, `reasonix mcp add`, the
# desktop settings page and `reasonix subagent create --scope global` now fail
# and every change has to come through here plus a rebuild. The first activation
# renames the hand-written config.toml to config.toml.hm-bak rather than
# deleting it.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  # Subagent roles, shared with claude-code, codex and opencode.
  aiAgents = import ./ai-agents.nix { inherit lib pkgs; };

  # Global instructions, shared with the other three. reasonix loads user-global
  # instructions out of its own home directory - REASONIX.md, AGENTS.md or
  # CLAUDE.md, whichever it finds there - so this is a fourth rendering of
  # ai-context.nix rather than a symlink to one of the other three.
  aiContext = import ./ai-context.nix { inherit lib; };

  # The same skill set the other three get, from the same single source.
  aiSkills = import ./ai-skills.nix { inherit pkgs; };

  # Some of those skills carry `allowed-tools` in Claude Code's vocabulary,
  # which is not a known tool identity in reasonix - it warns about each one and
  # ignores the list, so the whitelist is silently inert. Translating it is what
  # the copies under ~/.reasonix/skills are for.
  #
  # An unmapped name is passed through with a build warning rather than dropped:
  # a source bump that introduces one should surface here, in the file that has
  # to be edited, not as a doctor warning nobody reads.
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

  # `allowed-tools: Read Write Edit Bash` becomes `allowed-tools: [read_file,
  # write_file, edit_file, bash]` - the flow list reasonix's own profile editor
  # writes. The value arrives space- or comma-separated and sometimes quoted
  # (shap writes `"Read Bash"`), so the quotes come off only after the whitespace
  # that follows the colon: a leading space would otherwise leave the opening
  # quote attached to the first name. The separator shows up in builtins.split's
  # output as an empty list between the names.
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

  # A skill lands in ~/.reasonix/skills as itself unless it needs that
  # translation, in which case it is copied with only SKILL.md rewritten. The
  # copy is of the whole directory, not of the file alone: several of these
  # skills ship scripts/ and references/ beside their SKILL.md.
  #
  # Note the two skills that come from a package rather than from a source tree
  # (revdiff and hyperresearch's deep-research) are read out of their built
  # store paths here, so this evaluation depends on them.
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

  # The MCP registry, in reasonix's `[[plugins]]` dialect. Reading
  # programs.mcp.servers back rather than listing the servers again means
  # anything registered with home-manager's tool-agnostic programs.mcp - by
  # ai-mcp.nix or by a module that owns its own endpoint - reaches reasonix with
  # nothing to keep in sync. Home Manager renders the claude-code, codex and
  # opencode dialects itself but has no reasonix one, so this is that dialect.
  #
  # A `url` entry is remote and a `command` entry is a subprocess. Reasonix's
  # `http` transport is Streamable HTTP, which is what those three urls speak.
  # Empty args/env are dropped because they are the zero values in TOML and
  # `reasonix mcp add` writes the same shape. `type = "stdio"` is the default,
  # so it is left implicit.
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
  # never disagree about a version. `extensions` is reasonix's spelling of
  # Claude Code's extensionToLanguage map. Servers launch lazily on first use.
  #
  # It also keeps reasonix off its npm fallback: when it cannot find a
  # typescript-language-server it offers `npm i -g typescript-language-server
  # typescript`, which on NixOS would land a second copy outside the store. The
  # store path above is what it finds instead.
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

  # Carried over verbatim from the `reasonix setup` scaffold this replaces, so
  # the desktop app keeps the preferences it was configured with. Two values are
  # deliberately not what the scaffold wrote:
  #
  #   - check_updates is off, for the same reason codex.nix sets
  #     check_for_update_on_startup = false and opencode.nix sets
  #     autoupdate = false: the store path is read-only, so an update can only
  #     be a nag. Bump packages/ai/reasonix.nix instead.
  #   - desktop telemetry/metrics are off, matching both the CLI metrics setting
  #     below and the REASONIX_TELEMETRY=0 the package wrapper sets.
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
  # ~/.reasonix/.env (machines/strix/default.nix) and `api_key_env` names it.
  # Prices are per 1M tokens and only feed the cost readout - balance_url is
  # what the status bar's balance item reads.
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
    # The levels /effort offers for this provider. Every effort a subagent
    # carries has to be one of these or reasonix only warns and drops it -
    # see the efforts table in ai-agents.nix.
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

    # Content-free CLI usage metrics, off. `auto` - the default - turns them on
    # whenever the terminal is interactive, which is how this tool is used here.
    # The package wrapper already sets REASONIX_TELEMETRY=0 in
    # packages/ai/reasonix.nix; this is the same switch for when it is launched
    # some other way.
    telemetry.cli_metrics = "off";

    # Proxy settings are inert while proxy_mode is auto/env - carried because
    # they were active in the scaffold, so switching to `custom` does not need
    # a second visit to this file.
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
      # subagent_model / subagent_effort stay unset, so a subagent that names
      # neither - the four built-ins - inherits default_model. The three roles
      # in ~/.reasonix/skills/ carry their own model and effort, which outranks
      # both of those settings.
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

    # The CLI's own browser tools stay off: crw is the browser on this machine,
    # already wired above, and it is the one sharing a renderer between sessions.
    browser.enabled = false;

    # reasonix also finds these skills through ~/.claude/skills, one of its
    # convention roots. That copy is excluded because it is the one the other
    # three clients need - Claude Code's own tool names in `allowed-tools` - and
    # reading both roots would leave two definitions of every skill, one of them
    # the source of the doctor warnings the copies above exist to remove.
    #
    # Only the home root: a project's `.claude/skills`, which is what
    # `hyperresearch install` writes, is a different path and still loads.
    skills.excluded_paths = [ "~/.claude/skills" ];

    # The Git section of ai-context.nix, enforced rather than merely asked for -
    # the same denies claude-code.nix (permissions.deny), codex.nix
    # (rules/default.rules) and opencode.nix (permission.bash) already carry.
    #
    # `:*` is reasonix's command-prefix form, and a prefix rule it recognises as
    # such refuses a later command that introduces a shell operator, so
    # `Bash(git push:*)` does not also cover `git push && rm -rf .`. The legacy
    # `Bash(git push*)` spelling still loads.
    #
    # Not airtight, same as the other three: the pattern is a literal prefix, so
    # `git -c user.name=x commit` slips past. The prose in ai-context.nix is
    # still what carries the rule.
    #
    # mode stays "ask" - the posture this config already had. Note what that
    # means for automation: `reasonix run` and `reasonix -p` cannot prompt, so
    # an unmatched command there fails closed rather than running, which is why
    # the headless lanes (orx, hyperresearch) still belong to codex and
    # claude-code. The equivalent of their blanket approvals would be
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
    # Read(**/.env), done the way reasonix implements it: the read tools hide
    # .env, .git-credentials, key files and ~/.ssh rather than a path glob
    # matching them. Broader than the other two - and, as its own config comment
    # warns, able to get in the way of a legitimate read of one of those files.
    secrets.protect_sensitive_files = true;

    # The bot gateway (QQ, Feishu, WeChat) stays off, and the rest of its
    # settings are left at reasonix's defaults rather than carried over as a
    # wall of empty allowlists.
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
in
{
  # The global Skill root is also reasonix's profile root, which is why the
  # roles land beside the skills - see the reasonix renderer in ai-agents.nix.
  home.file = {
    ".reasonix/config.toml".source = (pkgs.formats.toml { }).generate "reasonix-config" settings;
  }
  // lib.mapAttrs' (
    name: text: lib.nameValuePair ".reasonix/skills/${name}/SKILL.md" { inherit text; }
  ) (aiAgents.mkAgents { tool = "reasonix"; })
  // lib.mapAttrs' (
    name: src: lib.nameValuePair ".reasonix/skills/${name}" { source = renderSkill name src; }
  ) aiSkills;

  # The instructions file cannot be a home.file entry: that symlinks it into the
  # store, and reasonix ignores an instruction document whose symlink resolves
  # outside its own home ("rejected instruction document ... outside boundary").
  # A symlink to a file inside ~/.reasonix loads and a store symlink does not -
  # measured, not assumed. So this one is installed as a real file instead, at
  # the same 444 the store would give it, and rewritten on every activation.
  #
  # Nothing else here has that problem: the config loads from a store symlink,
  # and so do the skill directories.
  home.activation.reasonixInstructions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD install -m 444 -D $VERBOSE_ARG ${
      pkgs.writeText "REASONIX.md" (aiContext.mkContext { tool = "reasonix"; })
    } "$HOME/.reasonix/REASONIX.md"
  '';
}
