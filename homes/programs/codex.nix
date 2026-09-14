# codex - OpenAI's terminal agent, third on this box after claude-code and
# opencode, and wired the same way.
#
# Shared: MCP servers (homes/programs/ai-mcp.nix), instructions
# (homes/programs/ai-context.nix), skills (homes/programs/ai-skills.nix), and
# the CLI tools on PATH from packages/ai.nix.
#
# Not shared: rtk. `rtk hook` has backends for claude, cursor, gemini, copilot,
# droid and vibe, but not codex, so compression here is manual - AGENTS.md says
# so. icm *is* wired, because `icm hook` speaks codex's event schema.
#
# Auth is manual and outside nix: `codex login` opens a browser and signs in
# with ChatGPT, which is what bills sessions to the Plus subscription instead of
# to an API key. It writes ~/.codex/auth.json, the one file in that directory
# nix does not own. `codex login --device-auth` is the fallback with no browser.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  icm = lib.getExe pkgs.icm;

  # Global instructions, shared with claude-code and opencode.
  aiContext = import ./ai-context.nix { inherit lib; };

  # Subagent roles, shared with claude-code and opencode.
  aiAgents = import ./ai-agents.nix { inherit lib pkgs; };

  # One matcher-less hook entry (fires on every event of its kind). Codex reuses
  # Claude Code's event names and JSON shape, which is why icm needs no
  # per-tool wiring beyond this.
  cmd = command: [
    {
      hooks = [
        {
          type = "command";
          inherit command;
        }
      ];
    }
  ];

  # Codex hashes the normalized hook before allowing it to run. Generate the
  # same hash so reviewed nix configuration is the trust boundary.
  trustedHook =
    {
      event,
      command,
      timeout ? 600,
    }:
    {
      name = "${config.home.homeDirectory}/.codex/hooks.json:${event}:0:0";
      value.trusted_hash = "sha256:${
        builtins.hashString "sha256" (
          builtins.toJSON {
            event_name = event;
            hooks = [
              {
                type = "command";
                inherit command timeout;
                async = false;
              }
            ];
          }
        )
      }";
    };
in
{
  programs.codex = {
    enable = true;
    package = pkgs.codex;

    # Pulls mempalace + fff from programs.mcp.servers.
    enableMcpIntegration = true;

    # NOTE: config.toml becomes a mode-444 symlink into the nix store, same as
    # ~/.claude/settings.json. So `/model`, `/approvals` and `codex features
    # enable` cannot persist their choice - every change comes through here plus
    # a rebuild. `codex update` fails for the same reason; bump nixpkgs instead.
    settings = {
      # Sol is the flagship of the GPT-5.6 family, the analogue of `model =
      # "opus"` on the claude-code side. Plus includes all three: Terra is the
      # workhorse and Luna the cheap one, and both go much further per
      # five-hour window, so drop down here when Sol runs out rather than
      # waiting for the window to reset.
      model = "gpt-5.6-sol";
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
        default_subagent_model = "gpt-5.6-terra";
        default_subagent_reasoning_effort = "medium";
      };

      # Codex otherwise tries to persist this choice into the generated,
      # read-only config.toml and asks again on the next launch.
      projects."/home/yt/dotfiles".trust_level = "trusted";

      # `/hooks` cannot persist trust into the read-only config.toml. These
      # hashes admit exactly the hooks declared below and follow icm upgrades.
      hooks.state = builtins.listToAttrs [
        (trustedHook {
          event = "session_start";
          command = "${icm} hook start";
        })
        (trustedHook {
          event = "post_tool_use";
          command = "${icm} hook post";
        })
        (trustedHook {
          event = "pre_compact";
          command = "${icm} hook compact";
        })
        (trustedHook {
          event = "session_end";
          command = "${icm} hook end";
          timeout = 3;
        })
      ];
    };

    # icm's memory, the same four events claude-code.nix registers.
    #
    # Trust is derived above from each normalized command. The `icm hook pre`
    # auto-allow hook is left off because it returns permission decisions, which
    # is a bypass driven by a third-party binary.
    #
    # SessionEnd is capped at three seconds by codex (most hooks get 600), so
    # end-of-session extraction can be cut short. PostToolUse and PreCompact are
    # what actually carry the memories.
    hooks = {
      SessionStart = cmd "${icm} hook start";
      PostToolUse = cmd "${icm} hook post";
      PreCompact = cmd "${icm} hook compact";
      SessionEnd = [
        {
          hooks = [
            {
              type = "command";
              command = "${icm} hook end";
              timeout = 3;
            }
          ];
        }
      ];
    };

    # -> ~/.codex/rules/default.rules, the Git section of ai-context.nix
    # enforced rather than merely asked for - the same denies claude-code.nix
    # and opencode.nix already carry.
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
  }
  // lib.mapAttrs' (
    name: source: lib.nameValuePair ".codex/agents/${name}.toml" { inherit source; }
  ) (aiAgents.mkAgents { tool = "codex"; });
}
