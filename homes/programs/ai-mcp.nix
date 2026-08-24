# The one registry of MCP servers on this machine.
#
# home-manager's tool-agnostic `programs.mcp`: declare a server once, and every
# client with `enableMcpIntegration = true` gets it in its own dialect (Claude
# Code wants `mcpServers.<n> = { command, args }`, opencode wants
# `mcp.<n> = { type, command = [cmd args...] }`). Add a server here and it
# appears in both on the next rebuild.
{ pkgs, lib, ... }:
let
  # Same callPackage calls as packages/ai.nix, so these are the same store
  # paths - listing them twice does not duplicate anything.
  mempalace = pkgs.callPackage ../../packages/ai/mempalace.nix { };
  fff-mcp = pkgs.callPackage ../../packages/ai/fff-mcp.nix { };
in
{
  programs.mcp = {
    enable = true;

    # Both speak stdio and are pinned to absolute store paths, so they do not
    # depend on PATH when the agent spawns them.
    servers = {
      mempalace = {
        # Defaults to stdio and ~/.mempalace; both are what we want.
        command = "${mempalace}/bin/mempalace-mcp";
        args = [ ];
      };

      fff = {
        command = lib.getExe fff-mcp;
        args = [ ];
      };
    };
  };
}
