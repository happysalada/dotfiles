# codex - OpenAI's terminal agent, third on this box after claude-code and
# opencode, and wired the same way: MCP servers, instructions, skills and the CLI
# tools all come from the shared sources (packages/ai.nix for the last of them).
#
# Not shared: rtk. `rtk hook` has backends for claude, cursor, gemini, copilot,
# droid and vibe, but not codex, so compression here is manual - AGENTS.md says
# so. icm *is* wired, because `icm hook` speaks codex's event schema.
#
# Auth is manual and outside nix: `codex login` opens a browser and signs in with
# ChatGPT, which is what bills sessions to the Plus subscription instead of to an
# API key. It writes ~/.codex/auth.json, the one file in that directory nix does
# not own. `codex login --device-auth` is the fallback with no browser.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  icm = lib.getExe pkgs.icm;

  # herdr's Codex integration: the SessionStart hook that reports the session id
  # to the local socket so herdr reopens this conversation after its server
  # restarts. Same shape as the Claude Code one, and the same path-and-command
  # lookup is what tells herdr the integration is installed.
  herdrCodexHook = "${config.home.homeDirectory}/.codex/herdr-agent-state.sh";
  herdrCodexCommand = "bash '${herdrCodexHook}' session";

  # Global instructions, shared with claude-code and opencode.
  aiContext = import ./ai-context.nix { inherit lib; };

  # Subagent roles, shared with claude-code and opencode.
  aiAgents = import ./ai-agents.nix { inherit lib pkgs; };

  # The SessionStart hooks, each with the timeout codex has to see. One list
  # feeds both hooks.json and the hashes below, because codex hashes the
  # *normalized* hook: a timeout declared here but left out of the file is a
  # different hook, and the file's entry silently keeps codex's 600s default.
  sessionStartHooks = [
    {
      command = "${icm} hook start";
      timeout = 600;
    }
    {
      command = herdrCodexCommand;
      timeout = 10;
    }
  ];

  # A project's own .codex/hooks.json is not a nix file, but its trust entries
  # have to be: codex reads hook trust from the user layer only, so a project
  # cannot vouch for itself. These four are what symposium's `cargo agents sync`
  # writes there - the hash covers the command and the timeout, not the file, so
  # changing what cargo-agents emits means re-deriving them here.
  projectHooks = {
    "/home/yt/dev/commonage" = [
      {
        event = "pre_tool_use";
        command = "cargo-agents hook codex pre-tool-use";
        timeout = 10;
        matcher = "";
      }
      {
        event = "post_tool_use";
        command = "cargo-agents hook codex post-tool-use";
        timeout = 10;
        matcher = "";
      }
      {
        event = "session_start";
        command = "cargo-agents hook codex session-start";
        timeout = 10;
        matcher = "";
      }
      {
        event = "user_prompt_submit";
        command = "cargo-agents hook codex user-prompt-submit";
        timeout = 10;
        matcher = "";
      }
    ];
  };

  # For these events codex takes no matcher and drops whatever the file carries,
  # so hashing the file's matcher here would produce a hash codex never computes.
  matcherlessEvents = [
    "user_prompt_submit"
    "stop"
    "interrupt"
  ];

  # One matcher-less hook entry (fires on every event of its kind). Codex reuses
  # Claude Code's event names and JSON shape, which is why icm needs no
  # per-tool wiring beyond this.
  cmd = { command, timeout }: [
    {
      hooks = [
        {
          type = "command";
          inherit command timeout;
        }
      ];
    }
  ];

  # Codex hashes the normalized hook before allowing it to run; these hashes are
  # how reviewed nix configuration becomes the trust boundary. `groupIndex` is
  # where the entry sits in its event's array, since codex keys trust by position.
  trustedHook =
    {
      path,
      event,
      command,
      timeout,
      matcher ? null,
      groupIndex ? 0,
    }:
    let
      normalizedMatcher = if builtins.elem event matcherlessEvents then null else matcher;
    in
    {
      name = "${path}:${event}:${toString groupIndex}:0";
      value.trusted_hash = "sha256:${
        builtins.hashString "sha256" (
          builtins.toJSON (
            {
              event_name = event;
              hooks = [
                {
                  type = "command";
                  inherit command timeout;
                  async = false;
                }
              ];
            }
            // lib.optionalAttrs (normalizedMatcher != null) {
              matcher = normalizedMatcher;
            }
          )
        )
      }";
    };

  # One trust entry per hook in one hooks.json, keyed the way codex keys trust:
  # the file it came from, the event, the hook's position in that event's array,
  # then its position in the matcher group. Each hook here is its own group, so
  # only its event's own ordering counts.
  trustedHooks =
    path: hooks:
    builtins.listToAttrs (
      lib.imap0 (
        index: hook:
        trustedHook (hook // {
          inherit path;
          groupIndex = lib.count (other: other.event == hook.event) (lib.take index hooks);
        })
      ) hooks
    );
in
{
  programs.codex = {
    enable = true;
    package = pkgs.codex;

    # Pulls funes + fff from programs.mcp.servers.
    enableMcpIntegration = true;

    # NOTE: config.toml becomes a mode-444 store symlink, so `/model`,
    # `/approvals` and `codex features enable` cannot persist their choice -
    # every change comes through here plus a rebuild, and `codex update` fails
    # outright. Bump the llm-agents input instead.
    settings = {
      # GPT-6 Luna is the faster/cheaper tier of the GPT-6 family; Sol and
      # Astra are the quality-first ones.
      model = "gpt-6-luna";
      model_reasoning_effort = "high";

      # Matches claude-code's default posture: edits inside the workspace go
      # through without asking, anything reaching outside it prompts. The
      # workspace-write sandbox also protects .git, which is the second half of
      # the Git rules below.
      approval_policy = "on-request";
      approvals_reviewer = "auto_review";
      sandbox_mode = "workspace-write";

      # Cached results come from OpenAI's index rather than a live fetch, which
      # keeps arbitrary page content out of the prompt. AGENTS.md points at crw
      # for the cases that need the live page.
      web_search = "cached";

      # Nothing to update against a read-only store path, so do not spend a
      # request on asking at every launch.
      check_for_update_on_startup = false;

      agents = {
        enabled = true;
        max_concurrent_threads_per_session = 4;
        default_subagent_model = "gpt-6-luna";
        default_subagent_reasoning_effort = "medium";
      };

      # Codex otherwise tries to persist this choice into the generated,
      # read-only config.toml and asks again on the next launch - or, in the
      # agents view, fails the write outright and reports it as an error.
      projects = {
        "/home/yt/dev/agent-run".trust_level = "trusted";
        "/home/yt/dev/commonage".trust_level = "trusted";
        "/home/yt/dev/stound".trust_level = "trusted";
        "/home/yt/dotfiles".trust_level = "trusted";
      };

      # `/hooks` cannot persist trust into the read-only config.toml. These
      # hashes admit exactly the hooks declared above and follow icm upgrades.
      # Without them codex reports each hook as untrusted, and the prompt that
      # would record trust cannot write this file.
      hooks.state =
        trustedHooks "${config.home.homeDirectory}/.codex/hooks.json" (
          map (hook: hook // { event = "session_start"; }) sessionStartHooks
        )
        // lib.concatMapAttrs (
          dir: hooks: trustedHooks "${dir}/.codex/hooks.json" hooks
        ) projectHooks;
    };

    # icm's wake-up pack only, same as claude-code.nix. Trust is derived above
    # from each normalized command. The `icm hook pre` auto-allow hook is left
    # off because it returns permission decisions, a bypass driven by a
    # third-party binary, and the post/compact/end extraction hooks are off
    # because their rule-based extraction filled icm with repo restatements that
    # then crowded the wake-up pack. Memories are stored by hand with `icm store`.
    hooks = {
      SessionStart = lib.concatMap cmd sessionStartHooks;
    };

    # -> ~/.codex/rules/default.rules, the Git section of ai-context.nix enforced
    # rather than merely asked for - the same denies claude-code.nix and
    # opencode.nix already carry.
    #
    # Two limits worth knowing. Rules govern commands run *outside* the sandbox,
    # so inside workspace-write it is the protected .git path that stops a
    # commit, not this file. And codex splits `a && b` into separate commands
    # before matching, so a mutator smuggled into a compound command is still
    # caught - but only while the script stays free of variables, redirection
    # and globs, which make it opaque and matched as a single `bash -lc` call.
    rules.default = ''
      # Generated from homes/programs/codex.nix - do not edit in place.
      # This is a read-only store symlink, so the TUI's "always allow" cannot
      # append to it either. Add rules in the nix file and rebuild.

      prefix_rule(
          pattern = ["git", ["add", "commit", "push", "reset", "restore", "stash"]],
          decision = "forbidden",
          justification = "I stage and I commit. Leave the change in the working tree and tell me what it is.",
          match = [
              "git add .",
              "git commit -m wip",
              "git push origin master",
              "git stash",
          ],
          not_match = [
              "git status",
              "git diff",
              "git log --oneline",
          ],
      )

      # `git checkout -b` is fine when asked for, `git checkout -- path` destroys
      # work. One prefix cannot tell them apart, so this one asks.
      prefix_rule(
          pattern = ["git", "checkout"],
          decision = "prompt",
          justification = "`git checkout -- <path>` discards working-tree changes.",
      )
    '';

    # Cherry-picked upstream skills, shared with claude-code and opencode.
    skills = import ./ai-skills.nix { inherit pkgs; };

    # -> ~/.codex/AGENTS.md, same prose as CLAUDE.md and opencode's AGENTS.md.
    context = aiContext.mkContext { tool = "codex"; };
  };

  # Codex discovers personal roles directly under $CODEX_HOME/agents. Home
  # Manager does not yet expose a programs.codex.agents option.
  home.file = {
    # Let the managed daemon launch the Nix package without enabling its updater.
    ".codex/packages/standalone/current/bin/codex".source = lib.getExe config.programs.codex.package;

    # herdr's hook file, straight out of the herdr store path - same bytes and
    # same version marker as the installer would write there. Its trust hash and
    # its SessionStart entry are declared above; see packages/ai.nix for why
    # `herdr integration install codex` must not be run.
    ".codex/herdr-agent-state.sh".source = "${pkgs.herdr}/share/herdr/integrations/codex/herdr-agent-state.sh";
  }
  // lib.mapAttrs' (
    name: source: lib.nameValuePair ".codex/agents/${name}.toml" { inherit source; }
  ) (aiAgents.mkAgents { tool = "codex"; });
}
