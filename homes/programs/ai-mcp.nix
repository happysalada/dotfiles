# The one registry of MCP servers on this machine.
#
# home-manager's tool-agnostic `programs.mcp`: declare a server once, and every
# client with `enableMcpIntegration = true` gets it in its own dialect (Claude
# Code wants `mcpServers.<n> = { command, args }`, opencode wants
# `mcp.<n> = { type, command = [cmd args...] }`). Add a server here and it
# appears in both on the next rebuild.
#
# Not everything lives here: homes/programs/crw.nix registers its own server,
# because that entry has to name the port its systemd unit listens on and
# splitting the two across files is how they drift apart.
{ pkgs, lib, ... }:
let
  # Same callPackage call as packages/ai.nix, so it is the same store path -
  # listing it twice does not duplicate anything.
  funes = pkgs.callPackage ../../packages/ai/funes.nix { };
in
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
        command = lib.getExe funes;
        args = [ "mcp" ];
      };

      fff = {
        command = lib.getExe pkgs.fff-mcp;
        args = [ ];
      };

      # Semantic code search - the one search here that answers a question
      # rather than matching a string: fff is fuzzy, ripgrep is lexical, ast-grep
      # is structural. `semble-mcp` is the MCP entry point llm-agents' derivation
      # exposes beside the `semble` CLI, so the server is a store path and needs
      # nothing from PATH. Declaring it here covers all four agents at once.
      #
      # Not via `semble install`, which writes this same entry into each agent's
      # own config - the files this repo generates - plus a sub-agent file. First
      # use on a machine downloads a small embedding model and caches it.
      semble = {
        command = lib.getExe' pkgs.semble "semble-mcp";
        args = [ ];
      };
    };
  };
}
