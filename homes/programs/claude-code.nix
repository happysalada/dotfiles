{ pkgs, lib, ... }:
let
  rtk = lib.getExe pkgs.rtk;
  icm = lib.getExe pkgs.icm;
  graphify = lib.getExe pkgs.graphify;
  starship = lib.getExe pkgs.starship;

  # Global instructions, shared with opencode.
  aiContext = import ./ai-context.nix { inherit lib; };

  # One hook entry, matcher-less (fires on every event of its kind).
  cmd = command: {
    hooks = [
      {
        type = "command";
        inherit command;
      }
    ];
  };
  # One hook entry scoped to a tool matcher.
  cmdFor = matcher: command: (cmd command) // { inherit matcher; };
in
{
  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;

    # NOTE: settings.json and CLAUDE.md become mode-444 symlinks into the nix
    # store. That is the point (they are reviewable and reproducible), but it
    # means `/config` and the in-TUI auto-memory toggle can no longer write to
    # them - every change has to come through this file plus a rebuild. It also
    # means `rtk init`, `icm init` and `graphify claude install` must never be
    # run: they mutate exactly these two files and will fail or be reverted.
    settings = {
      model = "opus";
      theme = "dark";
      effortLevel = "high";
      agentPushNotifEnabled = true;

      # Model, context gauge and session cost, rendered by starship rather than
      # a hand-rolled script - the profile lives beside the shell prompt in
      # homes/common.nix. Needs starship >= 1.25, which added the subcommand.
      statusLine = {
        type = "command";
        command = "${starship} statusline claude-code";
      };

      # Native auto-memory is OFF deliberately. It is the third memory system
      # here, and the only one whose store is per-project and invisible to
      # opencode - which makes it the odd one out now that icm (keyed, global,
      # cross-tool) and mempalace (semantic, corpus-scoped) cover the same
      # ground between them. Its directory
      # (~/.claude/projects/<proj>/memory) has been empty since it was created,
      # so nothing is being discarded by turning it off.
      #
      # Flip to true if you ever want per-project memory that is human-readable
      # and diffable in a way neither of the other two are.
      autoMemoryEnabled = false;

      # The Git section of ai-context.nix, enforced rather than merely asked
      # for - the same denies opencode.nix already carries in permission.bash.
      # Deny beats allow and beats a narrower rule, and claude-code matches each
      # subcommand of a compound command independently, so `foo && git commit`
      # is caught too.
      #
      # Not airtight: the pattern is literal up to the first `*`, so
      # `git -c user.name=x commit` slips past. It stops the accident, not a
      # determined agent - the prose in ai-context.nix is still what carries the
      # rule.
      permissions.deny = [
        "Bash(git add *)"
        "Bash(git commit *)"
        "Bash(git push *)"
        "Bash(git reset *)"
        "Bash(git restore *)"
        "Bash(git stash *)"
      ];

      # `git checkout -b` is fine when asked for, `git checkout -- path` destroys
      # work. One pattern cannot tell them apart, so this one prompts.
      permissions.ask = [ "Bash(git checkout *)" ];

      permissions.allow = [
        "Bash(ast-grep *)"
        "Bash(rtk *)"
        "Bash(icm *)"
        "Bash(graphify *)"
        "Bash(nono *)"
        "Bash(crw *)"
        # Deliberately NOT "Bash(sg *)": on NixOS `sg` resolves to
        # /run/wrappers/bin/sg, the setgid "run a command as another group"
        # utility - not ast-grep. Always spell out `ast-grep`.
      ];

      hooks = {
        # Clickable "Claude is done" notification -> focuses the niri window
        # and the zellij pane. Script is hand-maintained in ~/.claude/hooks and
        # is NOT nix-managed (hooksDir would clobber the directory).
        Stop = [
          {
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/stop-notify.sh";
                timeout = 5;
              }
            ];
          }
        ];

        PreToolUse = [
          # rtk rewrites bash invocations to their compact equivalents
          # (`git status` -> `rtk git status`) before the output is captured.
          (cmdFor "Bash" "${rtk} hook claude")

          # graphify's hook-guard nudges search/read toward the knowledge graph.
          # Left off by default: it intercepts *every* Read and Glob, which is
          # pure latency in the repos where no graphify-out/graph.json exists.
          # The CLAUDE.md section below already tells Claude to use graphify,
          # which is the part that actually matters. Uncomment if you want the
          # hard guard instead of the instruction.
          # (cmdFor "Bash|Grep" "${graphify} hook-guard search")
          # (cmdFor "Read|Glob" "${graphify} hook-guard read")

          # `icm hook pre` is icm's *auto-allow* hook: it returns permission
          # decisions, i.e. it can approve tool calls that would otherwise
          # prompt. That is a permission bypass driven by a third-party binary,
          # so it stays off. icm's memory features work fine without it.
          # (cmdFor "Bash" "${icm} hook pre")
        ];

        PostToolUse = [ (cmd "${icm} hook post") ];
        PreCompact = [ (cmd "${icm} hook compact") ];

        # icm's wake-up pack: identity/preferences plus critical decisions,
        # injected once per session. This is the *only* automatic memory
        # injection that stays on - see the memory-split section in
        # ai-context.nix for why exactly one system may own this path.
        SessionStart = [ (cmd "${icm} hook start") ];

        # `icm hook prompt` (auto-recall) is deliberately off. It fires on
        # every single user prompt and its output is appended to the
        # conversation, so the cost is not paid once - it accumulates, one
        # recall block per turn, for the whole session. That directly undoes
        # what rtk is here to do, and it re-injects on turns that have nothing
        # to do with the recalled topic. `icm recall` on demand covers the same
        # ground at the moment it is actually needed.
        # UserPromptSubmit = [ (cmd "${icm} hook prompt") ];
        SessionEnd = [ (cmd "${icm} hook end") ];
      };
    };

    # mempalace + fff come from the shared registry in ai-mcp.nix, so opencode
    # gets identical servers. `mcpServers` still works for Claude-only ones.
    enableMcpIntegration = true;

    # Real code intelligence instead of grep: claude-code speaks
    # textDocument/definition, /references and /documentSymbol, and surfaces
    # publishDiagnostics. Same servers and same store paths as helix.nix, so the
    # editor and the agent can never disagree about a version.
    #
    # The marketplace's twelve `*-lsp` plugins are nothing but this attrset plus
    # a README, and there is no Nix one at all. `ty` rather than `ruff server`
    # on .py: ruff's server is lint and format, which ai-context.nix already
    # tells the agent to get from `ruff check --fix`.
    lspServers = with pkgs; {
      nixd = {
        command = "${nixd}/bin/nixd";
        extensionToLanguage.".nix" = "nix";
      };
      rust-analyzer = {
        command = "${rust-analyzer-unwrapped}/bin/rust-analyzer";
        extensionToLanguage.".rs" = "rust";
      };
      ty = {
        command = "${ty}/bin/ty";
        args = [ "server" ];
        extensionToLanguage.".py" = "python";
      };
    };

    # Cherry-picked upstream skills, shared with opencode.
    skills = import ./ai-skills.nix { inherit pkgs; };

    # -> ~/.claude/CLAUDE.md, same prose as opencode's AGENTS.md.
    context = aiContext.mkContext { tool = "claude-code"; };
  };
}
