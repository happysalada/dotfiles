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
in
{
  programs.opencode = {
    enable = true;
    package = pkgs.opencode;

    # Pulls mempalace + fff from programs.mcp.servers.
    enableMcpIntegration = true;

    settings = {
      # models.dev ids, and the ChatGPT subscription rather than an API key -
      # so the same GPT-5.6 family codex.nix picks from. Sol is the flagship;
      # Terra and Luna stretch the five-hour window much further, so drop down
      # here when Sol runs out. Run `/models` after logging in to see what the
      # account is actually offered.
      model = "openai/gpt-5.6-sol";
      # Titles and summaries, so they don't cost flagship tokens.
      small_model = "openai/gpt-5.6-luna";

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
