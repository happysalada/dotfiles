# The one registry of MCP servers on this machine.
#
# home-manager's tool-agnostic `programs.mcp`: declare a server once, and every
# client with `enableMcpIntegration = true` gets it in its own dialect (Claude
# Code wants `mcpServers.<n> = { command, args }`, opencode wants
# `mcp.<n> = { type, command = [cmd args...] }`). Add a server here and it
# appears in both on the next rebuild. crw.nix registers its own entry, because
# that one must name the port its systemd unit listens on.
{ pkgs, lib, ... }:
{
  programs.mcp = {
    enable = true;

    servers = {
      context7.url = "https://mcp.context7.com/mcp";
      scite.url = "https://api.scite.ai/mcp";
      wolfram.url = "https://agenttools.wolfram.com/mcp";

      # Local servers use absolute store paths, so they do not depend on PATH.
      funes = {
        # No memory argument: recall reads the local memory, never the Hub.
        command = lib.getExe pkgs.funes;
        args = [ "mcp" ];
      };

      fff = {
        command = lib.getExe pkgs.fff-mcp;
        args = [ ];
      };

      # Semantic code search - the one search that answers a question rather
      # than matching a string: fff is fuzzy, ripgrep lexical, ast-grep
      # structural. `--serve` speaks MCP over stdio and captures its cwd at
      # launch as the sandbox root, so each agent searches the repo it was
      # started in; CK_MCP_ALLOWED_ROOTS is the only way to widen that. It takes
      # the slot semble held, whose `install` was the hazard - here it is the
      # README's `claude mcp add ck-search`, which writes the same entry into a
      # ~/.claude/settings.json this repo generates.
      #
      # First use downloads bge-small to ~/.cache/ck/models, and the agent
      # sandboxes leave $HOME read-only, so warm that cache from a plain shell
      # before the first jailed session or the embedder fails to start.
      ck = {
        command = lib.getExe pkgs.ck;
        args = [ "--serve" ];
      };
    };
  };
}
