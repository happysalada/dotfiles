# opencode - second terminal agent, sharing this box's AI tooling with Claude
# Code and codex.
#
# Shared: MCP servers (homes/programs/ai-mcp.nix), instructions
# (homes/programs/ai-context.nix), and the CLI tools on PATH from packages/ai.nix.
#
# Not shared: hooks. `rtk hook` and `icm hook` have no opencode backend
# (opencode extends via TypeScript plugins, a different event shape), so rtk
# compression and icm's automatic memory belong to claude-code and codex.
# AGENTS.md tells the agent to invoke both by hand instead.
#
# Auth is manual and outside nix: run `opencode auth login`, pick OpenAI, then
# "ChatGPT Plus/Pro". That is the same subscription codex signs into, and it is
# native here - the Anthropic equivalent is not, because opencode dropped the
# Claude Pro/Max plugins in 1.3.0 after Anthropic prohibited them. Credentials
# land in ~/.local/share/opencode/auth.json.
{ pkgs, lib, ... }:
let
  aiContext = import ./ai-context.nix { inherit lib; };
  aiAgents = import ./ai-agents.nix { inherit lib pkgs; };
in
{
  programs.opencode = {
    enable = true;
    package = pkgs.symlinkJoin {
      name = "opencode-${pkgs.opencode.version}";
      paths = [ pkgs.opencode ];
      nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
      postBuild = ''
        wrapProgram "$out/bin/opencode" \
          --set OPENCODE_DISABLE_CLAUDE_CODE_SKILLS 1
      '';
      inherit (pkgs.opencode) version meta;
    };

    # Pulls mempalace + fff from programs.mcp.servers.
    enableMcpIntegration = true;

    settings = {
      # models.dev ids, and the ChatGPT subscription rather than an API key -
      # so the same GPT-5.6 family codex.nix picks from. Sol is the flagship;
      # Terra and Luna stretch the five-hour window much further, so drop down
      # here when Sol runs out. Run `/models` after logging in to see what the
      # account is actually offered.
      model = "openai/gpt-5.6-sol";
      default_agent = "build";
      # Titles and summaries, so they don't cost flagship tokens.
      small_model = "openai/gpt-5.6-luna";

      agent = {
        build = {
          description = "Primary orchestrator for decisions, integration, and final verification.";
          mode = "primary";
          model = "openai/gpt-5.6-sol";
          options.reasoningEffort = "high";
        };
        # `general` overlaps the bounded worker and otherwise gives the main
        # thread an unintended second write-capable role.
        general.disable = true;
      };

      # `opencode upgrade` cannot write to a read-only store path; left on it
      # nags every launch and then fails. Bump nixpkgs instead.
      autoupdate = false;

      # Uploads the transcript to opencode's servers for a public link.
      # `disabled` also removes /share, so it can't fire by accident.
      share = "disabled";

      # Native persistent equivalent of `--auto`: allow otherwise-unmatched
      # requests while retaining the default secret-file blocks and our Git
      # policy. Unlike a CLI wrapper, this does not break subcommand parsing.
      permission = {
        "*" = "allow";
        read = {
          "*" = "allow";
          "*.env" = "deny";
          "*.env.*" = "deny";
          "*.env.example" = "allow";
        };
        bash = {
          "git add*" = "deny";
          "git commit*" = "deny";
          "git push*" = "deny";
          "git reset*" = "deny";
          "git restore*" = "deny";
          "git stash*" = "deny";
          # Auto mode approves asks, and one glob cannot distinguish `-b` from
          # the destructive `-- path` form. Use `git switch -c` for branches.
          "git checkout*" = "deny";
        };
      };
    };

    # Since 1.2.15 TUI keys live in their own tui.json. Note this is a
    # read-only store symlink, so the in-TUI /theme picker cannot persist -
    # change the theme here.
    tui.theme = "system";

    # -> ~/.config/opencode/skills/, same set claude-code gets.
    skills = import ./ai-skills.nix { inherit pkgs; };

    # -> ~/.config/opencode/agents/, same roles codex and claude-code get.
    agents = aiAgents.mkAgents { tool = "opencode"; };

    # -> ~/.config/opencode/AGENTS.md
    context = aiContext.mkContext { tool = "opencode"; };
  };
}
