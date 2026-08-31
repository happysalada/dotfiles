# opencode - second terminal agent, sharing this box's AI tooling with Claude Code.
#
# Shared: MCP servers (homes/programs/ai-mcp.nix), instructions
# (homes/programs/ai-context.nix), and the CLI tools on PATH from packages/ai.nix.
#
# Not shared: hooks. `rtk hook` and `icm hook` have no opencode backend
# (opencode extends via TypeScript plugins, a different event shape), so rtk
# compression and icm's automatic memory are Claude-Code-only. AGENTS.md tells
# the agent to invoke both by hand instead.
#
# Auth is manual and outside nix: run `opencode auth login` once.
{ pkgs, lib, ... }:
let
  aiContext = import ./ai-context.nix { inherit lib; };
in
{
  programs.opencode = {
    enable = true;
    package = pkgs.opencode;

    # Pulls mempalace + fff from programs.mcp.servers.
    enableMcpIntegration = true;

    settings = {
      # models.dev ids. Mirrors `model = "opus"` on the Claude Code side.
      model = "anthropic/claude-opus-5";
      # Titles and summaries, so they don't cost opus tokens.
      small_model = "anthropic/claude-haiku-4-5";

      # `opencode upgrade` cannot write to a read-only store path; left on it
      # nags every launch and then fails. Bump nixpkgs instead.
      autoupdate = false;

      # Uploads the transcript to opencode's servers for a public link.
      # `disabled` also removes /share, so it can't fire by accident.
      share = "disabled";

      # Globs over the command string, last match wins. No "*" entry, so
      # ordinary commands keep opencode's defaults - this only enforces the Git
      # section of AGENTS.md, which prose alone cannot.
      permission.bash = {
        "git add*" = "deny";
        "git commit*" = "deny";
        "git push*" = "deny";
        "git reset*" = "deny";
        "git restore*" = "deny";
        "git stash*" = "deny";
        # `git checkout -b` is allowed when asked for, `git checkout -- path`
        # destroys work. One glob can't tell them apart.
        "git checkout*" = "ask";
      };
    };

    # Since 1.2.15 TUI keys live in their own tui.json. Note this is a
    # read-only store symlink, so the in-TUI /theme picker cannot persist -
    # change the theme here.
    tui.theme = "system";

    # -> ~/.config/opencode/skills/, same set claude-code gets.
    skills = import ./ai-skills.nix { inherit pkgs; };

    # -> ~/.config/opencode/AGENTS.md
    context = aiContext.mkContext { tool = "opencode"; };
  };
}
