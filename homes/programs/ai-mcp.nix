# The one registry of MCP servers on this machine.
#
# home-manager's tool-agnostic `programs.mcp`: declare a server once, and every
# client with `enableMcpIntegration = true` gets it in its own dialect (Claude
# Code wants `mcpServers.<n> = { command, args }`, opencode wants
# `mcp.<n> = { type, command = [cmd args...] }`). Add a server here and it
# appears in both on the next rebuild. crw.nix registers its own entry, because
# that one must name the port its systemd unit listens on.
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

      # Semantic code search - the one search that answers a question rather than
      # matching a string: fff is fuzzy, ripgrep lexical, ast-grep structural.
      # `semble-mcp` is the entry point llm-agents exposes beside the `semble` CLI,
      # so a store path needs nothing from PATH and declaring it covers all four
      # agents. Not via `semble install`, which writes this same entry into each
      # agent's generated config; first use caches a small embedding model.
      semble = {
        command = lib.getExe' pkgs.semble "semble-mcp";
        args = [ ];
      };
    };
  };
}
